import Foundation

/// A lane card from `~/.claude/lanes/<lane>.json`, written by the /resume
/// tooling in claude-config (contract: `written_by` is "lane-card-v1" or
/// "lane-card-v2"; v2 added `last_session_id`).
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

    /// nil for anything that is not a v1 or v2 card, so a future format
    /// change is ignored rather than misread.
    public static func parse(_ data: Data) -> LaneCard? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let version = obj["written_by"] as? String,
              version == "lane-card-v1" || version == "lane-card-v2",
              let lane = obj["lane"] as? String, !lane.isEmpty else { return nil }
        func nonEmpty(_ key: String) -> String? {
            guard let v = obj[key] as? String, !v.isEmpty else { return nil }
            return v
        }
        // v1 has no last_session_id; only v2 is trusted to carry one.
        let sessionId = version == "lane-card-v2" ? nonEmpty("last_session_id") : nil
        return LaneCard(lane: lane, cwd: nonEmpty("cwd"), lastSessionId: sessionId)
    }
}
