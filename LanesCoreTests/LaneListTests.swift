import XCTest
import LanesCore

final class LaneListTests: XCTestCase {
    func seat(_ name: String, _ seen: TimeInterval?, active: Bool = true, workdir: String? = nil) -> RosterSeat {
        RosterSeat(name: name, lane: nil, workdir: workdir,
                   lastSeen: seen.map { Date(timeIntervalSince1970: $0) }, isActive: active)
    }

    func testSortsByOpenDescThenOldestFirst() {
        let lanes = LaneList.dormant(
            roster: [seat("old-empty", 100), seat("busy", 500), seat("stale-busy", 50), seat("new-empty", 900)],
            openCounts: ["busy": 3, "stale-busy": 3],
            recordedCwd: [:], cardCwd: [:], liveLanes: [])
        XCTAssertEqual(lanes.map(\.name), ["stale-busy", "busy", "old-empty", "new-empty"])
    }

    func testExcludesInactiveAndLive() {
        let lanes = LaneList.dormant(
            roster: [seat("a", 1), seat("gone", 1, active: false), seat("working", 1)],
            openCounts: [:], recordedCwd: [:], cardCwd: [:], liveLanes: ["working"])
        XCTAssertEqual(lanes.map(\.name), ["a"])
    }

    func testNeverSeenSortsBeforeSeen() {
        let lanes = LaneList.dormant(roster: [seat("seen", 1), seat("never", nil)],
                                     openCounts: [:], recordedCwd: [:], cardCwd: [:], liveLanes: [])
        XCTAssertEqual(lanes.map(\.name), ["never", "seen"])
    }

    func testTiesBreakByName() {
        let lanes = LaneList.dormant(roster: [seat("b", 1), seat("a", 1)],
                                     openCounts: [:], recordedCwd: [:], cardCwd: [:], liveLanes: [])
        XCTAssertEqual(lanes.map(\.name), ["a", "b"])
    }

    func testRecordedCwdBeatsRosterWorkdir() {
        let lanes = LaneList.dormant(
            roster: [seat("h", 1, workdir: "/roster/path"), seat("r", 1, workdir: "/roster/only"), seat("n", 1)],
            openCounts: [:], recordedCwd: ["h": "/recorded/path"], cardCwd: [:], liveLanes: [])
        XCTAssertEqual(lanes.first { $0.name == "h" }?.cwd, "/recorded/path")
        XCTAssertEqual(lanes.first { $0.name == "r" }?.cwd, "/roster/only")
        XCTAssertNil(lanes.first { $0.name == "n" }?.cwd)
    }

    /// Order: hook-recorded, then lane card, then roster workdir.
    func testCardCwdSitsBetweenRecordedAndRoster() {
        let lanes = LaneList.dormant(
            roster: [seat("both", 1, workdir: "/roster"), seat("card", 1, workdir: "/roster"), seat("onlycard", 1)],
            openCounts: [:],
            recordedCwd: ["both": "/recorded"],
            cardCwd: ["both": "/card", "card": "/card", "onlycard": "/card"],
            liveLanes: [])
        XCTAssertEqual(lanes.first { $0.name == "both" }?.cwd, "/recorded")
        XCTAssertEqual(lanes.first { $0.name == "card" }?.cwd, "/card")
        XCTAssertEqual(lanes.first { $0.name == "onlycard" }?.cwd, "/card")
    }

    func testOpenCountDefaultsToZero() {
        let lanes = LaneList.dormant(roster: [seat("a", 1)], openCounts: [:], recordedCwd: [:], cardCwd: [:], liveLanes: [])
        XCTAssertEqual(lanes.first?.openItems, 0)
    }
}
