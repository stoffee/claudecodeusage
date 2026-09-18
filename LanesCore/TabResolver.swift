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
    public static func forNewTab(cwd: String?, sessionId: String?) -> String? {
        guard cwd != nil else { return nil }
        if let id = sessionId, UUID(uuidString: id)?.uuidString.lowercased() == id {
            return "claude --resume \(id)"
        }
        return "claude"
    }
}
