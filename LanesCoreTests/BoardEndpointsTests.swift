import XCTest
import LanesCore

final class BoardEndpointsTests: XCTestCase {
    func testDefaultIsEdgeThenConsul() {
        XCTAssertEqual(BoardEndpoints.candidates(override: nil),
                       [URL(string: "http://bbs.stoffee.io")!,
                        URL(string: "http://agent-bbs.service.consul:8899")!])
    }

    func testBlankOverrideMeansDefault() {
        XCTAssertEqual(BoardEndpoints.candidates(override: "  "),
                       [BoardEndpoints.primary, BoardEndpoints.consul])
    }

    /// A comma list is tried in order. This is how the fallback is tested on the
    /// real app: a dead first entry, then consul.
    func testCommaListIsTriedInOrder() {
        XCTAssertEqual(BoardEndpoints.candidates(override: "http://127.0.0.1:9, http://agent-bbs.service.consul:8899"),
                       [URL(string: "http://127.0.0.1:9")!, BoardEndpoints.consul])
    }

    func testOverrideWithNoUsableUrlMeansDefault() {
        XCTAssertEqual(BoardEndpoints.candidates(override: "not a url, ,"),
                       [BoardEndpoints.primary, BoardEndpoints.consul])
    }
}
