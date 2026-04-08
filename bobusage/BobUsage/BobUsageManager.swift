import Foundation

struct BobStats {
    let todayMessages: Int
    let todaySessions: Int
    let weekMessages: Int
    let weekSessions: Int
    let totalMessages: Int
    let totalSessions: Int
    let lastUpdated: Date
    let recentSessions: [SessionInfo]
}

struct SessionInfo: Identifiable {
    let id: String
    let messageCount: Int
    let firstMessage: Date
    let lastMessage: Date
}

struct LogEntry: Codable {
    let sessionId: String
    let messageId: Int
    let type: String
    let message: String
    let timestamp: String
}

@MainActor
class BobUsageManager: ObservableObject {
    @Published var stats: BobStats?
    @Published var sessions: [BobSessionInfo] = []
    @Published var error: String?
    @Published var isLoading = false
    @Published var isLoadingSessions = false
    
    private let bobTmpPath: String
    
    init() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        self.bobTmpPath = "\(homeDir)/.bob/tmp"
    }
    
    var statusEmoji: String {
        guard let stats = stats else { return "❓" }
        
        // Color code based on today's activity
        if stats.todayMessages > 100 { return "🔴" }
        if stats.todayMessages > 50 { return "🟡" }
        return "🟢"
    }
    
    func refresh() async {
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        do {
            let stats = try await loadStats()
            self.stats = stats
            print("BobUsage: Loaded stats - Today: \(stats.todayMessages) msgs, Week: \(stats.weekMessages) msgs, Total: \(stats.totalMessages) msgs")
        } catch {
            self.error = error.localizedDescription
            print("BobUsage: Error loading stats - \(error.localizedDescription)")
        }
    }
    
    func loadSessions() async {
        isLoadingSessions = true
        defer { isLoadingSessions = false }
        
        do {
            let sessions = try await loadAllSessions()
            self.sessions = sessions
            print("BobUsage: Loaded \(sessions.count) sessions")
        } catch {
            self.error = error.localizedDescription
            print("BobUsage: Error loading sessions - \(error.localizedDescription)")
        }
    }
    
    private func loadAllSessions() async throws -> [BobSessionInfo] {
        let fileManager = FileManager.default
        
        guard let projectDirs = try? fileManager.contentsOfDirectory(atPath: bobTmpPath) else {
            throw NSError(domain: "BobUsage", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot access ~/.bob/tmp"])
        }
        
        var allSessions: [BobSessionInfo] = []
        let dateFormatter = ISO8601DateFormatter()
        
        for projectDir in projectDirs {
            let chatsPath = "\(bobTmpPath)/\(projectDir)/chats"
            
            guard fileManager.fileExists(atPath: chatsPath),
                  let sessionFiles = try? fileManager.contentsOfDirectory(atPath: chatsPath) else {
                continue
            }
            
            for sessionFile in sessionFiles where sessionFile.hasSuffix(".json") {
                let sessionPath = "\(chatsPath)/\(sessionFile)"
                
                guard let data = try? Data(contentsOf: URL(fileURLWithPath: sessionPath)),
                      let session = try? JSONDecoder().decode(BobSession.self, from: data),
                      let startTime = session.startDate,
                      let lastUpdated = session.lastUpdatedDate else {
                    continue
                }
                
                let firstUserMessage = session.messages.first(where: { $0.isUser })?.content
                
                let sessionInfo = BobSessionInfo(
                    id: session.sessionId,
                    sessionId: session.sessionId,
                    projectHash: session.projectHash,
                    startTime: startTime,
                    lastUpdated: lastUpdated,
                    messageCount: session.messageCount,
                    userMessageCount: session.userMessageCount,
                    duration: session.duration ?? 0,
                    firstUserMessage: firstUserMessage
                )
                
                allSessions.append(sessionInfo)
            }
        }
        
        // Sort by last updated (most recent first)
        allSessions.sort { $0.lastUpdated > $1.lastUpdated }
        
        return allSessions
    }
    
    private func loadStats() async throws -> BobStats {
        let fileManager = FileManager.default
        
        // Get all session directories
        guard let sessionDirs = try? fileManager.contentsOfDirectory(atPath: bobTmpPath) else {
            throw NSError(domain: "BobUsage", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot access ~/.bob/tmp"])
        }
        
        var allSessions: [String: [LogEntry]] = [:]
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: today)!
        
        print("BobUsage: Today starts at: \(today)")
        print("BobUsage: Week starts at: \(weekAgo)")
        
        // Read all logs.json files
        for sessionDir in sessionDirs {
            let logsPath = "\(bobTmpPath)/\(sessionDir)/logs.json"
            
            guard fileManager.fileExists(atPath: logsPath),
                  let data = try? Data(contentsOf: URL(fileURLWithPath: logsPath)),
                  let logs = try? JSONDecoder().decode([LogEntry].self, from: data) else {
                continue
            }
            
            if !logs.isEmpty {
                allSessions[sessionDir] = logs
            }
        }
        
        // Calculate statistics
        var todayMessages = 0
        var todaySessions = Set<String>()
        var weekMessages = 0
        var weekSessions = Set<String>()
        var totalMessages = 0
        var recentSessionsInfo: [SessionInfo] = []
        
        let dateFormatter = ISO8601DateFormatter()
        
        for (sessionId, logs) in allSessions {
            totalMessages += logs.count
            
            // Parse timestamps and count messages by date
            var sessionTodayCount = 0
            var sessionWeekCount = 0
            var firstTimestamp: Date?
            var lastTimestamp: Date?
            
            for log in logs {
                guard let timestamp = dateFormatter.date(from: log.timestamp) else { continue }
                
                if firstTimestamp == nil { firstTimestamp = timestamp }
                lastTimestamp = timestamp
                
                // Count today's messages (use calendar.isDateInToday for proper timezone handling)
                if calendar.isDateInToday(timestamp) {
                    sessionTodayCount += 1
                }
                
                // Count week's messages
                if timestamp >= weekAgo {
                    sessionWeekCount += 1
                }
            }
            
            // Update totals
            if sessionTodayCount > 0 {
                todayMessages += sessionTodayCount
                todaySessions.insert(sessionId)
                print("BobUsage: Session \(String(sessionId.prefix(8)))... has \(sessionTodayCount) messages today")
            }
            
            if sessionWeekCount > 0 {
                weekMessages += sessionWeekCount
                weekSessions.insert(sessionId)
            }
            
            guard let first = firstTimestamp, let last = lastTimestamp else { continue }
            
            // Build session info
            recentSessionsInfo.append(SessionInfo(
                id: sessionId,
                messageCount: logs.count,
                firstMessage: first,
                lastMessage: last
            ))
        }
        
        // Sort sessions by last message (most recent first)
        recentSessionsInfo.sort { $0.lastMessage > $1.lastMessage }
        
        return BobStats(
            todayMessages: todayMessages,
            todaySessions: todaySessions.count,
            weekMessages: weekMessages,
            weekSessions: weekSessions.count,
            totalMessages: totalMessages,
            totalSessions: allSessions.count,
            lastUpdated: now,
            recentSessions: Array(recentSessionsInfo.prefix(10))
        )
    }
}