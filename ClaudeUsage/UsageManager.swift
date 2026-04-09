import Foundation
import Security

struct UsageData {
    let sessionUtilization: Double
    let sessionResetsAt: Date?
    let weeklyUtilization: Double
    let weeklyResetsAt: Date?
    let sonnetUtilization: Double?
    let sonnetResetsAt: Date?
    let extraUsageEnabled: Bool
    let extraUsageMonthlyLimit: Double?
    let extraUsageUsedCredits: Double?

    var sessionPercentage: Int { Int(sessionUtilization) }
    var weeklyPercentage: Int { Int(weeklyUtilization) }
    var sonnetPercentage: Int? { sonnetUtilization.map { Int($0) } }
    var extraUsagePercentage: Int? {
        guard extraUsageEnabled, let limit = extraUsageMonthlyLimit, let used = extraUsageUsedCredits, limit > 0 else { return nil }
        return Int((used / limit) * 100)
    }
}

struct TokenStats {
    let todayTokens: Int
    let weekTokens: Int
    let mostActiveDay: String      // e.g. "Apr 8"
    let mostActiveDayTokens: Int
    let currentStreak: Int         // consecutive active days up to today
}

@MainActor
class UsageManager: ObservableObject {
    @Published var usage: UsageData?
    @Published var error: String?
    @Published var isLoading = false
    @Published var lastUpdated: Date?
    @Published var subscriptionType: String?
    @Published var claudeUsername: String?
    @Published var tokenStats: TokenStats?
    static let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    static let claudeCodeVersion: String = {
        // Detect installed Claude Code version for User-Agent
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["claude", "--version"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            if let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) {
                // Output is like "2.1.69 (Claude Code)" - extract version number
                let version = output.split(separator: " ").first.map(String.init) ?? output
                if !version.isEmpty { return version }
            }
        } catch {}
        return "2.1.0"
    }()

    // Configured URLSession with timeouts
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }()

    var statusEmoji: String {
        guard let usage = usage else { return "❓" }
        let maxUtil = max(usage.sessionUtilization, usage.weeklyUtilization)
        if maxUtil >= 90 { return "🔴" }
        if maxUtil >= 70 { return "🟡" }
        return "🟢"
    }

    func refresh() async {
        await refreshWithRetry(retriesRemaining: 5)
    }

    private func refreshWithRetry(retriesRemaining: Int, backoffSeconds: UInt64 = 2) async {
        isLoading = true
        error = nil

        defer { isLoading = false }

        do {
            let creds = try readKeychainCredentials()
            subscriptionType = creds.subscriptionType
            var token = creds.accessToken

            // Check if token is expired
            if let expiresAt = creds.expiresAt, Date().timeIntervalSince1970 * 1000 >= Double(expiresAt) {
                if creds.refreshToken != nil {
                    token = try await refreshAccessToken(credentials: creds)
                } else {
                    throw KeychainError.invalidCredentialFormat
                }
            }

            do {
                async let usageData = fetchUsage(token: token)
                async let profileEmail = fetchProfileEmail(token: token)
                async let tStats = fetchTokenStats()
                let (data, email, ts) = try await (usageData, profileEmail, tStats)
                usage = data
                claudeUsername = email
                tokenStats = ts
                lastUpdated = Date()
            } catch UsageError.apiError(statusCode: 401) {
                // Token might be stale even if not past expiresAt - force refresh
                let creds = try readKeychainCredentials()
                if creds.refreshToken != nil {
                    token = try await refreshAccessToken(credentials: creds)
                    async let usageData = fetchUsage(token: token)
                    async let profileEmail = fetchProfileEmail(token: token)
                    async let tStats = fetchTokenStats()
                    let (data, email, ts) = try await (usageData, profileEmail, tStats)
                    usage = data
                    claudeUsername = email
                    tokenStats = ts
                    lastUpdated = Date()
                } else {
                    throw UsageError.apiError(statusCode: 401)
                }
            }
        } catch let keychainError as KeychainError {
            // Retry on keychain errors that may resolve after unlock
            if retriesRemaining > 0 && keychainError.isRetryable {
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                await refreshWithRetry(retriesRemaining: retriesRemaining - 1, backoffSeconds: backoffSeconds)
                return
            }
            self.error = keychainError.localizedDescription
        } catch let usageError as UsageError {
            // Retry on rate limit (429) with exponential backoff
            if retriesRemaining > 0 && usageError.isRetryable {
                try? await Task.sleep(nanoseconds: backoffSeconds * 1_000_000_000)
                await refreshWithRetry(retriesRemaining: retriesRemaining - 1, backoffSeconds: backoffSeconds * 2)
                return
            }
            self.error = usageError.localizedDescription
        } catch let urlError as URLError {
            // Retry on network errors (common after wake from sleep)
            if retriesRemaining > 0 && urlError.isRetryable {
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds for network
                await refreshWithRetry(retriesRemaining: retriesRemaining - 1, backoffSeconds: backoffSeconds)
                return
            }
            self.error = urlError.localizedDescription
        } catch {
            self.error = error.localizedDescription
        }
    }

    private static let oauthClientId = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
    private static let oauthTokenURL = "https://platform.claude.com/v1/oauth/token"

    func fetchTokenStats() async -> TokenStats? {
        await Task.detached(priority: .utility) {
            var dailyTotals: [String: Int] = [:]
            var activeDays: Set<String> = []

            let home = FileManager.default.homeDirectoryForCurrentUser
            let cacheURL = home.appendingPathComponent(".claude/stats-cache.json")

            let ymd = DateFormatter()
            ymd.dateFormat = "yyyy-MM-dd"
            ymd.locale = Locale(identifier: "en_US_POSIX")

            // 1. Seed from stats-cache
            var lastCachedDate: String? = nil
            if let data = try? Data(contentsOf: cacheURL),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                lastCachedDate = json["lastComputedDate"] as? String
                if let entries = json["dailyModelTokens"] as? [[String: Any]] {
                    for entry in entries {
                        guard let date = entry["date"] as? String,
                              let byModel = entry["tokensByModel"] as? [String: Any] else { continue }
                        let total = byModel.values.compactMap { $0 as? Int }.reduce(0, +)
                        dailyTotals[date, default: 0] += total
                    }
                }
                if let activity = json["dailyActivity"] as? [[String: Any]] {
                    for entry in activity {
                        if let date = entry["date"] as? String { activeDays.insert(date) }
                    }
                }
            }

            // 2. Scan session JSONL files for dates after the cache
            let projectsURL = home.appendingPathComponent(".claude/projects")
            let fm = FileManager.default
            if let enumerator = fm.enumerator(at: projectsURL,
                                               includingPropertiesForKeys: [.contentModificationDateKey],
                                               options: [.skipsHiddenFiles]) {
                let isoFull = ISO8601DateFormatter()
                isoFull.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let isoBasic = ISO8601DateFormatter()
                isoBasic.formatOptions = [.withInternetDateTime]

                for case let url as URL in enumerator {
                    guard url.pathExtension == "jsonl" else { continue }
                    if let lastCached = lastCachedDate,
                       let modDate = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate {
                        if ymd.string(from: modDate) <= lastCached { continue }
                    }
                    guard let content = try? String(contentsOf: url, encoding: .utf8) else { continue }
                    for line in content.split(separator: "\n", omittingEmptySubsequences: true) {
                        guard let data = line.data(using: .utf8),
                              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let tsStr = obj["timestamp"] as? String,
                              let ts = isoFull.date(from: tsStr) ?? isoBasic.date(from: tsStr) else { continue }
                        let day = ymd.string(from: ts)
                        activeDays.insert(day)
                        if let msg = obj["message"] as? [String: Any],
                           let usage = msg["usage"] as? [String: Any] {
                            let tokens = (usage["input_tokens"] as? Int ?? 0)
                                       + (usage["cache_creation_input_tokens"] as? Int ?? 0)
                                       + (usage["output_tokens"] as? Int ?? 0)
                            dailyTotals[day, default: 0] += tokens
                        }
                    }
                }
            }

            guard !dailyTotals.isEmpty else { return nil }

            // 3. Today + current Sun-Sat week tokens
            let todayStr = ymd.string(from: Date())
            let todayTokens = dailyTotals[todayStr] ?? 0

            var cal = Calendar(identifier: .gregorian)
            cal.firstWeekday = 1
            let weekInterval = cal.dateInterval(of: .weekOfYear, for: Date())
            let weekStart = weekInterval?.start ?? Date()
            let weekEnd = weekInterval?.end ?? Date()
            let weekTokens = dailyTotals.filter { entry in
                guard let d = ymd.date(from: entry.key) else { return false }
                return d >= weekStart && d < weekEnd
            }.values.reduce(0, +)

            // 4. Most active day
            guard let best = dailyTotals.max(by: { $0.value < $1.value }) else { return nil }
            let display = DateFormatter()
            display.dateFormat = "MMM d"
            let bestLabel = ymd.date(from: best.key).map { display.string(from: $0) } ?? best.key

            // 5. Current streak — consecutive active days ending today or yesterday
            var streak = 0
            var checkDate = Date()
            // If today has no activity yet, start counting from yesterday
            if !activeDays.contains(ymd.string(from: checkDate)) {
                checkDate = cal.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            }
            while activeDays.contains(ymd.string(from: checkDate)) {
                streak += 1
                checkDate = cal.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            }

            return TokenStats(todayTokens: todayTokens, weekTokens: weekTokens,
                              mostActiveDay: bestLabel, mostActiveDayTokens: best.value,
                              currentStreak: streak)
        }.value
    }

    private func fetchProfileEmail(token: String) async -> String? {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/profile")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("claude-code/\(Self.claudeCodeVersion)", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await urlSession.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let account = json["account"] as? [String: Any],
              let email = account["email"] as? String else { return nil }
        return email
    }

    private func getAccessToken() async throws -> String {
        let creds = try readKeychainCredentials()

        // Check if the access token is expired
        if let expiresAt = creds.expiresAt, Date().timeIntervalSince1970 * 1000 >= Double(expiresAt) {
            // Token expired - refresh it
            if creds.refreshToken != nil {
                return try await refreshAccessToken(credentials: creds)
            }
            throw KeychainError.invalidCredentialFormat
        }

        return creds.accessToken
    }

    private struct OAuthCredentials {
        let accessToken: String
        let refreshToken: String?
        let expiresAt: Int64? // milliseconds since epoch
        let service: String
        let account: String?
        let subscriptionType: String?
    }

    /// Read credentials from Claude Code's keychain using security CLI
    /// Tries multiple account names since Claude Code may store under different accounts
    private func readKeychainCredentials() throws -> OAuthCredentials {
        // Try account-specific entries first (Claude Code stores under the OS username)
        let accounts = [NSUserName(), "root", ""]
        var jsonString: String? = nil
        var foundService = "Claude Code-credentials"
        var foundAccount: String? = nil

        for account in accounts {
            let accountArg: String? = account.isEmpty ? nil : account
            if let entry = try readKeychainEntry(service: "Claude Code-credentials", account: accountArg) {
                // Validate this entry has a non-expired token or at least a refresh token
                if let data = entry.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let oauth = json["claudeAiOauth"] as? [String: Any],
                   oauth["accessToken"] != nil {
                    let expiresAt = oauth["expiresAt"] as? Int64 ?? 0
                    let isExpired = Date().timeIntervalSince1970 * 1000 >= Double(expiresAt)
                    // Prefer non-expired tokens, but accept expired if it has a refresh token
                    if !isExpired {
                        jsonString = entry
                        foundAccount = accountArg
                        break
                    } else if oauth["refreshToken"] != nil && jsonString == nil {
                        jsonString = entry
                        foundAccount = accountArg
                        // Keep looking for a non-expired one
                    }
                }
            }
        }

        // Fallback: try alternate service name
        if jsonString == nil {
            if let entry = try readKeychainEntry(service: "Claude Code", account: nil) {
                jsonString = entry
                foundService = "Claude Code"
                foundAccount = nil
            }
        }

        guard let jsonString = jsonString else {
            throw KeychainError.notLoggedIn
        }

        guard let jsonData = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let accessToken = oauth["accessToken"] as? String else {
            if let jsonData = jsonString.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                let keys = Array(json.keys).joined(separator: ", ")
                throw KeychainError.missingOAuthToken(availableKeys: keys)
            }
            throw KeychainError.invalidCredentialFormat
        }

        return OAuthCredentials(
            accessToken: accessToken,
            refreshToken: oauth["refreshToken"] as? String,
            expiresAt: oauth["expiresAt"] as? Int64,
            service: foundService,
            account: foundAccount,
            subscriptionType: oauth["subscriptionType"] as? String
        )
    }

    /// Read a single keychain entry by service name and optional account, returns nil if not found
    private func readKeychainEntry(service: String, account: String? = nil) throws -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        var args = ["find-generic-password", "-s", service]
        if let account = account {
            args += ["-a", account]
        }
        args.append("-w")
        process.arguments = args

        let pipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw KeychainError.unexpectedError(status: -1)
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let errorString = String(data: errorData, encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            if errorString.contains("could not be found") {
                return nil
            }
            throw KeychainError.securityCommandFailed(errorString.isEmpty ? "Exit code \(process.terminationStatus)" : errorString)
        }

        let result = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (result?.isEmpty == true) ? nil : result
    }

    /// Refresh the OAuth access token and update the keychain
    private func refreshAccessToken(credentials: OAuthCredentials) async throws -> String {
        guard let refreshToken = credentials.refreshToken else {
            throw KeychainError.invalidCredentialFormat
        }

        var request = URLRequest(url: URL(string: Self.oauthTokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": Self.oauthClientId
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw UsageError.apiError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let newAccessToken = json["access_token"] as? String else {
            throw UsageError.invalidResponse
        }

        // Update keychain with refreshed tokens
        let newRefreshToken = json["refresh_token"] as? String ?? refreshToken
        let expiresIn = json["expires_in"] as? Int ?? 28800
        let newExpiresAt = Int64(Date().timeIntervalSince1970 * 1000) + Int64(expiresIn) * 1000

        updateKeychainCredentials(
            accessToken: newAccessToken,
            refreshToken: newRefreshToken,
            expiresAt: newExpiresAt,
            service: credentials.service,
            account: credentials.account
        )

        return newAccessToken
    }

    /// Write updated OAuth credentials back to the same keychain entry that was originally read
    private func updateKeychainCredentials(accessToken: String, refreshToken: String, expiresAt: Int64, service: String, account: String?) {
        // Read the full current keychain JSON so we preserve other keys
        guard let currentJson = try? readKeychainEntry(service: service, account: account),
              let jsonData = currentJson.data(using: .utf8),
              var json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              var oauth = json["claudeAiOauth"] as? [String: Any] else {
            return
        }

        oauth["accessToken"] = accessToken
        oauth["refreshToken"] = refreshToken
        oauth["expiresAt"] = expiresAt
        json["claudeAiOauth"] = oauth

        guard let updatedData = try? JSONSerialization.data(withJSONObject: json),
              let updatedString = String(data: updatedData, encoding: .utf8) else {
            return
        }

        // Use -U flag for atomic update — avoids the delete-then-add race that could wipe credentials
        let addProcess = Process()
        addProcess.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        var args = ["add-generic-password", "-s", service, "-w", updatedString, "-U"]
        if let account = account {
            args += ["-a", account]
        }
        addProcess.arguments = args
        addProcess.standardOutput = FileHandle.nullDevice
        addProcess.standardError = FileHandle.nullDevice
        try? addProcess.run()
        addProcess.waitUntilExit()
    }

    private func fetchUsage(token: String) async throws -> UsageData {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("claude-code/\(Self.claudeCodeVersion)", forHTTPHeaderField: "User-Agent")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw UsageError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw UsageError.apiError(statusCode: httpResponse.statusCode)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw UsageError.invalidResponse
        }

        let fiveHour = json["five_hour"] as? [String: Any]
        let sevenDay = json["seven_day"] as? [String: Any]
        // Try new field name first, fall back to legacy
        let sonnet = json["seven_day_sonnet"] as? [String: Any] ?? json["sonnet_only"] as? [String: Any]
        let extraUsage = json["extra_usage"] as? [String: Any]

        return UsageData(
            sessionUtilization: fiveHour?["utilization"] as? Double ?? 0,
            sessionResetsAt: parseDate(fiveHour?["resets_at"] as? String),
            weeklyUtilization: sevenDay?["utilization"] as? Double ?? 0,
            weeklyResetsAt: parseDate(sevenDay?["resets_at"] as? String),
            sonnetUtilization: sonnet?["utilization"] as? Double,
            sonnetResetsAt: parseDate(sonnet?["resets_at"] as? String),
            extraUsageEnabled: extraUsage?["is_enabled"] as? Bool ?? false,
            extraUsageMonthlyLimit: extraUsage?["monthly_limit"] as? Double,
            extraUsageUsedCredits: extraUsage?["used_credits"] as? Double
        )
    }

    private func parseDate(_ string: String?) -> Date? {
        guard let string = string else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }

}

enum KeychainError: LocalizedError {
    case notLoggedIn
    case accessDenied
    case interactionNotAllowed
    case invalidData
    case invalidCredentialFormat
    case unexpectedError(status: OSStatus)
    case securityCommandFailed(String)
    case missingOAuthToken(availableKeys: String)

    var errorDescription: String? {
        switch self {
        case .notLoggedIn:
            return "Not logged in to Claude Code"
        case .accessDenied:
            return "Keychain access denied. Please allow access in System Settings."
        case .interactionNotAllowed:
            return "Keychain interaction not allowed. Try unlocking your Mac."
        case .invalidData:
            return "Could not read Keychain data"
        case .invalidCredentialFormat:
            return "Invalid credential format in keychain"
        case .unexpectedError(let status):
            return "Keychain error (code: \(status))"
        case .securityCommandFailed(let error):
            return "Keychain access failed: \(error.trimmingCharacters(in: .whitespacesAndNewlines))"
        case .missingOAuthToken(let keys):
            return "No OAuth token in keychain. Found keys: \(keys). Try 'claude' to re-login."
        }
    }

    /// Errors that may resolve after the keychain unlocks (post-sleep/lock/boot)
    var isRetryable: Bool {
        switch self {
        case .notLoggedIn, .invalidCredentialFormat, .invalidData, .interactionNotAllowed, .securityCommandFailed:
            // notLoggedIn is retryable because keychain may not be accessible immediately after boot
            return true
        case .accessDenied, .unexpectedError, .missingOAuthToken:
            return false
        }
    }
}

enum UsageError: LocalizedError {
    case invalidResponse
    case apiError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from API"
        case .apiError(let code):
            if code == 401 {
                return "Authentication expired. Run 'claude' to re-authenticate."
            }
            if code == 429 {
                return "Rate limited by API. Will retry automatically."
            }
            return "API error (code: \(code))"
        }
    }

    var isRetryable: Bool {
        switch self {
        case .apiError(let code):
            return code == 429 || code == 500 || code == 502 || code == 503
        case .invalidResponse:
            return false
        }
    }
}

extension URLError {
    /// Network errors that may resolve after wake from sleep
    var isRetryable: Bool {
        switch self.code {
        case .notConnectedToInternet,
             .networkConnectionLost,
             .dnsLookupFailed,
             .cannotFindHost,
             .cannotConnectToHost,
             .timedOut,
             .secureConnectionFailed:
            return true
        default:
            return false
        }
    }
}
