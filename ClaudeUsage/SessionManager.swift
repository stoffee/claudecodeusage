import Foundation
import AppKit

struct SessionEntry: Identifiable {
    let sessionId: String
    let fullPath: String
    let projectPath: String
    let firstPrompt: String
    let messageCount: Int
    let modifiedDate: Date
    let gitBranch: String
    let summary: String?      // set via /name in Claude Code

    var id: String { sessionId }

    var displayTitle: String {
        if let s = summary, !s.isEmpty { return s }
        if !firstPrompt.isEmpty { return String(firstPrompt.prefix(80)) }
        return "Untitled Session"
    }

    var hasCustomName: Bool { !(summary ?? "").isEmpty }

    var shortProjectName: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if projectPath == home || projectPath.isEmpty { return "~" }
        if projectPath.hasPrefix(home) {
            let relative = String(projectPath.dropFirst(home.count + 1))
            let parts = relative.split(separator: "/")
            if parts.count <= 2 { return relative }
            return parts.suffix(2).joined(separator: "/")
        }
        return (projectPath as NSString).lastPathComponent
    }

    var relativeModified: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: modifiedDate, relativeTo: Date())
    }

    var branchDisplay: String? {
        gitBranch.isEmpty ? nil : gitBranch
    }
}

// Free functions to avoid @MainActor isolation in Task.detached

private func parseSessionFile(_ path: String) -> (prompt: String, messageCount: Int, cwd: String, branch: String, customTitle: String?) {
    guard let fh = FileHandle(forReadingAtPath: path) else {
        return ("", 0, "", "", nil)
    }
    defer { fh.closeFile() }

    // Read full file to catch custom-title entries (may appear anywhere, last one wins)
    let fileSize = (try? FileManager.default.attributesOfItem(atPath: path))?[.size] as? Int ?? 0
    let data = fh.readDataToEndOfFile()
    guard let content = String(data: data, encoding: .utf8) else {
        return ("", 0, "", "", nil)
    }

    var prompt = ""
    var cwd = ""
    var branch = ""
    var messageCount = 0
    var customTitle: String? = nil

    for line in content.split(separator: "\n") {
        guard let obj = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any] else { continue }

        let type = obj["type"] as? String ?? ""

        if type == "custom-title", let title = obj["customTitle"] as? String, !title.isEmpty {
            customTitle = title   // last entry wins
        }

        if type == "user" || type == "assistant" {
            messageCount += 1
        }

        if cwd.isEmpty, let c = obj["cwd"] as? String {
            cwd = c
        }

        if branch.isEmpty, let b = obj["gitBranch"] as? String {
            branch = b
        }

        if prompt.isEmpty && type == "user" {
            let userType = obj["userType"] as? String ?? ""
            if userType == "external" {
                if let msg = obj["message"] as? [String: Any] {
                    if let contentArr = msg["content"] as? [[String: Any]] {
                        for c in contentArr {
                            if c["type"] as? String == "text",
                               let text = c["text"] as? String, !text.isEmpty {
                                prompt = text
                                break
                            }
                        }
                    } else if let text = msg["content"] as? String {
                        prompt = text
                    }
                }
            }
        }
    }

    // Estimate message count for large files that were truncated in old code
    // (now we read full file so no estimation needed, but keep for very large files)
    _ = fileSize

    return (prompt, messageCount, cwd, branch, customTitle)
}

private func decodeProjectPath(_ encoded: String) -> String {
    "/" + encoded.dropFirst().replacingOccurrences(of: "-", with: "/")
}

@MainActor
class SessionManager: ObservableObject {
    @Published var sessions: [SessionEntry] = []
    @Published var isLoading = false

    func loadSessions() {
        isLoading = true
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let projectsDir = "\(homeDir)/.claude/projects"

        Task.detached {
            var allSessions: [SessionEntry] = []
            let fm = FileManager.default

            guard let dirs = try? fm.contentsOfDirectory(atPath: projectsDir) else {
                await MainActor.run { [weak self] in
                    self?.sessions = []
                    self?.isLoading = false
                }
                return
            }

            // Build sessionId → summary lookup from all sessions-index.json files
            var summaryIndex: [String: String] = [:]
            for dir in dirs {
                let indexPath = "\(projectsDir)/\(dir)/sessions-index.json"
                guard let data = fm.contents(atPath: indexPath),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let entries = json["entries"] as? [[String: Any]] else { continue }
                for entry in entries {
                    if let sid = entry["sessionId"] as? String,
                       let summary = entry["summary"] as? String,
                       !summary.isEmpty {
                        summaryIndex[sid] = summary
                    }
                }
            }

            for dir in dirs {
                let dirPath = "\(projectsDir)/\(dir)"
                guard let files = try? fm.contentsOfDirectory(atPath: dirPath) else { continue }

                let projectPath = decodeProjectPath(dir)

                for file in files {
                    guard file.hasSuffix(".jsonl"),
                          !file.contains("subagent") else { continue }
                    let filePath = "\(dirPath)/\(file)"
                    let sessionId = String(file.dropLast(6))

                    guard let attrs = try? fm.attributesOfItem(atPath: filePath),
                          let modDate = attrs[.modificationDate] as? Date else { continue }

                    let (prompt, msgCount, cwd, branch, customTitle) = parseSessionFile(filePath)

                    let session = SessionEntry(
                        sessionId: sessionId,
                        fullPath: filePath,
                        projectPath: cwd.isEmpty ? projectPath : cwd,
                        firstPrompt: prompt,
                        messageCount: msgCount,
                        modifiedDate: modDate,
                        gitBranch: branch,
                        summary: customTitle ?? summaryIndex[sessionId]
                    )
                    allSessions.append(session)
                }
            }

            allSessions.sort { $0.modifiedDate > $1.modifiedDate }

            await MainActor.run { [weak self] in
                self?.sessions = allSessions
                self?.isLoading = false
            }
        }
    }

    func deleteSession(_ session: SessionEntry) {
        let fm = FileManager.default

        // Delete the .jsonl session file
        if fm.fileExists(atPath: session.fullPath) {
            try? fm.removeItem(atPath: session.fullPath)
        }

        // Also delete subagents directory if it exists
        let subagentsDir = session.fullPath.replacingOccurrences(of: ".jsonl", with: "")
        if fm.fileExists(atPath: subagentsDir) {
            try? fm.removeItem(atPath: subagentsDir)
        }

        // Also remove from sessions-index.json if present
        let homeDir = fm.homeDirectoryForCurrentUser.path
        let projectsDir = "\(homeDir)/.claude/projects"
        if let dirs = try? fm.contentsOfDirectory(atPath: projectsDir) {
            for dir in dirs {
                let indexPath = "\(projectsDir)/\(dir)/sessions-index.json"
                guard fm.fileExists(atPath: indexPath),
                      let data = fm.contents(atPath: indexPath),
                      var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      var entries = json["entries"] as? [[String: Any]] else { continue }

                let before = entries.count
                entries.removeAll { ($0["sessionId"] as? String) == session.sessionId }
                if entries.count < before {
                    json["entries"] = entries
                    if let updated = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]) {
                        try? updated.write(to: URL(fileURLWithPath: indexPath))
                    }
                }
            }
        }

        // Remove from local list
        sessions.removeAll { $0.sessionId == session.sessionId }
    }

    enum TerminalApp: String {
        case iterm = "iTerm2"
        case warp = "Warp"
    }

    func resumeSession(_ session: SessionEntry) {
        // Show terminal picker
        let alert = NSAlert()
        alert.messageText = "Open session in..."
        alert.informativeText = session.displayTitle
        alert.addButton(withTitle: "iTerm2")
        alert.addButton(withTitle: "Warp")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            launchInTerminal(session: session, app: .iterm)
        case .alertSecondButtonReturn:
            launchInTerminal(session: session, app: .warp)
        default:
            break
        }
    }

    private func launchInTerminal(session: SessionEntry, app: TerminalApp) {
        let projectPath = session.projectPath.isEmpty
            ? FileManager.default.homeDirectoryForCurrentUser.path
            : session.projectPath

        switch app {
        case .iterm:
            let command = "cd \(shellQuote(projectPath)) && claude --resume \(shellQuote(session.sessionId))"
            let script = """
            tell application "iTerm2"
                activate
                if (count of windows) = 0 then
                    create window with default profile
                    tell current session of current window
                        write text "\(command)"
                    end tell
                else
                    tell current window
                        create tab with default profile
                        tell current session
                            write text "\(command)"
                        end tell
                    end tell
                end if
            end tell
            """
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", script]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try? process.run()

        case .warp:
            // Write a temp script and open it in Warp — no Accessibility permissions needed
            let tmpScript = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("claude_resume_\(session.sessionId).sh")
            let scriptContent = """
            #!/bin/bash
            cd \(shellQuote(projectPath))
            claude --resume \(shellQuote(session.sessionId))
            """
            do {
                try scriptContent.write(to: tmpScript, atomically: true, encoding: .utf8)
                try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tmpScript.path)
            } catch {
                return
            }
            NSWorkspace.shared.openFile(tmpScript.path, withApplication: "Warp")
        }
    }

    private func shellQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func appleScriptQuote(_ s: String) -> String {
        let escaped = s
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"" + escaped + "\""
    }
}
