import Foundation
import Security

struct UsageData {
    let sessionUtilization: Double
    let sessionResetsAt: Date?
    let weeklyUtilization: Double
    let weeklyResetsAt: Date?
    let sonnetUtilization: Double?
    let sonnetResetsAt: Date?

    var sessionPercentage: Int { Int(sessionUtilization) }
    var weeklyPercentage: Int { Int(weeklyUtilization) }
    var sonnetPercentage: Int? { sonnetUtilization.map { Int($0) } }
}

@MainActor
class UsageManager: ObservableObject {
    @Published var usage: UsageData?
    @Published var error: String?
    @Published var isLoading = false
    @Published var lastUpdated: Date?
    @Published var updateAvailable: String?

    static let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    static let githubRepo = "richhickson/claudecodeusage"

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
        await refreshWithRetry(retriesRemaining: 3)
    }

    private func refreshWithRetry(retriesRemaining: Int) async {
        isLoading = true
        error = nil

        defer { isLoading = false }

        do {
            var token = try await getAccessToken()
            do {
                let data = try await fetchUsage(token: token)
                usage = data
                lastUpdated = Date()
            } catch UsageError.apiError(statusCode: 401) {
                // Token might be stale even if not past expiresAt - force refresh
                let creds = try readKeychainCredentials()
                if creds.refreshToken != nil {
                    token = try await refreshAccessToken(credentials: creds)
                    let data = try await fetchUsage(token: token)
                    usage = data
                    lastUpdated = Date()
                } else {
                    throw UsageError.apiError(statusCode: 401)
                }
            }
        } catch let keychainError as KeychainError {
            // Retry on keychain errors that may resolve after unlock
            if retriesRemaining > 0 && keychainError.isRetryable {
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                await refreshWithRetry(retriesRemaining: retriesRemaining - 1)
                return
            }
            self.error = keychainError.localizedDescription
        } catch let urlError as URLError {
            // Retry on network errors (common after wake from sleep)
            if retriesRemaining > 0 && urlError.isRetryable {
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds for network
                await refreshWithRetry(retriesRemaining: retriesRemaining - 1)
                return
            }
            self.error = urlError.localizedDescription
        } catch {
            self.error = error.localizedDescription
        }
    }

    private static let oauthClientId = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
    private static let oauthTokenURL = "https://platform.claude.com/v1/oauth/token"

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
            account: foundAccount
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
        request.setValue("ClaudeUsage/\(Self.currentVersion)", forHTTPHeaderField: "User-Agent")
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
        let sonnetOnly = json["sonnet_only"] as? [String: Any]

        return UsageData(
            sessionUtilization: fiveHour?["utilization"] as? Double ?? 0,
            sessionResetsAt: parseDate(fiveHour?["resets_at"] as? String),
            weeklyUtilization: sevenDay?["utilization"] as? Double ?? 0,
            weeklyResetsAt: parseDate(sevenDay?["resets_at"] as? String),
            sonnetUtilization: sonnetOnly?["utilization"] as? Double,
            sonnetResetsAt: parseDate(sonnetOnly?["resets_at"] as? String)
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

    func checkForUpdates() async {
        guard let url = URL(string: "https://api.github.com/repos/\(Self.githubRepo)/releases/latest") else { return }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("ClaudeUsage/\(Self.currentVersion)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, _) = try await urlSession.data(for: request)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let tagName = json["tag_name"] as? String {
                let latestVersion = tagName.trimmingCharacters(in: CharacterSet(charactersIn: "v"))
                if isNewerVersion(latestVersion, than: Self.currentVersion) {
                    updateAvailable = latestVersion
                }
            }
        } catch {
            // Silently fail - update check is not critical
        }
    }

    private func isNewerVersion(_ latest: String, than current: String) -> Bool {
        let latestParts = latest.split(separator: ".").compactMap { Int($0) }
        let currentParts = current.split(separator: ".").compactMap { Int($0) }

        for i in 0..<max(latestParts.count, currentParts.count) {
            let l = i < latestParts.count ? latestParts[i] : 0
            let c = i < currentParts.count ? currentParts[i] : 0
            if l > c { return true }
            if l < c { return false }
        }
        return false
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
            return "API error (code: \(code))"
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
