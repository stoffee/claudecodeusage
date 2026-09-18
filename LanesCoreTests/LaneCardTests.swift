import XCTest
import LanesCore

final class LaneCardTests: XCTestCase {
    func card(_ fields: [String: Any]) -> Data {
        var base: [String: Any] = ["written_by": "lane-card-v2", "lane": "sysop",
                                   "cwd": "/Users/stoffee/git/agent-bbs",
                                   "last_session_web": "016Gae2J", "last_session_id": NSNull()]
        fields.forEach { base[$0.key] = $0.value }
        return try! JSONSerialization.data(withJSONObject: base)
    }

    func testParsesTheCurrentContract() {
        XCTAssertEqual(LaneCard.parse(card([:])),
                       LaneCard(lane: "sysop", cwd: "/Users/stoffee/git/agent-bbs", lastSessionId: nil))
    }

    func testReadsLocalSessionIdWhenProven() {
        let id = "6d82ead5-2b7b-40e6-aa09-e90650247044"
        XCTAssertEqual(LaneCard.parse(card(["last_session_id": id]))?.lastSessionId, id)
    }

    /// last_session_web is a claude.ai prefix and must never be used to resume.
    func testNeverFallsBackToWebPrefix() {
        XCTAssertNil(LaneCard.parse(card([:]))?.lastSessionId)
    }

    func testUnknownVersionIsIgnored() {
        XCTAssertNil(LaneCard.parse(card(["written_by": "lane-card-v3"])))
    }

    func testMissingVersionIsIgnored() {
        XCTAssertNil(LaneCard.parse(card(["written_by": NSNull()])))
    }

    /// v1 has no last_session_id, so it only contributes a cwd.
    func testV1CardStillYieldsItsCwd() {
        let v1 = try! JSONSerialization.data(withJSONObject: [
            "written_by": "lane-card-v1", "lane": "sysop", "cwd": "/Users/stoffee/git/agent-bbs"])
        XCTAssertEqual(LaneCard.parse(v1),
                       LaneCard(lane: "sysop", cwd: "/Users/stoffee/git/agent-bbs", lastSessionId: nil))
    }

    func testV1CardNeverYieldsASessionId() {
        XCTAssertNil(LaneCard.parse(card(["written_by": "lane-card-v1",
                                          "last_session_id": "6d82ead5-2b7b-40e6-aa09-e90650247044"]))?.lastSessionId)
    }

    func testEmptyCwdIsUnset() {
        XCTAssertNil(LaneCard.parse(card(["cwd": ""]))?.cwd)
    }
}
