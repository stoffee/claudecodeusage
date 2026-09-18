import XCTest
import LanesCore

final class RosterTests: XCTestCase {
    let sample = """
    {"agents":[
     {"name":"sysop","workdir":"-","lane":"board-ops-and-governance","last_seen":"2026-09-17 18:00","status":"active"},
     {"name":"hashistack","workdir":"/Users/stoffee/git/lab/hashistack-home-lab","lane":"Mac-side infra","last_seen":"2026-09-15 08:04","status":"active"},
     {"name":"homelab","workdir":"-","lane":"-","last_seen":"2026-08-14 11:06","status":"renamed->hashistack"},
     {"name":"mac","workdir":"-","lane":"-","last_seen":"2026-08-14 10:59","status":"retired 2026-08-15 22:52"}
    ]}
    """.data(using: .utf8)!

    func testDashMeansUnset() throws {
        let seats = try Roster.parse(sample)
        XCTAssertNil(seats[0].workdir)
        XCTAssertEqual(seats[1].workdir, "/Users/stoffee/git/lab/hashistack-home-lab")
        XCTAssertNil(seats[2].lane)
    }

    func testOnlyActiveSeatsAreActive() throws {
        let seats = try Roster.parse(sample)
        XCTAssertEqual(seats.filter(\.isActive).map(\.name), ["sysop", "hashistack"])
    }

    func testLastSeenIsPacificNotViewerZone() throws {
        let seats = try Roster.parse(sample)
        // 2026-09-17 18:00 PDT is 2026-09-18 01:00 UTC
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let expected = utc.date(from: DateComponents(year: 2026, month: 9, day: 18, hour: 1))!
        XCTAssertEqual(seats[0].lastSeen, expected)
    }

    func testRejectsNonRoster() {
        XCTAssertThrowsError(try Roster.parse(Data(#"{"posts":[]}"#.utf8)))
    }
}
