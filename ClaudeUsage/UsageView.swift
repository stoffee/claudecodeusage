import SwiftUI
import AppKit
import ServiceManagement

enum AppTab: String, CaseIterable {
    case usage = "Usage"
    case sessions = "Sessions"
}

// MARK: - Theme

enum AppTheme: String, CaseIterable {
    case standard = "Default"
    case system = "System"
    case stoffee = "Stoffee"

    var headerBackground: Color {
        switch self {
        case .standard: return Color(NSColor.controlBackgroundColor)
        case .system: return Color(NSColor.controlBackgroundColor)
        case .stoffee: return Color(red: 0.15, green: 0.05, blue: 0.2)
        }
    }

    var cardBackground: Color {
        switch self {
        case .standard: return Color(NSColor.controlBackgroundColor)
        case .system: return Color(NSColor.controlBackgroundColor)
        case .stoffee: return Color(red: 0.2, green: 0.08, blue: 0.28)
        }
    }

    var popoverBackground: Color {
        switch self {
        case .standard: return Color(NSColor.windowBackgroundColor)
        case .system: return Color(NSColor.windowBackgroundColor)
        case .stoffee: return Color(red: 0.12, green: 0.03, blue: 0.18)
        }
    }

    var primaryText: Color {
        switch self {
        case .standard, .system: return Color.primary
        case .stoffee: return Color(red: 1.0, green: 0.85, blue: 1.0)
        }
    }

    var secondaryText: Color {
        switch self {
        case .standard, .system: return Color.secondary
        case .stoffee: return Color(red: 0.75, green: 0.55, blue: 0.85)
        }
    }

    var accent: Color {
        switch self {
        case .standard: return .accentColor
        case .system: return .accentColor
        case .stoffee: return Color(red: 1.0, green: 0.2, blue: 0.6) // hot pink
        }
    }

    var barTrack: Color {
        switch self {
        case .standard, .system: return Color(NSColor.separatorColor)
        case .stoffee: return Color(red: 0.3, green: 0.12, blue: 0.4)
        }
    }

    var searchBackground: Color {
        switch self {
        case .standard, .system: return Color(NSColor.textBackgroundColor)
        case .stoffee: return Color(red: 0.22, green: 0.1, blue: 0.3)
        }
    }

    func colorForPercentage(_ pct: Int) -> Color {
        switch self {
        case .standard, .system:
            if pct >= 90 { return .red }
            if pct >= 70 { return .orange }
            return .green
        case .stoffee:
            if pct >= 90 { return Color(red: 1.0, green: 0.1, blue: 0.3) }   // neon red-pink
            if pct >= 70 { return Color(red: 1.0, green: 0.4, blue: 0.9) }   // neon magenta
            return Color(red: 0.6, green: 0.2, blue: 1.0)                     // electric purple
        }
    }

    func overageColor(_ pct: Int) -> Color {
        switch self {
        case .standard, .system:
            if pct >= 90 { return .red }
            if pct >= 70 { return .orange }
            return .blue
        case .stoffee:
            if pct >= 90 { return Color(red: 1.0, green: 0.1, blue: 0.3) }
            if pct >= 70 { return Color(red: 1.0, green: 0.4, blue: 0.9) }
            return Color(red: 0.0, green: 0.8, blue: 1.0) // cyan neon
        }
    }

    var themeIcon: String {
        switch self {
        case .standard: return "paintbrush"
        case .system: return "gearshape"
        case .stoffee: return "sparkles"
        }
    }
}

struct UsageView: View {
    @ObservedObject var manager: UsageManager
    @ObservedObject var sessionManager: SessionManager
    @Environment(\.openURL) var openURL
    @State private var selectedTab: AppTab = .usage
    @State private var sessionSearchText: String = ""
    @AppStorage("appTheme") private var selectedTheme: String = AppTheme.standard.rawValue
    private var theme: AppTheme { AppTheme(rawValue: selectedTheme) ?? .standard }
    @State private var launchAtLogin: Bool = {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(theme.accent)
                Text("Claude Usage")
                    .font(.headline)
                    .foregroundColor(theme.primaryText)
                Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")")
                    .font(.caption2)
                    .foregroundColor(theme.secondaryText)
                Spacer()

                if manager.isLoading || sessionManager.isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding()
            .background(theme.headerBackground)

            // Tab picker
            Picker("", selection: $selectedTab) {
                ForEach(AppTab.allCases, id: \.self) { tab in
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
        .frame(width: 340)
        .background(theme.popoverBackground)
    }

    // MARK: - Usage Tab

    @ViewBuilder
    func usageTabContent() -> some View {
        if let error = manager.error {
            errorView(error)
        } else if let usage = manager.usage {
            usageContent(usage)
        } else {
            loadingView()
        }
    }

    @ViewBuilder
    func usageContent(_ usage: UsageData) -> some View {
        VStack(spacing: 16) {
            UsageRow(
                title: "Session",
                subtitle: "5-hour window",
                percentage: usage.sessionPercentage,
                resetsAt: usage.sessionResetsAt,
                color: theme.colorForPercentage(usage.sessionPercentage),
                theme: theme
            )

            UsageRow(
                title: "Weekly",
                subtitle: "7-day window",
                percentage: usage.weeklyPercentage,
                resetsAt: usage.weeklyResetsAt,
                color: theme.colorForPercentage(usage.weeklyPercentage),
                theme: theme
            )

            if let sonnetPct = usage.sonnetPercentage {
                UsageRow(
                    title: "Sonnet Only",
                    subtitle: "Model-specific",
                    percentage: sonnetPct,
                    resetsAt: usage.sonnetResetsAt,
                    color: theme.colorForPercentage(sonnetPct),
                    theme: theme
                )
            }

            // Extra usage / overage (if enabled)
            if usage.extraUsageEnabled, let limit = usage.extraUsageMonthlyLimit, let used = usage.extraUsageUsedCredits {
                OverageRow(
                    usedDollars: used / 100,
                    limitDollars: limit / 100,
                    percentage: usage.extraUsagePercentage ?? 0,
                    theme: theme
                )
            }
        }
        .padding()
    }

    // MARK: - Sessions Tab

    var filteredSessions: [SessionEntry] {
        guard !sessionSearchText.isEmpty else { return sessionManager.sessions }
        let query = sessionSearchText.lowercased()
        return sessionManager.sessions.filter { session in
            session.displayTitle.lowercased().contains(query) ||
            session.shortProjectName.lowercased().contains(query) ||
            (session.branchDisplay?.lowercased().contains(query) ?? false)
        }
    }

    @ViewBuilder
    func sessionsTabContent() -> some View {
        VStack(spacing: 0) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(theme.secondaryText)
                TextField("Search sessions...", text: $sessionSearchText)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
                    .foregroundColor(theme.primaryText)
                if !sessionSearchText.isEmpty {
                    Button(action: { sessionSearchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(theme.secondaryText)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(theme.searchBackground)
            .cornerRadius(8)
            .padding(.horizontal)
            .padding(.vertical, 6)

            if filteredSessions.isEmpty && !sessionManager.isLoading {
                VStack(spacing: 12) {
                    Image(systemName: sessionSearchText.isEmpty ? "tray" : "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundColor(theme.secondaryText)
                    Text(sessionSearchText.isEmpty ? "No sessions found" : "No matching sessions")
                        .font(.subheadline)
                        .foregroundColor(theme.secondaryText)
                }
                .padding()
                .frame(maxWidth: .infinity, minHeight: 180)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredSessions) { session in
                            SessionRow(session: session, theme: theme, onTap: {
                                sessionManager.resumeSession(session)
                            }, onDelete: {
                                sessionManager.deleteSession(session)
                            })
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .frame(minHeight: 180, maxHeight: 300)
            }
        }
    }

    // MARK: - Error / Loading

    @ViewBuilder
    func errorView(_ error: String) -> some View {
        VStack(spacing: 12) {
            if error.contains("Not logged in") {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.largeTitle)
                    .foregroundColor(.blue)

                Text("Not Signed In")
                    .font(.headline)

                Text("This app uses credentials from Claude Code stored in the macOS Keychain.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Text("Please run `claude` in Terminal and log in first.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Button("Open Terminal & Run Claude") {
                    launchClaudeCLI()
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)

                Button("Install Claude Code") {
                    openURL(URL(string: "https://docs.anthropic.com/en/docs/claude-code/overview")!)
                }
                .buttonStyle(.borderless)
                .font(.caption)
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.orange)

                Text(error)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    func loadingView() -> some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading usage data...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }

    // MARK: - Footer

    @ViewBuilder
    func footerView() -> some View {
        VStack(spacing: 8) {
            if #available(macOS 14.0, *) {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .toggleStyle(.checkbox)
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
                    .onChange(of: launchAtLogin) { _, newValue in setLaunchAtLogin(newValue) }
                    .padding(.horizontal)
            } else {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .toggleStyle(.checkbox)
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
                    .onChange(of: launchAtLogin) { newValue in setLaunchAtLogin(newValue) }
                    .padding(.horizontal)
            }

            Divider()

            HStack {
                if let lastUpdated = manager.lastUpdated {
                    Text("Updated \(lastUpdated.formatted(.relative(presentation: .named)))")
                        .font(.caption)
                        .foregroundColor(theme.secondaryText)
                }

                Spacer()

                Button(action: {
                    sessionManager.loadSessions()
                    Task { await manager.refresh() }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(theme.secondaryText)
                }
                .buttonStyle(.borderless)
                .disabled(manager.isLoading && sessionManager.isLoading)

                Button(action: {
                    openURL(URL(string: "https://claude.ai")!)
                }) {
                    Image(systemName: "globe")
                        .foregroundColor(theme.secondaryText)
                }
                .buttonStyle(.borderless)

                // Theme picker
                Menu {
                    ForEach(AppTheme.allCases, id: \.self) { t in
                        Button(action: { selectedTheme = t.rawValue }) {
                            HStack {
                                Image(systemName: t.themeIcon)
                                Text(t.rawValue)
                                if t.rawValue == selectedTheme {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: theme.themeIcon)
                        .foregroundColor(theme == .stoffee ? theme.accent : theme.secondaryText)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 20)

                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Image(systemName: "xmark.circle")
                        .foregroundColor(theme.secondaryText)
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal)

            Divider()

            HStack {
                if let username = manager.claudeUsername {
                    Text("User: \(username)")
                        .font(.caption)
                        .foregroundColor(theme.secondaryText)
                } else if let subscriptionType = manager.subscriptionType {
                    Text("Plan: \(subscriptionType.capitalized)")
                        .font(.caption)
                        .foregroundColor(theme.secondaryText)
                }
                
                Spacer()
                
                Button(action: {
                    openURL(URL(string: "https://x.com/richhickson")!)
                }) {
                    Text("Created by @richhickson")
                        .font(.caption)
                        .foregroundColor(theme.secondaryText)
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .background(theme.headerBackground)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLogin = !enabled
        }
    }

    // MARK: - Helpers

    func launchClaudeCLI() {
        let script = """
        tell application "Terminal"
            activate
            do script "claude"
        end tell
        """
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }
}

// MARK: - Session Row

struct SessionRow: View {
    let session: SessionEntry
    var theme: AppTheme = .standard
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Delete button
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help("Delete session")

            // Session card (clickable)
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.displayTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(2)
                        .foregroundColor(theme.primaryText)

                    HStack(spacing: 8) {
                        Label(session.shortProjectName, systemImage: "folder")
                            .font(.caption)
                            .foregroundColor(theme.secondaryText)
                            .lineLimit(1)

                        if let branch = session.branchDisplay {
                            Label(branch, systemImage: "arrow.triangle.branch")
                                .font(.caption)
                                .foregroundColor(theme.secondaryText)
                                .lineLimit(1)
                        }

                        Spacer()

                        if session.messageCount > 0 {
                            Label("\(session.messageCount)", systemImage: "message")
                                .font(.caption)
                                .foregroundColor(theme.secondaryText)
                        }
                    }

                    if !session.relativeModified.isEmpty {
                        Text(session.relativeModified)
                            .font(.caption2)
                            .foregroundColor(theme.secondaryText.opacity(0.7))
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .background(theme.cardBackground)
        .cornerRadius(8)
    }
}

// MARK: - Usage Row

struct UsageRow: View {
    let title: String
    let subtitle: String
    let percentage: Int
    let resetsAt: Date?
    let color: Color
    var theme: AppTheme = .standard

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(theme.primaryText)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(theme.secondaryText)
                }

                Spacer()

                Text("\(percentage)%")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(theme.barTrack)
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(percentage) / 100, height: 8)
                }
            }
            .frame(height: 8)

            // Reset time
            if let resetsAt = resetsAt {
                HStack {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text("Resets \(formatTimeRemaining(resetsAt))")
                        .font(.caption)
                }
                .foregroundColor(theme.secondaryText)
            }
        }
        .padding(12)
        .background(theme.cardBackground)
        .cornerRadius(8)
    }

    func formatTimeRemaining(_ date: Date) -> String {
        let now = Date()
        let diff = date.timeIntervalSince(now)

        if diff <= 0 { return "soon" }

        let hours = Int(diff / 3600)
        let minutes = Int((diff.truncatingRemainder(dividingBy: 3600)) / 60)

        if hours > 24 {
            let days = hours / 24
            let remainingHours = hours % 24
            return "in \(days)d \(remainingHours)h"
        }

        return "in \(hours)h \(minutes)m"
    }
}

struct OverageRow: View {
    let usedDollars: Double
    let limitDollars: Double
    let percentage: Int
    var theme: AppTheme = .standard

    var color: Color { theme.overageColor(percentage) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Overage")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(theme.primaryText)
                    Text("Extra usage this month")
                        .font(.caption)
                        .foregroundColor(theme.secondaryText)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("$\(String(format: "%.2f", usedDollars))")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(color)
                    Text("of $\(String(format: "%.0f", limitDollars)) limit")
                        .font(.caption)
                        .foregroundColor(theme.secondaryText)
                }
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(theme.barTrack)
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(min(percentage, 100)) / 100, height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding(12)
        .background(theme.cardBackground)
        .cornerRadius(8)
    }
}

#Preview {
    UsageView(manager: UsageManager(), sessionManager: SessionManager())
}
