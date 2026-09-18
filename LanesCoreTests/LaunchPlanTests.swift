import XCTest
import LanesCore

final class LaunchPlanTests: XCTestCase {
    let id = "65207d77-1c2b-4d3e-8f90-0123456789ab"
    let agentBbs = "/Users/stoffee/git/agent-bbs"
    let now = Date(timeIntervalSince1970: 1_000_000)
    lazy var old = now.addingTimeInterval(-3600)

    /// Session files as Claude Code lays them out: "<project dir>/<id>" to mtime.
    func files(_ entries: [String: Date]) -> (String, String) -> Date? {
        { cwd, id in entries["\(LaunchPlan.projectDirName(forCwd: cwd))/\(id)"] }
    }

    func plan(candidate: String?,
              recorded: RecordedTab? = nil,
              card: LaneCard? = nil,
              dirs: Set<String>? = nil,
              sessionFiles: [String: Date]? = nil,
              live: Set<String> = [],
              hooks: Bool = true) -> LaunchPlan {
        let card = card ?? LaneCard(lane: "sysop", cwd: agentBbs, lastSessionId: id)
        let dirs = dirs ?? [agentBbs]
        let sessionFiles = sessionFiles ?? ["-Users-stoffee-git-agent-bbs/\(id)": old]
        return LaunchPlan.forCreate(candidate: candidate, recorded: recorded, card: card,
                                    isDirectory: { dirs.contains($0) },
                                    sessionFileModified: files(sessionFiles),
                                    liveSessionIds: live, hooksInstalled: hooks, now: now)
    }

    // MARK: projectDirName

    func testProjectDirNameReplacesEveryNonAlphanumeric() {
        XCTAssertEqual(LaunchPlan.projectDirName(forCwd: "/Users/stoffee/git/lab/hashistack-home-lab"),
                       "-Users-stoffee-git-lab-hashistack-home-lab")
        XCTAssertEqual(LaunchPlan.projectDirName(forCwd: "/a/b.c_d e"), "-a-b-c-d-e")
    }

    func testProjectDirNameReplacesNonAscii() {
        XCTAssertEqual(LaunchPlan.projectDirName(forCwd: "/x/café9"), "-x-caf-9")
    }

    // MARK: no usable cwd

    func testNilCwdOpensHomeTypesNothingRecordsNothing() {
        XCTAssertEqual(plan(candidate: nil),
                       LaunchPlan(cwd: nil, command: nil, record: nil, note: nil))
    }

    func testNonexistentCwdOpensHomeTypesNothingRecordsNothing() {
        XCTAssertEqual(plan(candidate: "/gone/repo"),
                       LaunchPlan(cwd: nil, command: nil, record: nil, note: nil))
    }

    /// Recording ~ would make it the lane's cwd next time and start claude there.
    func testHomeIsNeverRecorded() {
        for p in [plan(candidate: nil), plan(candidate: "/gone/repo")] {
            XCTAssertNil(p.cwd, "nil cwd is how the caller knows to open a plain shell in ~")
            XCTAssertNil(p.record)
        }
    }

    // MARK: resume

    func testResumesWhenEverythingHolds() {
        XCTAssertEqual(plan(candidate: agentBbs),
                       LaunchPlan(cwd: agentBbs, command: "claude --resume \(id)",
                                  record: .init(cwd: agentBbs, sessionId: id), note: nil))
    }

    func testNoSessionIdIsPlainClaudeWithoutNote() {
        let p = plan(candidate: agentBbs, card: LaneCard(lane: "sysop", cwd: agentBbs, lastSessionId: nil))
        XCTAssertEqual(p, LaunchPlan(cwd: agentBbs, command: "claude",
                                     record: .init(cwd: agentBbs, sessionId: nil), note: nil))
    }

    func testMalformedIdIsRefused() {
        let p = plan(candidate: agentBbs, card: LaneCard(lane: "sysop", cwd: agentBbs, lastSessionId: "--print"))
        XCTAssertEqual(p.command, "claude")
        XCTAssertNil(p.record?.sessionId)
        XCTAssertNotNil(p.note)
        XCTAssertFalse(p.note!.contains("--print"))
    }

    func testMissingSessionFileIsRefused() {
        let p = plan(candidate: agentBbs, sessionFiles: [:])
        XCTAssertEqual(p.command, "claude")
        XCTAssertEqual(p.record, .init(cwd: agentBbs, sessionId: nil))
        XCTAssertEqual(p.note, "not resuming 65207d77: no session file for it in this lane's directory")
    }

    /// The real sysop card: its id lives under the hashistack-home-lab
    /// project dir, but the card's cwd is agent-bbs.
    func testIdFromAnotherProjectDirIsRefused() {
        let p = plan(candidate: agentBbs,
                     sessionFiles: ["-Users-stoffee-git-lab-hashistack-home-lab/\(id)": old])
        XCTAssertEqual(p.command, "claude")
        XCTAssertEqual(p.note, "not resuming 65207d77: no session file for it in this lane's directory")
    }

    func testLiveSessionIsRefused() {
        let p = plan(candidate: agentBbs, live: [id])
        XCTAssertEqual(p.command, "claude")
        XCTAssertEqual(p.note, "not resuming 65207d77: that session is live in another tab")
    }

    func testHooksOffIsRefused() {
        let p = plan(candidate: agentBbs, hooks: false)
        XCTAssertEqual(p.command, "claude")
        XCTAssertEqual(p.note, "not resuming 65207d77: session hooks are off, so a live session can't be ruled out")
    }

    func testRecentlyWrittenSessionIsRefused() {
        let p = plan(candidate: agentBbs,
                     sessionFiles: ["-Users-stoffee-git-agent-bbs/\(id)": now.addingTimeInterval(-9 * 60)])
        XCTAssertEqual(p.command, "claude")
        XCTAssertEqual(p.note, "not resuming 65207d77: it was active under 10 minutes ago and may still be running")
    }

    /// "More than 10 minutes before now": exactly 10 is still refused.
    func testExactlyTenMinutesIsRefused() {
        let p = plan(candidate: agentBbs,
                     sessionFiles: ["-Users-stoffee-git-agent-bbs/\(id)": now.addingTimeInterval(-600)])
        XCTAssertEqual(p.command, "claude")
    }

    /// The lane reaches the typed command on both the refused and resumed paths.
    func testLaneIsThreadedIntoTheCommand() {
        let refused = LaunchPlan.forCreate(candidate: agentBbs, recorded: nil,
                                           card: LaneCard(lane: "sysop", cwd: agentBbs, lastSessionId: id),
                                           isDirectory: { $0 == self.agentBbs },
                                           sessionFileModified: files(["-Users-stoffee-git-agent-bbs/\(id)": old]),
                                           liveSessionIds: [], hooksInstalled: false, now: now, lane: "sysop")
        XCTAssertEqual(refused.command, "claude -n sysop \"/resume sysop\"")
        let resumed = LaunchPlan.forCreate(candidate: agentBbs, recorded: nil,
                                           card: LaneCard(lane: "sysop", cwd: agentBbs, lastSessionId: id),
                                           isDirectory: { $0 == self.agentBbs },
                                           sessionFileModified: files(["-Users-stoffee-git-agent-bbs/\(id)": old]),
                                           liveSessionIds: [], hooksInstalled: true, now: now, lane: "sysop")
        XCTAssertEqual(resumed.command, "claude -n sysop --resume \(id)")
    }

    func testRecordedSessionIsResumedInRecordedCwd() {
        let rid = "6d82ead5-2b7b-40e6-aa09-e90650247044"
        let rec = RecordedTab(tabId: "w1:t3", cwd: "/r", sessionId: rid, recordedAt: now)
        let p = plan(candidate: "/r", recorded: rec, dirs: ["/r"], sessionFiles: ["-r/\(rid)": old])
        XCTAssertEqual(p.command, "claude --resume \(rid)")
        XCTAssertEqual(p.record, .init(cwd: "/r", sessionId: rid))
    }
}
