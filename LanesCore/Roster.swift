import Foundation

/// One seat from the board roster (`GET /agents?json=1`). A lane IS a seat
/// (LANES-SPEC D1), so this is also the lane index.
public struct RosterSeat: Equatable, Sendable {
    public let name: String
    public let lane: String?
    public let workdir: String?
    public let lastSeen: Date?
    public let isActive: Bool

    public init(name: String, lane: String?, workdir: String?, lastSeen: Date?, isActive: Bool) {
        self.name = name
        self.lane = lane
        self.workdir = workdir
        self.lastSeen = lastSeen
        self.isActive = isActive
    }
}

public enum Roster {
    public enum ParseError: Error, Equatable { case notARoster }

    public static func parse(_ data: Data) throws -> [RosterSeat] {
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let agents = obj["agents"] as? [[String: Any]] else { throw ParseError.notARoster }

        // The board writes last_seen in its own local time, which is Pacific
        // (measured 2026-09-17). Parsing it in the viewer's zone would skew
        // every lane by 3h whenever Stoaf is in Hawaii.
        let lastSeen = DateFormatter()
        lastSeen.locale = Locale(identifier: "en_US_POSIX")
        lastSeen.timeZone = TimeZone(identifier: "America/Los_Angeles")
        lastSeen.dateFormat = "yyyy-MM-dd HH:mm"

        return agents.compactMap { a in
            guard let name = a["name"] as? String, !name.isEmpty else { return nil }
            return RosterSeat(
                name: name,
                lane: unsetIfDash(a["lane"]),
                workdir: unsetIfDash(a["workdir"]),
                lastSeen: (a["last_seen"] as? String).flatMap { lastSeen.date(from: $0) },
                // Anything but "active" reads "retired <date>" or "renamed-><seat>".
                isActive: (a["status"] as? String) == "active"
            )
        }
    }

    /// The board writes "-" for an unset field.
    static func unsetIfDash(_ value: Any?) -> String? {
        guard let s = value as? String, !s.isEmpty, s != "-" else { return nil }
        return s
    }
}
