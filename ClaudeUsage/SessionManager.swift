import Foundation

struct SessionEntry: Codable, Identifiable {
    let sessionId: String
    let fullPath: String?
    let fileMtime: Double?
    let firstPrompt: String?
    let summary: String?
    let messageCount: Int?
    let created: String?
    let modified: String?
    let gitBranch: String?
    let projectPath: String?
    let isSidechain: Bool?

    var id: String { sessionId }

    var displayTitle: String {
        if let summary = summary, !summary.isEmpty {
            return summary
        }
        if let prompt = firstPrompt, !prompt.isEmpty, prompt != "No prompt" {
            return String(prompt.prefix(60))
        }
        return "Untitled Session"
    }

    var shortProjectName: String {
        guard let path = projectPath, !path.isEmpty else { return "~" }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path == home { return "~" }
        if path.hasPrefix(home) {
            let relative = String(path.dropFirst(home.count + 1))
            // Show last 2 path components for context
            let parts = relative.split(separator: "/")
            if parts.count <= 2 { return relative }
            return parts.suffix(2).joined(separator: "/")
        }
        return (path as NSString).lastPathComponent
    }

    var modifiedDate: Date? {
        guard let modified = modified else { return nil }
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = fmt.date(from: modified) { return d }
        fmt.formatOptions = [.withInternetDateTime]
        return fmt.date(from: modified)
    }

    var relativeModified: String {
        guard let date = modifiedDate else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    var branchDisplay: String? {
        guard let branch = gitBranch, !branch.isEmpty else { return nil }
        return branch
    }
}

struct SessionsIndex: Codable {
    let version: Int?
    let entries: [SessionEntry]
    let originalPath: String?
}

@MainActor
class SessionManager: ObservableObject {
    @Published var sessions: [SessionEntry] = []
    @Published var isLoading = false

    func loadSessions() {
        isLoading = true
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let projectsDir = "\(homeDir)/.claude/projects"

        Task.detached { [weak self] in
            var allSessions: [SessionEntry] = []
            let fm = FileManager.default

            guard let dirs = try? fm.contentsOfDirectory(atPath: projectsDir) else {
                await MainActor.run {
                    self?.sessions = []
                    self?.isLoading = false
                }
                return
            }

            for dir in dirs {
                let indexPath = "\(projectsDir)/\(dir)/sessions-index.json"
                guard fm.fileExists(atPath: indexPath),
                      let data = fm.contents(atPath: indexPath) else { continue }
                do {
                    let index = try JSONDecoder().decode(SessionsIndex.self, from: data)
                    allSessions.append(contentsOf: index.entries)
                } catch {
                    continue
                }
            }

            // Sort by modified date, most recent first; fall back to fileMtime
            allSessions.sort { a, b in
                let aDate = a.modifiedDate ?? Date(timeIntervalSince1970: (a.fileMtime ?? 0) / 1000)
                let bDate = b.modifiedDate ?? Date(timeIntervalSince1970: (b.fileMtime ?? 0) / 1000)
                return aDate > bDate
            }

            await MainActor.run {
                self?.sessions = allSessions
                self?.isLoading = false
            }
        }
    }

    func resumeSession(_ session: SessionEntry) {
        let projectPath = session.projectPath ?? FileManager.default.homeDirectoryForCurrentUser.path
        // Escape for AppleScript string (backslash and double-quote)
        let escapedPath = projectPath
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let escapedId = session.sessionId
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let script = """
        tell application "iTerm2"
            activate
            if (count of windows) = 0 then
                create window with default profile
                tell current session of current window
                    write text "cd \\"\(escapedPath)\\" && claude --resume \\"\(escapedId)\\""
                end tell
            else
                tell current window
                    create tab with default profile
                    tell current session
                        write text "cd \\"\(escapedPath)\\" && claude --resume \\"\(escapedId)\\""
                    end tell
                end tell
            end if
        end tell
        """

        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }
}
