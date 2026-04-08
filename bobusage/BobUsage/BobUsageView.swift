import SwiftUI

enum BobTab: String, CaseIterable {
    case usage = "Usage"
    case sessions = "Sessions"
}

struct BobUsageView: View {
    @ObservedObject var manager: BobUsageManager
    @State private var selectedTab: BobTab = .usage
    @State private var selectedSession: BobSessionInfo?
    @State private var sessionSearchText: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.accentColor)
                Text("Bob-Shell Usage")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if manager.isLoading || manager.isLoadingSessions {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            // Tab picker
            Picker("", selection: $selectedTab) {
                ForEach(BobTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            Divider()
            
            // Tab content
            switch selectedTab {
            case .usage:
                usageTabContent()
            case .sessions:
                sessionsTabContent()
            }
            
            Divider()
            
            // Footer
            footerView()
        }
        .frame(width: 340, height: 500)
        .onAppear {
            Task {
                await manager.loadSessions()
            }
        }
    }
    
    // MARK: - Usage Tab
    
    @ViewBuilder
    func usageTabContent() -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if manager.isLoading {
                    loadingView()
                } else if let error = manager.error {
                    errorView(error)
                } else if let stats = manager.stats {
                    statsContent(stats)
                } else {
                    Text("No data available")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                }
            }
            .padding()
        }
    }
    
    // MARK: - Sessions Tab
    
    @ViewBuilder
    func sessionsTabContent() -> some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search sessions...", text: $sessionSearchText)
                    .textFieldStyle(.plain)
                if !sessionSearchText.isEmpty {
                    Button(action: { sessionSearchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .padding()
            
            Divider()
            
            // Session list
            if manager.isLoadingSessions {
                ProgressView()
                    .padding()
            } else if filteredSessions.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text(sessionSearchText.isEmpty ? "No sessions found" : "No matching sessions")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredSessions) { session in
                            SessionListRow(session: session, isSelected: selectedSession?.id == session.id)
                                .onTapGesture {
                                    selectedSession = session
                                }
                        }
                    }
                    .padding()
                }
            }
        }
        .sheet(item: $selectedSession) { session in
            SessionDetailView(session: session)
        }
    }
    
    var filteredSessions: [BobSessionInfo] {
        if sessionSearchText.isEmpty {
            return manager.sessions
        }
        return manager.sessions.filter { session in
            session.firstUserMessage?.localizedCaseInsensitiveContains(sessionSearchText) ?? false ||
            session.projectName.localizedCaseInsensitiveContains(sessionSearchText)
        }
    }
    
    // MARK: - Loading View
    
    func loadingView() -> some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading usage data...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding()
    }
    
    // MARK: - Error View
    
    func errorView(_ error: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Error")
                    .font(.headline)
            }
            
            Text(error)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - Stats Content
    
    func statsContent(_ stats: BobStats) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Today's Activity
            StatSection(title: "Today") {
                StatRow(
                    label: "Messages",
                    value: "\(stats.todayMessages)",
                    color: colorForMessages(stats.todayMessages)
                )
                StatRow(
                    label: "Sessions",
                    value: "\(stats.todaySessions)",
                    color: .blue
                )
            }
            
            // This Week
            StatSection(title: "This Week") {
                StatRow(
                    label: "Messages",
                    value: "\(stats.weekMessages)",
                    color: .purple
                )
                StatRow(
                    label: "Sessions",
                    value: "\(stats.weekSessions)",
                    color: .blue
                )
            }
            
            // All Time
            StatSection(title: "All Time") {
                StatRow(
                    label: "Total Messages",
                    value: "\(stats.totalMessages)",
                    color: .gray
                )
                StatRow(
                    label: "Total Sessions",
                    value: "\(stats.totalSessions)",
                    color: .gray
                )
            }
            
            // Recent Sessions
            if !stats.recentSessions.isEmpty {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Sessions")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    ForEach(stats.recentSessions.prefix(5)) { session in
                        SessionRow(session: session)
                    }
                }
            }
            
            // Last Updated
            Divider()
            
            HStack {
                Text("Last updated:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(formatDate(stats.lastUpdated))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Footer
    
    func footerView() -> some View {
        HStack {
            if let stats = manager.stats {
                Text("Updated \(stats.lastUpdated.formatted(.relative(presentation: .named)))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: {
                Task { await manager.refresh() }
            }) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .disabled(manager.isLoading)
            .help("Refresh")
            
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Image(systemName: "xmark.circle")
            }
            .buttonStyle(.borderless)
            .help("Quit")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    // MARK: - Helper Functions
    
    func colorForMessages(_ count: Int) -> Color {
        if count > 100 { return .red }
        if count > 50 { return .orange }
        return .green
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Session List Row

struct SessionListRow: View {
    let session: BobSessionInfo
    let isSelected: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    if let firstMessage = session.firstUserMessage {
                        Text(firstMessage)
                            .font(.subheadline)
                            .lineLimit(2)
                            .foregroundColor(.primary)
                    } else {
                        Text("Session \(session.projectName)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 8) {
                        Label("\(session.messageCount)", systemImage: "message")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Label(session.durationFormatted, systemImage: "clock")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("Project: \(session.projectName)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(session.relativeTime)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(10)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Session Detail View

struct SessionDetailView: View {
    let session: BobSessionInfo
    @Environment(\.dismiss) var dismiss
    @State private var fullSession: BobSession?
    @State private var isLoading = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Session Details")
                        .font(.headline)
                    Text("Project: \(session.projectName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Content
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let fullSession = fullSession {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(fullSession.messages) { message in
                            MessageBubble(message: message)
                        }
                    }
                    .padding()
                }
            } else {
                Text("Failed to load session")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 600, height: 700)
        .onAppear {
            loadFullSession()
        }
    }
    
    private func loadFullSession() {
        Task {
            do {
                let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
                let sessionPath = "\(homeDir)/.bob/tmp/\(session.projectHash)/chats"
                
                guard let files = try? FileManager.default.contentsOfDirectory(atPath: sessionPath) else {
                    isLoading = false
                    return
                }
                
                for file in files where file.contains(session.sessionId) {
                    let fullPath = "\(sessionPath)/\(file)"
                    if let data = try? Data(contentsOf: URL(fileURLWithPath: fullPath)),
                       let decoded = try? JSONDecoder().decode(BobSession.self, from: data) {
                        fullSession = decoded
                        break
                    }
                }
            }
            isLoading = false
        }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: BobMessage
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: message.isUser ? "person.circle.fill" : "cpu")
                .foregroundColor(message.isUser ? .blue : .green)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(message.isUser ? "You" : "Bob-Shell")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(message.isUser ? .blue : .green)
                    
                    if let date = message.date {
                        Text(date.formatted(date: .omitted, time: .shortened))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Text(message.content)
                    .font(.body)
                    .textSelection(.enabled)
                    .padding(8)
                    .background(message.isUser ? Color.blue.opacity(0.1) : Color.green.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Stat Section

struct StatSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            content
        }
    }
}

// MARK: - Stat Row

struct StatRow: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(label)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.semibold)
        }
    }
}

// MARK: - Session Row

struct SessionRow: View {
    let session: SessionInfo
    
    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(session.messageCount) messages")
                    .font(.caption)
                    .foregroundColor(.primary)
                
                Text(formatRelativeTime(session.lastMessage))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(String(session.id.prefix(8)))
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)
        }
        .padding(.vertical, 4)
    }
    
    func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Preview

struct BobUsageView_Previews: PreviewProvider {
    static var previews: some View {
        BobUsageView(manager: BobUsageManager())
    }
}
