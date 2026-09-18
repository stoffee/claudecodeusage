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
    /// previous cache is served.
    func fetch(_ path: String, cacheAs name: String, validate: (Data) -> Bool) async -> Fetched? {
        let cacheURL = Self.cacheDir.appendingPathComponent(name)

        if let url = URL(string: path, relativeTo: Self.baseURL),
           let result = try? await session.data(from: url),
           (result.1 as? HTTPURLResponse)?.statusCode == 200,
           validate(result.0) {
            try? FileManager.default.createDirectory(at: Self.cacheDir, withIntermediateDirectories: true)
            try? result.0.write(to: cacheURL, options: .atomic)
            return Fetched(data: result.0, at: Date(), fromCache: false)
        }

        guard let data = try? Data(contentsOf: cacheURL),
              let at = (try? FileManager.default.attributesOfItem(atPath: cacheURL.path))?[.modificationDate] as? Date
        else { return nil }
        return Fetched(data: data, at: at, fromCache: true)
    }
}
