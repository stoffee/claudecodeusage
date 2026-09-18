import Foundation

/// A lane card from `~/.claude/lanes/<lane>.json`, written by the /resume
/// tooling in claude-config (contract: `written_by == "lane-card-v1"`).
///
/// It is a CACHE and may be missing at any time. A missing card means "no
/// card", never "this lane has no history".
public struct LaneCard: Equatable, Sendable {
    public let lane: String
    public let cwd: String?
    /// Local Claude Code session UUID, set by the card writer only when it
    /// could prove it. Deliberately NOT `last_session_web`: that is a
    /// claude.ai prefix and `claude --resume` cannot use it.
    public let lastSessionId: String?

    public init(lane: String, cwd: String?, lastSessionId: String?) {
        self.lane = lane
        self.cwd = cwd
        self.lastSessionId = lastSessionId
    }

    /// nil for anything that is not a lane-card-v1, so a future format change
    /// is ignored rather than misread.
    public static func parse(_ data: Data) -> LaneCard? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              obj["written_by"] as? String == "lane-card-v1",
              let lane = obj["lane"] as? String, !lane.isEmpty else { return nil }
        func nonEmpty(_ key: String) -> String? {
            guard let v = obj[key] as? String, !v.isEmpty else { return nil }
            return v
        }
        return LaneCard(lane: lane, cwd: nonEmpty("cwd"), lastSessionId: nonEmpty("last_session_id"))
    }
}
