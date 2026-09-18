import Foundation

/// A herdr tab as `herdr api snapshot` reports it.
public struct HerdrTab: Equatable, Sendable {
    public let tabId: String
    public let label: String
    /// cwd of every pane in the tab.
    public let paneCwds: [String]

    public init(tabId: String, label: String, paneCwds: [String]) {
        self.tabId = tabId
        self.label = label
        self.paneCwds = paneCwds
    }
}

/// Where a lane was last seen running, as RECORDED by the session hook or by
/// this app's own `herdr tab create`. Never inferred.
public struct RecordedTab: Codable, Equatable, Sendable {
    public let tabId: String
    public let cwd: String
    public let sessionId: String?
    public let recordedAt: Date

    public init(tabId: String, cwd: String, sessionId: String?, recordedAt: Date) {
        self.tabId = tabId
        self.cwd = cwd
        self.sessionId = sessionId
        self.recordedAt = recordedAt
    }
}

public enum TabAction: Equatable, Sendable {
    case focus(tabId: String)
    /// Open a new tab. nil cwd means no known repo path.
    case create(cwd: String?)
}

public enum TabResolver {
    /// LANES-SPEC "Click behaviour" for a dormant lane.
    ///
    /// The load-bearing rule: a tab matches a lane ONLY by a recorded link or
    /// an exact label. Never fuzzy. Unsure means create, because a duplicate
    /// tab is cheap and a mislabelled lane is not.
    public static func resolve(lane: String, recorded: RecordedTab?,
                               tabs: [HerdrTab], fallbackCwd: String?) -> TabAction {
        // 1. A recorded link that still holds. herdr tab ids are short
        //    sequence ids ("w1:t3") that can be handed out again after herdr
        //    restarts, so the id alone proves nothing: the tab must still have
        //    a pane in the recorded cwd.
        if let r = recorded,
           let tab = tabs.first(where: { $0.tabId == r.tabId }),
           tab.paneCwds.contains(r.cwd) {
            return .focus(tabId: tab.tabId)
        }

        // 2. Exactly one tab whose label IS the lane name. Two or more is
        //    ambiguous, and ambiguous means create.
        let exact = tabs.filter { $0.label == lane }
        if exact.count == 1 { return .focus(tabId: exact[0].tabId) }

        // 3. Nothing trustworthy.
        return .create(cwd: recorded?.cwd ?? fallbackCwd)
    }
}

public enum ResumeCommand {
    /// Which recorded session a new tab in `cwd` should resume, if any.
    ///
    /// The hook's record wins (it carries its own cwd, which is how `cwd` was
    /// chosen). A lane card's id is used only when `cwd` is the card's own
    /// cwd: `claude --resume` looks sessions up per directory, so an id from
    /// another directory would fail or open the wrong session.
    public static func sessionId(forCwd cwd: String?, recorded: RecordedTab?, card: LaneCard?) -> String? {
        if let id = recorded?.sessionId { return id }
        if let card, let cwd, card.cwd == cwd { return card.lastSessionId }
        return nil
    }

    /// What to type into a freshly created tab.
    ///
    /// - nil when the cwd is unknown: never start claude in a guessed directory.
    /// - `claude --resume <id>` when a session was recorded for the lane.
    /// - `claude` otherwise.
    ///
    /// The id is typed into a shell, so only canonical lowercase UUIDs are
    /// accepted, which rules out shell metacharacters and flag-shaped values
    /// like "--print" that could be injected from a corrupted lane-tabs file.
    public static func forNewTab(cwd: String?, sessionId: String?, lane: String? = nil) -> String? {
        guard cwd != nil else { return nil }
        // Name the session after its lane (`-n`), and have a fresh one load the
        // lane with the /resume skill. An unsafe lane name is left out entirely.
        let name = lane.flatMap { isSafeLaneName($0) ? $0 : nil }
        if let id = sessionId, isResumableId(id) {
            return name.map { "claude -n \($0) --resume \(id)" } ?? "claude --resume \(id)"
        }
        return name.map { "claude -n \($0) \"/resume \($0)\"" } ?? "claude"
    }

    /// A lane name comes from the board and is typed into a shell, so it must
    /// be plain ASCII letters, digits, `_` and `-`, starting with a letter or
    /// digit (never read as a flag). Every real seat name fits.
    public static func isSafeLaneName(_ lane: String) -> Bool {
        guard let first = lane.unicodeScalars.first,
              first.isASCII, CharacterSet.alphanumerics.contains(first) else { return false }
        return lane.unicodeScalars.allSatisfy {
            $0.isASCII && (CharacterSet.alphanumerics.contains($0) || $0 == "_" || $0 == "-")
        }
    }

    /// True only for a canonical lowercase UUID, the only shape that is safe
    /// to type into a shell and the shape Claude Code names session files by.
    public static func isResumableId(_ id: String) -> Bool {
        UUID(uuidString: id)?.uuidString.lowercased() == id
    }
}
