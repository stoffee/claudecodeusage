import Foundation

/// Read-only client for bbs.stoffee.io. Holds no token and never writes
/// (LANES-SPEC non-goal: the app reads, /done writes).
///
/// Every good response is cached to disk. When the board is unreachable the
/// cache is served and `Fetched.fromCache` says so, so the UI can label it.
/// On 2026-09-14 a fallback served an empty database as if it were live and
/// the outage went unseen for ten minutes. Never present stale data as live.
struct BoardClient {
    struct Fetched {
        let data: Data
        let at: Date
        let fromCache: Bool
        /// nil for live data. Set when this is served from cache, to a short
        /// reason the live fetch failed: "timed out", "HTTP <code>",
        /// "unexpected response" (a bad URL or failed validation), or the
        /// error's localizedDescription.
        let liveFailure: String?
    }

    /// `defaults write com.helpfully.ClaudeUsage boardBaseURL http://127.0.0.1:9`
    /// points the app at a dead port, which is how the cached path is tested.
    static var baseURL: URL {
        if let s = UserDefaults.standard.string(forKey: "boardBaseURL"), let u = URL(string: s) { return u }
        return URL(string: "http://bbs.stoffee.io")!
    }

    static let cacheDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/claudeusage/board-cache", isDirectory: true)

    private let session: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 5
        c.timeoutIntervalForResource = 10
        return URLSession(configuration: c)
    }()

    /// `path` is the board path with query; `name` the cache file. Fresh data
    /// is only accepted, and cached, when `validate` passes; otherwise the
    /// previous cache is served, labelled with why the live fetch failed.
    func fetch(_ path: String, cacheAs name: String, validate: (Data) -> Bool) async -> Fetched? {
        let cacheURL = Self.cacheDir.appendingPathComponent(name)

        let (live, failureReason) = await fetchLive(path, validate: validate)
        if let live {
            try? FileManager.default.createDirectory(at: Self.cacheDir, withIntermediateDirectories: true)
            try? live.write(to: cacheURL, options: .atomic)
            return Fetched(data: live, at: Date(), fromCache: false, liveFailure: nil)
        }

        guard let data = try? Data(contentsOf: cacheURL),
              let at = (try? FileManager.default.attributesOfItem(atPath: cacheURL.path))?[.modificationDate] as? Date
        else { return nil }
        return Fetched(data: data, at: at, fromCache: true, liveFailure: failureReason)
    }

    /// The live half of `fetch`. Returns the body on success, or a short
    /// failure reason on failure.
    private func fetchLive(_ path: String, validate: (Data) -> Bool) async -> (Data?, String?) {
        guard let url = URL(string: path, relativeTo: Self.baseURL) else { return (nil, "unexpected response") }
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse else { return (nil, "unexpected response") }
            guard http.statusCode == 200 else { return (nil, "HTTP \(http.statusCode)") }
            guard validate(data) else { return (nil, "unexpected response") }
            return (data, nil)
        } catch {
            if (error as? URLError)?.code == .timedOut { return (nil, "timed out") }
            return (nil, error.localizedDescription)
        }
    }
}
