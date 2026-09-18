import Foundation

public struct Lane: Equatable, Sendable, Identifiable {
    public var id: String { name }
    public let name: String
    public let lastSeen: Date?
    public let openItems: Int
    /// Best known repo path: where the lane was last RECORDED working, else
    /// its lane card's cwd, else the roster's workdir, else nil. Never guessed
    /// from the lane's name.
    public let cwd: String?

    public init(name: String, lastSeen: Date?, openItems: Int, cwd: String?) {
        self.name = name
        self.lastSeen = lastSeen
        self.openItems = openItems
        self.cwd = cwd
    }
}

public enum LaneList {
    /// The lanes listed under the live sessions.
    ///
    /// - Active seats only. Retired and renamed seats are not lanes.
    /// - Every active seat is listed, `stoaf` and any junk seats included.
    ///   The board's roster decides what a lane is (LANES-SPEC non-goal), not
    ///   this app. A bad lane is fixed by retiring its seat on the board.
    /// - Lanes with a live session are left out: they already render above.
    /// - Sort: open items desc, then last seen asc (never seen first), then
    ///   name. The interesting row is the lane with work nobody has touched.
    public static func dormant(roster: [RosterSeat],
                               openCounts: [String: Int],
                               recordedCwd: [String: String],
                               cardCwd: [String: String],
                               liveLanes: Set<String>) -> [Lane] {
        roster
            .filter { $0.isActive && !liveLanes.contains($0.name) }
            .map { seat in
                Lane(name: seat.name,
                     lastSeen: seat.lastSeen,
                     openItems: openCounts[seat.name] ?? 0,
                     cwd: recordedCwd[seat.name] ?? cardCwd[seat.name] ?? seat.workdir)
            }
            .sorted { a, b in
                if a.openItems != b.openItems { return a.openItems > b.openItems }
                switch (a.lastSeen, b.lastSeen) {
                case let (x?, y?) where x != y: return x < y
                case (nil, _?): return true
                case (_?, nil): return false
                default: return a.name < b.name
                }
            }
    }
}
