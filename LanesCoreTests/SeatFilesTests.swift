import XCTest
import LanesCore

final class SeatFilesTests: XCTestCase {
    /// Parsed the same way the session hook reads the file.
    func testSeatsIgnoreCommentsBlanksAndCarriageReturns() {
        let contents = "# seats in this repo\r\n\n  hashistack  # the main one\r\ncamera-detection\n"
        XCTAssertEqual(SeatFiles.seats(in: contents), ["hashistack", "camera-detection"])
    }

    func testSingleSeatFileGivesItsFolder() {
        let folders = SeatFiles.folders(from: [
            (folder: "/Users/stoffee/git/lab/hale-awamoa", contents: "hale-awamoa\n"),
        ])
        XCTAssertEqual(folders, ["hale-awamoa": "/Users/stoffee/git/lab/hale-awamoa"])
    }

    /// A multi-seat file cannot say which seat owns the folder.
    func testMultiSeatFileIsIgnored() {
        let folders = SeatFiles.folders(from: [
            (folder: "/repo", contents: "hashistack\ncamera-detection\n"),
        ])
        XCTAssertEqual(folders, [:])
    }

    /// Two folders both claiming one seat is ambiguous, so neither wins.
    func testSeatClaimedByTwoFoldersIsDropped() {
        let folders = SeatFiles.folders(from: [
            (folder: "/Users/stoffee/git/lilikoi-fm", contents: "lilikoi-fm\n"),
            (folder: "/Users/stoffee/git/lab/hashistack-home-lab/lilikoi-fm", contents: "lilikoi-fm\n"),
            (folder: "/Users/stoffee/git/agent-bbs", contents: "sysop\n"),
        ])
        XCTAssertEqual(folders, ["sysop": "/Users/stoffee/git/agent-bbs"])
    }

    func testEmptyOrCommentOnlyFileIsIgnored() {
        XCTAssertEqual(SeatFiles.folders(from: [(folder: "/x", contents: "# nothing here\n\n")]), [:])
    }
}
