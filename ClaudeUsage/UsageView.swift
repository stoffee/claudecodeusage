import SwiftUI
import AppKit
import ServiceManagement

enum AppTab: String, CaseIterable {
    case usage = "Usage"
    case sessions = "Sessions"
}

// MARK: - Gauge Style

enum GaugeStyle: String, CaseIterable, Identifiable {
    case linear
    case segmented
    case liquid
    case ascii

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .linear:    return "Linear"
        case .segmented: return "Segmented"
        case .liquid:    return "Liquid Fill"
        case .ascii:     return "ASCII"
        }
    }
}

// MARK: - Icon Pack

enum IconPack: String, CaseIterable, Identifiable {
    case classic    // 🟢 🟡 🔴
    case stoffee    // 🚀 🪫 💀
    case terminal   // [OK] [!] [X]
    case retro      // ♥ ⚠ ☠

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .classic:  return "Classic"
        case .stoffee:  return "Stoffee"
        case .terminal: return "Terminal"
        case .retro:    return "Retro"
        }
    }

    func statusEmoji(for maxUtil: Double) -> String {
        switch self {
        case .classic:
            if maxUtil >= 90 { return "🔴" }
            if maxUtil >= 70 { return "🟡" }
            return "🟢"
        case .stoffee:
            if maxUtil >= 90 { return "💀" }
            if maxUtil >= 70 { return "🪫" }
            return "🚀"
        case .terminal:
            if maxUtil >= 90 { return "[X]" }
            if maxUtil >= 70 { return "[!]" }
            return "[OK]"
        case .retro:
            if maxUtil >= 90 { return "☠" }
            if maxUtil >= 70 { return "⚠" }
            return "♥"
        }
    }
}

// MARK: - Theme

enum AppTheme: String, CaseIterable {
    case standard = "Default"
    case stoffee = "Stoffee"
    case terminal = "Terminal"
    case retro = "Retro"

    var headerBackground: Color {
        switch self {
        case .standard: return Color(NSColor.controlBackgroundColor)
        case .stoffee: return Color(red: 0.15, green: 0.05, blue: 0.2)
        case .terminal: return Color(red: 0.0, green: 0.0, blue: 0.0)
        case .retro:    return Color(red: 0.1, green: 0.1, blue: 0.18)
        }
    }

    var cardBackground: Color {
        switch self {
        case .standard: return Color(NSColor.controlBackgroundColor)
        case .stoffee: return Color(red: 0.2, green: 0.08, blue: 0.28)
        case .terminal: return Color(red: 0.04, green: 0.04, blue: 0.04)
        case .retro:    return Color(red: 0.13, green: 0.13, blue: 0.22)
        }
    }

    var popoverBackground: Color {
        switch self {
        case .standard: return Color(NSColor.windowBackgroundColor)
        case .stoffee: return Color(red: 0.12, green: 0.03, blue: 0.18)
        case .terminal: return Color(red: 0.0, green: 0.0, blue: 0.0)
        case .retro:    return Color(red: 0.08, green: 0.08, blue: 0.16)
        }
    }

    var primaryText: Color {
        switch self {
        case .standard: return Color.primary
        case .stoffee: return Color(red: 1.0, green: 0.85, blue: 1.0)
        case .terminal: return Color(red: 0.0, green: 1.0, blue: 0.0)
        case .retro:    return Color.white
        }
    }

    var secondaryText: Color {
        switch self {
        case .standard: return Color.secondary
        case .stoffee: return Color(red: 0.75, green: 0.55, blue: 0.85)
        case .terminal: return Color(red: 0.0, green: 0.7, blue: 0.0)
        case .retro:    return Color(red: 0.6, green: 0.6, blue: 0.85)
        }
    }

    var accent: Color {
        switch self {
        case .standard: return .accentColor
        case .stoffee: return Color(red: 1.0, green: 0.2, blue: 0.6) // hot pink
        case .terminal: return Color(red: 0.0, green: 1.0, blue: 0.0)
        case .retro:    return Color(red: 1.0, green: 0.8, blue: 0.0)
        }
    }

    var barTrack: Color {
        switch self {
        case .standard: return Color(NSColor.separatorColor)
        case .stoffee: return Color(red: 0.3, green: 0.12, blue: 0.4)
        case .terminal: return Color(red: 0.1, green: 0.2, blue: 0.1)
        case .retro:    return Color(red: 0.2, green: 0.2, blue: 0.3)
        }
    }

    var searchBackground: Color {
        switch self {
        case .standard: return Color(NSColor.textBackgroundColor)
        case .stoffee: return Color(red: 0.22, green: 0.1, blue: 0.3)
        case .terminal: return Color(red: 0.05, green: 0.1, blue: 0.05)
        case .retro:    return Color(red: 0.15, green: 0.15, blue: 0.25)
        }
    }

    func colorForPercentage(_ pct: Int) -> Color {
        switch self {
        case .standard:
            if pct >= 90 { return .red }
            if pct >= 70 { return .orange }
            return .green
        case .stoffee:
            if pct >= 90 { return Color(red: 1.0, green: 0.1, blue: 0.3) }   // neon red-pink
            if pct >= 70 { return Color(red: 1.0, green: 0.4, blue: 0.9) }   // neon magenta
            return Color(red: 0.6, green: 0.2, blue: 1.0)                     // electric purple
        case .terminal:
            if pct >= 90 { return Color(red: 1.0, green: 0.2, blue: 0.0) }
            if pct >= 70 { return Color(red: 1.0, green: 1.0, blue: 0.0) }
            return Color(red: 0.0, green: 1.0, blue: 0.0)
        case .retro:
            if pct >= 90 { return Color(red: 1.0, green: 0.0, blue: 0.27) }
            if pct >= 70 { return Color(red: 1.0, green: 0.8, blue: 0.0) }
            return Color(red: 0.35, green: 0.8, blue: 0.4)
        }
    }

    func overageColor(_ pct: Int) -> Color {
        switch self {
        case .standard:
            if pct >= 90 { return .red }
            if pct >= 70 { return .orange }
            return .blue
        case .stoffee:
            if pct >= 90 { return Color(red: 1.0, green: 0.1, blue: 0.3) }
            if pct >= 70 { return Color(red: 1.0, green: 0.4, blue: 0.9) }
            return Color(red: 0.0, green: 0.8, blue: 1.0) // cyan neon
        case .terminal:
            if pct >= 90 { return Color(red: 1.0, green: 0.2, blue: 0.0) }
            if pct >= 70 { return Color(red: 1.0, green: 1.0, blue: 0.0) }
            return Color(red: 0.0, green: 0.9, blue: 0.9)
        case .retro:
            if pct >= 90 { return Color(red: 1.0, green: 0.0, blue: 0.27) }
            if pct >= 70 { return Color(red: 1.0, green: 0.8, blue: 0.0) }
            return Color(red: 0.4, green: 0.7, blue: 1.0)
        }
    }

    func statusEmoji(for maxUtil: Double) -> String {
        switch self {
        case .standard:
            if maxUtil >= 90 { return "🔴" }
            if maxUtil >= 70 { return "🟡" }
            return "🟢"
        case .stoffee:
            if maxUtil >= 90 { return "💀" }
            if maxUtil >= 70 { return "🪫" }
            return "🚀"
        case .terminal:
            if maxUtil >= 90 { return "[X]" }
            if maxUtil >= 70 { return "[!]" }
            return "[OK]"
        case .retro:
            if maxUtil >= 90 { return "☠" }
            if maxUtil >= 70 { return "⚠" }
            return "♥"
        }
    }

    var themeIcon: String {
        switch self {
        case .standard: return "paintbrush"
        case .stoffee: return "sparkles"
        case .terminal: return "terminal"
        case .retro:    return "gamecontroller"
        }
    }

    var defaultGauge: GaugeStyle {
        switch self {
        case .standard: return .linear
        case .stoffee:           return .liquid
        case .terminal:          return .ascii
        case .retro:             return .segmented
        }
    }

    var defaultIconPack: IconPack {
        switch self {
        case .standard: return .classic
        case .stoffee:           return .stoffee
        case .terminal:          return .terminal
        case .retro:             return .retro
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
    @AppStorage("gaugeStyleOverride") private var gaugeOverride: String = ""
    @AppStorage("iconPackOverride")  private var iconOverride: String = ""

    private var effectiveGauge: GaugeStyle { GaugeStyle(rawValue: gaugeOverride) ?? theme.defaultGauge }
    private var effectiveIconPack: IconPack { IconPack(rawValue: iconOverride) ?? theme.defaultIconPack }
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

            // Tab picker — custom so Stoffee theme colors apply
            HStack(spacing: 0) {
                ForEach(AppTab.allCases, id: \.self) { tab in
                    Button(action: { selectedTab = tab }) {
                        Text(tab.rawValue)
                            .font(.subheadline)
                            .fontWeight(selectedTab == tab ? .semibold : .regular)
                            .foregroundColor(selectedTab == tab ? .white : theme.secondaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(selectedTab == tab ? theme.accent : Color.clear)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(theme.barTrack)
            .cornerRadius(8)
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
                theme: theme,
                gaugeStyle: effectiveGauge
            )

            UsageRow(
                title: "Weekly",
                subtitle: "7-day window",
                percentage: usage.weeklyPercentage,
                resetsAt: usage.weeklyResetsAt,
                color: theme.colorForPercentage(usage.weeklyPercentage),
                theme: theme,
                gaugeStyle: effectiveGauge
            )

            if let sonnetPct = usage.sonnetPercentage {
                UsageRow(
                    title: "Sonnet Only",
                    subtitle: "Model-specific",
                    percentage: sonnetPct,
                    resetsAt: usage.sonnetResetsAt,
                    color: theme.colorForPercentage(sonnetPct),
                    theme: theme,
                    gaugeStyle: effectiveGauge
                )
            }

            // Extra usage / overage (if enabled)
            if usage.extraUsageEnabled, let limit = usage.extraUsageMonthlyLimit, let used = usage.extraUsageUsedCredits {
                OverageRow(
                    usedDollars: used / 100,
                    limitDollars: limit / 100,
                    percentage: usage.extraUsagePercentage ?? 0,
                    theme: theme,
                    gaugeStyle: effectiveGauge
                )
            }

            if let ts = manager.tokenStats {
                TokenStatsRow(stats: ts, theme: theme)
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

            VStack(alignment: .leading, spacing: 6) {
                Text("Theme")
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    ForEach(AppTheme.allCases, id: \.self) { t in
                        Button(action: { selectedTheme = t.rawValue }) {
                            HStack(spacing: 6) {
                                Image(systemName: t.themeIcon)
                                Text(t.rawValue)
                                    .font(.caption)
                                Spacer()
                            }
                            .padding(6)
                            .background(t.rawValue == selectedTheme ? theme.accent.opacity(0.25) : theme.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(t.rawValue == selectedTheme ? theme.accent : Color.clear, lineWidth: 1)
                            )
                            .cornerRadius(4)
                            .foregroundColor(theme.primaryText)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

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
                    // Named sessions: show name bold, first prompt as subtitle
                    if session.hasCustomName {
                        Text(session.displayTitle)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                            .foregroundColor(theme.accent)
                        if !session.firstPrompt.isEmpty {
                            Text(session.firstPrompt)
                                .font(.caption)
                                .lineLimit(1)
                                .foregroundColor(theme.secondaryText)
                        }
                    } else {
                        Text(session.displayTitle)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(2)
                            .foregroundColor(theme.primaryText)
                    }

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
    var gaugeStyle: GaugeStyle = .linear

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
            Group {
                switch gaugeStyle {
                case .linear:
                    LinearGauge(percentage: percentage, color: color, theme: theme)
                case .segmented:
                    SegmentedGauge(percentage: percentage, color: color, theme: theme)
                case .liquid:
                    LiquidGauge(percentage: percentage, color: color, theme: theme)
                case .ascii:
                    ASCIIGauge(percentage: percentage, title: title)
                }
            }

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
    var gaugeStyle: GaugeStyle = .linear

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
            Group {
                switch gaugeStyle {
                case .linear:
                    LinearGauge(percentage: min(percentage, 100), color: color, theme: theme)
                case .segmented:
                    SegmentedGauge(percentage: min(percentage, 100), color: color, theme: theme)
                case .liquid:
                    LiquidGauge(percentage: min(percentage, 100), color: color, theme: theme)
                case .ascii:
                    ASCIIGauge(percentage: min(percentage, 100), title: "Overage")
                }
            }
        }
        .padding(12)
        .background(theme.cardBackground)
        .cornerRadius(8)
    }
}

// MARK: - Gauges

struct LinearGauge: View {
    let percentage: Int
    let color: Color
    var theme: AppTheme = .standard

    var body: some View {
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
}

#Preview("LinearGauge") {
    VStack(spacing: 16) {
        LinearGauge(percentage: 0, color: .green)
        LinearGauge(percentage: 33, color: .green)
        LinearGauge(percentage: 67, color: .orange)
        LinearGauge(percentage: 95, color: .red)
        LinearGauge(percentage: 120, color: .red)
    }
    .padding()
    .frame(width: 280)
}

struct SegmentedGauge: View {
    let percentage: Int
    let color: Color
    var theme: AppTheme = .standard
    let segmentCount: Int = 10

    var filledSegments: Int {
        let clamped = max(0, min(percentage, 100))
        return Int((Double(clamped) / 100.0) * Double(segmentCount).rounded())
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<segmentCount, id: \.self) { index in
                Rectangle()
                    .fill(index < filledSegments ? color : theme.barTrack)
                    .frame(height: 10)
            }
        }
        .frame(height: 10)
    }
}

#Preview("SegmentedGauge") {
    VStack(spacing: 16) {
        SegmentedGauge(percentage: 0, color: .green)
        SegmentedGauge(percentage: 25, color: .green)
        SegmentedGauge(percentage: 67, color: .orange)
        SegmentedGauge(percentage: 100, color: .red)
    }
    .padding()
    .frame(width: 280)
    .background(Color(red: 0.13, green: 0.13, blue: 0.22))
}

struct ASCIIGauge: View {
    let percentage: Int
    let title: String
    let barWidth: Int = 18

    private var asciiBar: String {
        let clamped = max(0, min(percentage, 100))
        let filled = Int((Double(clamped) / 100.0) * Double(barWidth))
        let empty = barWidth - filled
        return String(repeating: "█", count: filled) + String(repeating: "░", count: empty)
    }

    private var paddedTitle: String {
        let upper = title.uppercased()
        if upper.count >= 8 { return String(upper.prefix(8)) }
        return upper + String(repeating: " ", count: 8 - upper.count)
    }

    var body: some View {
        Text("\(paddedTitle) [\(asciiBar)] \(percentage)%")
            .font(.system(.body, design: .monospaced))
            .foregroundColor(Color(red: 0.0, green: 1.0, blue: 0.0))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(Color.black)
            .cornerRadius(4)
    }
}

#Preview("ASCIIGauge") {
    VStack(spacing: 8) {
        ASCIIGauge(percentage: 0, title: "Session")
        ASCIIGauge(percentage: 33, title: "Weekly")
        ASCIIGauge(percentage: 67, title: "Sonnet")
        ASCIIGauge(percentage: 98, title: "Opus")
    }
    .padding()
    .frame(width: 280)
}

struct LiquidGauge: View {
    let percentage: Int
    let color: Color
    var theme: AppTheme = .standard

    var body: some View {
        GeometryReader { geometry in
            let clamped = max(0, min(percentage, 100))
            let fillWidth = geometry.size.width * CGFloat(clamped) / 100

            ZStack(alignment: .leading) {
                // Track + outline
                RoundedRectangle(cornerRadius: 4)
                    .stroke(color, lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(theme.barTrack.opacity(0.6))
                    )

                // Animated fill
                TimelineView(.animation) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    let phase = CGFloat(t.truncatingRemainder(dividingBy: 2.5)) / 2.5

                    Canvas { ctx, size in
                        let fillRect = CGRect(x: 0, y: 0, width: fillWidth, height: size.height)
                        ctx.clip(to: Path(roundedRect: CGRect(x: 0, y: 0, width: size.width, height: size.height),
                                          cornerRadius: 4))
                        ctx.fill(Path(fillRect), with: .color(color.opacity(0.85)))

                        // Wave overlay
                        var wave = Path()
                        let waveHeight: CGFloat = 3
                        let waveY = size.height * 0.15
                        wave.move(to: CGPoint(x: 0, y: waveY))
                        let segments = 40
                        for i in 0...segments {
                            let x = fillRect.width * CGFloat(i) / CGFloat(segments)
                            let angle = (CGFloat(i) / CGFloat(segments) * .pi * 2) + (phase * .pi * 2)
                            let y = waveY + sin(angle) * waveHeight
                            wave.addLine(to: CGPoint(x: x, y: y))
                        }
                        wave.addLine(to: CGPoint(x: fillRect.width, y: size.height))
                        wave.addLine(to: CGPoint(x: 0, y: size.height))
                        wave.closeSubpath()
                        ctx.fill(wave, with: .color(.white.opacity(0.35)))
                    }
                    .frame(width: fillWidth)
                }
            }
        }
        .frame(height: 14)
    }
}

#Preview("LiquidGauge") {
    VStack(spacing: 16) {
        LiquidGauge(percentage: 0, color: Color(red: 1.0, green: 0.2, blue: 0.6))
        LiquidGauge(percentage: 33, color: Color(red: 0.6, green: 0.2, blue: 1.0))
        LiquidGauge(percentage: 67, color: Color(red: 1.0, green: 0.4, blue: 0.9))
        LiquidGauge(percentage: 98, color: Color(red: 1.0, green: 0.1, blue: 0.3))
    }
    .padding()
    .frame(width: 280)
    .background(Color(red: 0.12, green: 0.03, blue: 0.18))
}

// MARK: - Token Stats Row

struct TokenStatsRow: View {
    let stats: TokenStats
    var theme: AppTheme = .standard

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Token Usage")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(theme.primaryText)

            HStack(spacing: 0) {
                tokenCell(label: "Today", value: stats.todayTokens)
                Divider().frame(height: 36)
                tokenCell(label: "This Week", value: stats.weekTokens)
                Divider().frame(height: 36)
                VStack(spacing: 2) {
                    Text(formatTokens(stats.mostActiveDayTokens))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.accent)
                    Text("Best: \(stats.mostActiveDay)")
                        .font(.caption2)
                        .foregroundColor(theme.secondaryText)
                }
                .frame(maxWidth: .infinity)
                Divider().frame(height: 36)
                VStack(spacing: 2) {
                    Text("\(stats.currentStreak)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(stats.currentStreak > 0 ? theme.accent : theme.secondaryText)
                    Text("Day Streak")
                        .font(.caption2)
                        .foregroundColor(theme.secondaryText)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(12)
        .background(theme.cardBackground)
        .cornerRadius(8)
    }

    @ViewBuilder
    func tokenCell(label: String, value: Int) -> some View {
        VStack(spacing: 2) {
            Text(formatTokens(value))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(theme.primaryText)
            Text(label)
                .font(.caption2)
                .foregroundColor(theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    func formatTokens(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000     { return String(format: "%.1fk", Double(n) / 1_000) }
        return "\(n)"
    }
}

#Preview {
    UsageView(manager: UsageManager(), sessionManager: SessionManager())
}
