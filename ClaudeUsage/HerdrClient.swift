import Foundation
#if canImport(LanesCore)
import LanesCore
#endif

/// Drives herdr through its CLI.
///
/// Always by absolute path: this app is started with launchd's minimal PATH,
/// which has no Homebrew (the same trap LANES-SPEC warns about for
/// `brew services`). The CLI finds herdr's default socket on its own; verified
/// from `env -i` on 2026-09-17.
///
/// Blocking. Call it off the main actor.
struct HerdrClient {
    static let candidates = ["/opt/homebrew/bin/herdr", "/usr/local/bin/herdr"]

    enum HerdrError: LocalizedError {
        case notInstalled
        case failed(String)
        case newTabNotFound
        case notAShell(String)

        var errorDescription: String? {
            switch self {
            case .notInstalled: return "herdr not found in /opt/homebrew/bin or /usr/local/bin"
            case .failed(let msg): return "herdr: \(msg)"
            case .newTabNotFound: return "herdr created a tab but it never showed up in the tab list"
            case .notAShell(let what): return "New tab is running \(what), not a shell, so Claude was not started"
            }
        }
    }

    private struct Snapshot {
        let tabs: [HerdrTab]
        let panesByTab: [String: [String]]
    }

    /// Bytes read from one pipe on a background queue. Written once by the
    /// reader, read only after `drained` says the reader is done.
    private final class PipeBox {
        var data = Data()
    }

    /// A herdr call that has not exited by then is killed, so a hung herdr
    /// can never hold a lane's `opening` guard forever.
    static let timeout: TimeInterval = 10

    func tabs() throws -> [HerdrTab] { try snapshot().tabs }

    func focus(tabId: String) throws {
        _ = try run(["tab", "focus", tabId])
    }

    /// Creates a focused tab for `lane` with BBS_AGENT set and returns its tab
    /// and first pane. The new tab is found by diffing the tab list, because
    /// the output of `tab create` has not been verified; a tab that did not
    /// exist before and carries this exact label is unambiguous.
    func create(lane: String, cwd: String) throws -> (tabId: String, paneId: String) {
        let before = Set(try snapshot().tabs.map(\.tabId))
        _ = try run(["tab", "create", "--cwd", cwd, "--label", lane, "--env", "BBS_AGENT=\(lane)", "--focus"])
        for _ in 0..<10 {
            let snap = try snapshot()
            if let tab = snap.tabs.first(where: { !before.contains($0.tabId) && $0.label == lane }),
               let pane = snap.panesByTab[tab.tabId]?.first {
                return (tab.tabId, pane)
            }
            Thread.sleep(forTimeInterval: 0.2)
        }
        throw HerdrError.newTabNotFound
    }

    /// Types `command` and Enter, but only when the pane's foreground process
    /// is a shell. If herdr is ever configured to start claude in new tabs,
    /// typing `claude --resume ...` into a running claude would send it as a
    /// prompt. Fails closed: the tab stays open, nothing is typed.
    func runInShell(paneId: String, command: String) throws {
        let data = try run(["pane", "process-info", "--pane", paneId])
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let info = (obj["result"] as? [String: Any])?["process_info"] as? [String: Any],
              let procs = info["foreground_processes"] as? [[String: Any]] else {
            throw HerdrError.failed("unexpected process-info shape")
        }
        let shells: Set<String> = ["zsh", "-zsh", "bash", "-bash", "sh", "-sh", "fish", "-fish", "login"]
        let names = procs.compactMap { $0["name"] as? String }
        guard !names.isEmpty, names.allSatisfy(shells.contains) else {
            throw HerdrError.notAShell(names.isEmpty ? "nothing" : names.joined(separator: ", "))
        }
        _ = try run(["pane", "run", paneId, command])
    }

    private func snapshot() throws -> Snapshot {
        let data = try run(["api", "snapshot"])
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let snap = (obj["result"] as? [String: Any])?["snapshot"] as? [String: Any],
              let tabs = snap["tabs"] as? [[String: Any]] else {
            throw HerdrError.failed("unexpected snapshot shape")
        }
        var cwds: [String: [String]] = [:]
        var panes: [String: [String]] = [:]
        for p in snap["panes"] as? [[String: Any]] ?? [] {
            guard let tab = p["tab_id"] as? String else { continue }
            if let cwd = p["cwd"] as? String { cwds[tab, default: []].append(cwd) }
            if let pane = p["pane_id"] as? String { panes[tab, default: []].append(pane) }
        }
        return Snapshot(
            tabs: tabs.compactMap { t in
                guard let id = t["tab_id"] as? String else { return nil }
                return HerdrTab(tabId: id, label: t["label"] as? String ?? "", paneCwds: cwds[id] ?? [])
            },
            panesByTab: panes)
    }

    private func run(_ args: [String]) throws -> Data {
        guard let bin = Self.candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            throw HerdrError.notInstalled
        }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: bin)
        p.arguments = args
        let out = Pipe()
        let err = Pipe()
        p.standardOutput = out
        p.standardError = err
        let exited = DispatchSemaphore(value: 0)
        p.terminationHandler = { _ in exited.signal() }
        try p.run()

        // Both pipes are drained at the same time, each on its own queue: if
        // herdr writes more than a pipe buffer to one while nobody reads it,
        // herdr blocks on that write and never exits.
        let outBox = PipeBox()
        let errBox = PipeBox()
        let drained = DispatchGroup()
        for (pipe, box) in [(out, outBox), (err, errBox)] {
            drained.enter()
            DispatchQueue.global(qos: .utility).async {
                box.data = pipe.fileHandleForReading.readDataToEndOfFile()
                drained.leave()
            }
        }

        if exited.wait(timeout: .now() + Self.timeout) == .timedOut {
            // SIGTERM, then SIGKILL if herdr ignores it. Once it is dead its
            // ends of the pipes close and both drains finish on their own.
            p.terminate()
            if exited.wait(timeout: .now() + 2) == .timedOut {
                kill(p.processIdentifier, SIGKILL)
                exited.wait()
            }
            _ = drained.wait(timeout: .now() + 2)
            throw HerdrError.failed("timed out")
        }
        // herdr has exited, so EOF is due on both pipes. The wait is still
        // bounded: a leftover child holding a pipe open must not hang us.
        guard drained.wait(timeout: .now() + 2) == .success else {
            throw HerdrError.failed("timed out")
        }
        let data = outBox.data
        guard p.terminationStatus == 0 else {
            let msg = String(data: errBox.data, encoding: .utf8) ?? ""
            throw HerdrError.failed(msg.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return data
    }
}
