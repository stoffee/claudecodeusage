import XCTest
import LanesCore

final class WorkItemsTests: XCTestCase {
    func thread(_ posts: [[String: Any]]) -> Data {
        try! JSONSerialization.data(withJSONObject: ["posts": posts])
    }

    func post(_ id: Int, _ body: String, supersededBy: Int? = nil) -> [String: Any] {
        ["id": id, "body": body, "superseded_by": supersededBy.map { $0 as Any } ?? NSNull()]
    }

    func testCountsOpenItemsPerLane() throws {
        let d = thread([
            post(1, "WORK: a\nLANE: speedy\nSTATE: open"),
            post(2, "WORK: b\nLANE: speedy\nSTATE: open"),
            post(3, "WORK: c\nLANE: octopi\nSTATE: open"),
        ])
        XCTAssertEqual(try WorkItems.openCounts(d), ["speedy": 2, "octopi": 1])
    }

    func testClosesRemovesItem() throws {
        let d = thread([
            post(10, "WORK: a\nLANE: speedy\nSTATE: open"),
            post(11, "Shipped it. Closes /p/10"),
        ])
        XCTAssertEqual(try WorkItems.openCounts(d), [:])
    }

    func testOnlyOpenStateCounts() throws {
        let d = thread([
            post(1, "WORK: a\nLANE: x\nSTATE: done"),
            post(2, "WORK: b\nLANE: x\nSTATE: claimed"),
            post(3, "WORK: c\nLANE: x\nSTATE: blocked"),
            post(4, "WORK: d\nLANE: x\nSTATE: open"),
        ])
        XCTAssertEqual(try WorkItems.openCounts(d), ["x": 1])
    }

    func testStateTakesFirstWordOnly() throws {
        let d = thread([post(1, "WORK: a\nLANE: x\nSTATE: open (was claimed)")])
        XCTAssertEqual(try WorkItems.openCounts(d), ["x": 1])
    }

    func testSupersededIsNotCounted() throws {
        let d = thread([
            post(1, "WORK: old\nLANE: x\nSTATE: open", supersededBy: 2),
            post(2, "WORK: new\nLANE: x\nSTATE: open"),
        ])
        XCTAssertEqual(try WorkItems.openCounts(d), ["x": 1])
    }

    func testNonWorkPostsIgnored() throws {
        let d = thread([post(1, "chatter\nLANE: x\nSTATE: open")])
        XCTAssertEqual(try WorkItems.openCounts(d), [:])
    }

    func testRejectsNonThread() {
        XCTAssertThrowsError(try WorkItems.openCounts(Data(#"{"agents":[]}"#.utf8)))
    }

    /// Posts written on Windows arrive with CRLF line endings.
    func testCRLFBodyIsCounted() throws {
        let d = thread([post(1, "WORK: a\r\nLANE: speedy\r\nSTATE: open\r\n")])
        XCTAssertEqual(try WorkItems.openCounts(d), ["speedy": 1])
    }
}
