import XCTest
import LanesCore

final class TabResolverTests: XCTestCase {
    func rec(_ tab: String, _ cwd: String, _ sid: String? = nil) -> RecordedTab {
        RecordedTab(tabId: tab, cwd: cwd, sessionId: sid, recordedAt: Date(timeIntervalSince1970: 0))
    }

    func testRecordedTabWithMatchingCwdIsFocused() {
        let a = TabResolver.resolve(
            lane: "speedy", recorded: rec("w1:t3", "/repo/speedy"),
            tabs: [HerdrTab(tabId: "w1:t3", label: "whatever", paneCwds: ["/repo/speedy"])],
            fallbackCwd: nil)
        XCTAssertEqual(a, .focus(tabId: "w1:t3"))
    }

    /// herdr restarted and handed the recorded id to an unrelated tab.
    func testReusedTabIdWithDifferentCwdIsNotFocused() {
        let a = TabResolver.resolve(
            lane: "speedy", recorded: rec("w1:t3", "/repo/speedy"),
            tabs: [HerdrTab(tabId: "w1:t3", label: "crypto", paneCwds: ["/repo/crypto"])],
            fallbackCwd: nil)
        XCTAssertEqual(a, .create(cwd: "/repo/speedy"))
    }

    func testExactLabelIsFocused() {
        let a = TabResolver.resolve(
            lane: "sysop", recorded: nil,
            tabs: [HerdrTab(tabId: "w2:t1", label: "sysop", paneCwds: ["/x"])],
            fallbackCwd: nil)
        XCTAssertEqual(a, .focus(tabId: "w2:t1"))
    }

    /// The failure measured in LANES-SPEC: two different lanes, one word apart.
    func testNearMissLabelIsNeverMatched() {
        let a = TabResolver.resolve(
            lane: "lilikoi-fm-the-game", recorded: nil,
            tabs: [HerdrTab(tabId: "w1:t9", label: "lilikoi-fm-the-video", paneCwds: ["/x"])],
            fallbackCwd: "/repo/game")
        XCTAssertEqual(a, .create(cwd: "/repo/game"))
    }

    func testLabelMatchIsCaseSensitive() {
        let a = TabResolver.resolve(
            lane: "Sysop", recorded: nil,
            tabs: [HerdrTab(tabId: "w2:t1", label: "sysop", paneCwds: ["/x"])],
            fallbackCwd: nil)
        XCTAssertEqual(a, .create(cwd: nil))
    }

    /// Shared case with usage_lanes' Python matcher (claude-config 33e81fc):
    /// the label differs only in case from an active seat.
    func testCaseOnlyLabelDoesNotMatchLane() {
        let a = TabResolver.resolve(
            lane: "sysop", recorded: nil,
            tabs: [HerdrTab(tabId: "w2:t1", label: "Sysop", paneCwds: ["/x"])],
            fallbackCwd: nil)
        XCTAssertEqual(a, .create(cwd: nil))
    }

    /// Shared case with the Python matcher: a junk label that is a substring
    /// of a seat name ("1" in "gr1ndz") is never a match.
    func testSubstringLabelIsNeverMatched() {
        let a = TabResolver.resolve(
            lane: "gr1ndz", recorded: nil,
            tabs: [HerdrTab(tabId: "w1:t1", label: "1", paneCwds: ["/x"])],
            fallbackCwd: nil)
        XCTAssertEqual(a, .create(cwd: nil))
    }

    func testDuplicateExactLabelsAreAmbiguous() {
        let a = TabResolver.resolve(
            lane: "sysop", recorded: nil,
            tabs: [HerdrTab(tabId: "a", label: "sysop", paneCwds: []),
                   HerdrTab(tabId: "b", label: "sysop", paneCwds: [])],
            fallbackCwd: nil)
        XCTAssertEqual(a, .create(cwd: nil))
    }

    func testRecordedCwdBeatsFallbackOnCreate() {
        let a = TabResolver.resolve(lane: "x", recorded: rec("gone", "/recorded"), tabs: [], fallbackCwd: "/roster")
        XCTAssertEqual(a, .create(cwd: "/recorded"))
    }

    func testResumeUsesRecordedSession() {
        XCTAssertEqual(ResumeCommand.forNewTab(cwd: "/r", sessionId: "6d82ead5-2b7b-40e6-aa09-e90650247044"),
                       "claude --resume 6d82ead5-2b7b-40e6-aa09-e90650247044")
    }

    func testResumeWithoutSessionIsPlainClaude() {
        XCTAssertEqual(ResumeCommand.forNewTab(cwd: "/r", sessionId: nil), "claude")
    }

    func testNoCwdMeansNoClaude() {
        XCTAssertNil(ResumeCommand.forNewTab(cwd: nil, sessionId: "abc"))
    }

    /// The id is typed into a shell.
    func testShellMetacharactersInSessionIdAreRefused() {
        XCTAssertEqual(ResumeCommand.forNewTab(cwd: "/r", sessionId: "x; rm -rf ~"), "claude")
    }

    func testNonAsciiSessionIdIsRefused() {
        XCTAssertEqual(ResumeCommand.forNewTab(cwd: "/r", sessionId: "abcé"), "claude")
    }

    /// A flag-shaped id must never reach the command line.
    func testFlagShapedSessionIdIsRefused() {
        XCTAssertEqual(ResumeCommand.forNewTab(cwd: "/r", sessionId: "--print"), "claude")
    }

    /// Session files are named by lowercase UUID; anything else is not a real id.
    func testNonCanonicalUuidIsRefused() {
        XCTAssertEqual(ResumeCommand.forNewTab(cwd: "/r", sessionId: "6D82EAD5-2B7B-40E6-AA09-E90650247044"), "claude")
    }

    func testRecordedSessionWins() {
        let card = LaneCard(lane: "x", cwd: "/r", lastSessionId: "card-id")
        XCTAssertEqual(ResumeCommand.sessionId(forCwd: "/r", recorded: rec("t", "/r", "rec-id"), card: card), "rec-id")
    }

    /// claude --resume looks sessions up per directory, so a card id is only
    /// usable when the tab opens in the card's own cwd.
    func testCardSessionOnlyInCardCwd() {
        let card = LaneCard(lane: "x", cwd: "/card", lastSessionId: "card-id")
        XCTAssertEqual(ResumeCommand.sessionId(forCwd: "/card", recorded: nil, card: card), "card-id")
        XCTAssertNil(ResumeCommand.sessionId(forCwd: "/elsewhere", recorded: nil, card: card))
    }

    func testNoSourcesMeansNoSession() {
        XCTAssertNil(ResumeCommand.sessionId(forCwd: "/r", recorded: nil, card: nil))
    }
}
