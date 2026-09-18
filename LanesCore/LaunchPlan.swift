import Foundation

/// What happens when a lane click resolves to `.create(cwd:)`: where the new
/// tab opens, what gets typed into it, and what is recorded for the lane.
///
/// Pure. Every side effect (the filesystem, the live session set, the clock)
/// is passed in, so the resume rules can be tested without a disk.
///
/// The rule it exists for: `claude --resume` on a session that is still
/// running in another tab gives two processes writing the same transcript.
/// So a resume happens only when a live session can be ruled out; anything
/// short of that types plain `claude` and says why.
public struct LaunchPlan: Equatable, Sendable {
    /// What to record for the lane once the tab exists (its id is only known
    /// then). Always a real directory, never the ~ fallback.
    public struct Record: Equatable, Sendable {
        public let cwd: String
        /// Set only when the tab resumes this session.
        public let sessionId: String?

        public init(cwd: String, sessionId: String?) {
            self.cwd = cwd
            self.sessionId = sessionId
        }
    }

    /// Directory to open the tab in. nil means a plain shell in ~.
    public let cwd: String?
    /// Text to type into the tab. nil means type nothing.
    public let command: String?
    public let record: Record?
    /// Why a resume was refused, for the user. nil when none was refused.
    public let note: String?

    public init(cwd: String?, command: String?, record: Record?, note: String?) {
        self.cwd = cwd
        self.command = command
        self.record = record
        self.note = note
    }

    /// A session file this recent may belong to a running session that the
    /// hooks have not reported yet.
    public static let quietPeriod: TimeInterval = 10 * 60

    /// Claude Code's directory name under `~/.claude/projects/` for `cwd`:
    /// every character that is not an ASCII letter or digit becomes "-".
    /// Counted in UTF-16 units, as Claude Code's JavaScript regex does.
    public static func projectDirName(forCwd cwd: String) -> String {
        String(cwd.utf16.map { u -> Character in
            switch u {
            case 0x30...0x39, 0x41...0x5A, 0x61...0x7A: return Character(Unicode.Scalar(u)!)
            default: return "-"
            }
        })
    }

    /// - Parameters:
    ///   - candidate: the cwd `TabResolver` chose, possibly stale.
    ///   - isDirectory: whether a path is an existing directory.
    ///   - sessionFileModified: modification date of
    ///     `~/.claude/projects/<projectDirName(cwd)>/<id>.jsonl`, nil if missing.
    ///   - liveSessionIds: every session id the hooks currently report.
    ///   - hooksInstalled: without hooks, `liveSessionIds` proves nothing.
    public static func forCreate(candidate: String?, recorded: RecordedTab?, card: LaneCard?,
                                 isDirectory: (String) -> Bool,
                                 sessionFileModified: (_ cwd: String, _ id: String) -> Date?,
                                 liveSessionIds: Set<String>,
                                 hooksInstalled: Bool,
                                 now: Date) -> LaunchPlan {
        // A cwd that no longer exists (moved repo, stale card) counts as
        // unknown: claude must not start somewhere we guessed.
        guard let cwd = candidate, isDirectory(cwd) else {
            return LaunchPlan(cwd: nil, command: nil, record: nil, note: nil)
        }

        func plain(_ note: String?) -> LaunchPlan {
            LaunchPlan(cwd: cwd, command: ResumeCommand.forNewTab(cwd: cwd, sessionId: nil),
                       record: Record(cwd: cwd, sessionId: nil), note: note)
        }

        guard let id = ResumeCommand.sessionId(forCwd: cwd, recorded: recorded, card: card) else {
            return plain(nil)
        }
        // Checked before the id is shown anywhere: it may be junk.
        guard ResumeCommand.isResumableId(id) else {
            return plain("not resuming: the recorded session id is not a valid session id")
        }

        let short = String(id.prefix(8))
        guard let modified = sessionFileModified(cwd, id) else {
            return plain("not resuming \(short): no session file for it in this lane's directory")
        }
        if liveSessionIds.contains(id) {
            return plain("not resuming \(short): that session is live in another tab")
        }
        if !hooksInstalled {
            return plain("not resuming \(short): session hooks are off, so a live session can't be ruled out")
        }
        if now.timeIntervalSince(modified) <= quietPeriod {
            return plain("not resuming \(short): it was active under 10 minutes ago and may still be running")
        }

        return LaunchPlan(cwd: cwd, command: ResumeCommand.forNewTab(cwd: cwd, sessionId: id),
                          record: Record(cwd: cwd, sessionId: id), note: nil)
    }
}
