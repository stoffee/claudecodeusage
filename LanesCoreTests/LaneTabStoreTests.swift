import XCTest
import LanesCore

final class LaneTabStoreTests: XCTestCase {
    var url: URL!

    override func setUp() {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lane-tabs-\(UUID().uuidString).json")
    }

    override func tearDown() { try? FileManager.default.removeItem(at: url) }

    func tab(_ id: String, at t: TimeInterval) -> RecordedTab {
        RecordedTab(tabId: id, cwd: "/r", sessionId: "s", recordedAt: Date(timeIntervalSince1970: t))
    }

    func testRoundTripsThroughDisk() {
        LaneTabStore(url: url).record(lane: "speedy", tab("w1:t3", at: 100))
        XCTAssertEqual(LaneTabStore(url: url).all()["speedy"], tab("w1:t3", at: 100))
    }

    func testNewerRecordWins() {
        let s = LaneTabStore(url: url)
        s.record(lane: "speedy", tab("old", at: 100))
        s.record(lane: "speedy", tab("new", at: 200))
        XCTAssertEqual(s.all()["speedy"]?.tabId, "new")
    }

    func testOlderRecordIsIgnored() {
        let s = LaneTabStore(url: url)
        s.record(lane: "speedy", tab("new", at: 200))
        s.record(lane: "speedy", tab("old", at: 100))
        XCTAssertEqual(s.all()["speedy"]?.tabId, "new")
    }

    func testMissingFileIsEmpty() {
        XCTAssertEqual(LaneTabStore(url: url).all(), [:])
    }
}
