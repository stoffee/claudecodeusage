import Foundation

// MARK: - Session Models

struct BobSession: Codable, Identifiable {
    let sessionId: String
    let projectHash: String
    let startTime: String
    let lastUpdated: String
    let messages: [BobMessage]
    
    var id: String { sessionId }
    
    var startDate: Date? {
        ISO8601DateFormatter().date(from: startTime)
    }
    
    var lastUpdatedDate: Date? {
        ISO8601DateFormatter().date(from: lastUpdated)
    }
    
    var duration: TimeInterval? {
        guard let start = startDate, let end = lastUpdatedDate else { return nil }
        return end.timeIntervalSince(start)
    }
    
    var messageCount: Int {
        messages.count
    }
    
    var userMessageCount: Int {
        messages.filter { $0.type == "user" }.count
    }
    
    var bobMessageCount: Int {
        messages.filter { $0.type == "bob-shell" }.count
    }
}

struct BobMessage: Codable, Identifiable {
    let id: String
    let timestamp: String
    let type: String
    let content: String
    let thoughts: [BobThought]?
    
    var date: Date? {
        ISO8601DateFormatter().date(from: timestamp)
    }
    
    var isUser: Bool {
        type == "user"
    }
    
    var isBob: Bool {
        type == "bob-shell"
    }
}

struct BobThought: Codable {
    let subject: String
    let description: String
    let timestamp: String
    
    var date: Date? {
        ISO8601DateFormatter().date(from: timestamp)
    }
}

// MARK: - Session Info for List Display

struct BobSessionInfo: Identifiable {
    let id: String
    let sessionId: String
    let projectHash: String
    let startTime: Date
    let lastUpdated: Date
    let messageCount: Int
    let userMessageCount: Int
    let duration: TimeInterval
    let firstUserMessage: String?
    
    var projectName: String {
        // Extract first 8 chars of project hash for display
        String(projectHash.prefix(8))
    }
    
    var durationFormatted: String {
        let hours = Int(duration / 3600)
        let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
    
    var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastUpdated, relativeTo: Date())
    }
}
