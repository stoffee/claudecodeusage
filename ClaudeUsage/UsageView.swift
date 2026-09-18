import SwiftUI
import AppKit
import ServiceManagement

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
    @ObservedObject var sessionMonitor: SessionMonitor
    @ObservedObject var statusMonitor: StatusMonitor
    @ObservedObject var updateInstaller: UpdateInstaller
    @Environment(\.openURL) var openURL
    @AppStorage("appTheme") private var selectedTheme: String = AppTheme.standard.rawValue
    private var theme: AppTheme { AppTheme(rawValue: selectedTheme) ?? .standard }
    @AppStorage("gaugeStyleOverride") private var gaugeOverride: String = ""
    @AppStorage("iconPackOverride")  private var iconOverride: String = ""
    @AppStorage("themeSectionExpanded") private var themeExpanded: Bool = false

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

                if manager.isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding()
            .background(theme.headerBackground)

            // Update available banner
            if let newVersion = manager.updateAvailable {
                updateBanner(newVersion)
            }

            Divider()

            usageTabContent()

            Divider()

            // Claude service status (from status.claude.com)
            statusRow()

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
        // Live Claude Code sessions (when alert hooks are installed)
        if sessionMonitor.hooksInstalled && !sessionMonitor.sessions.isEmpty {
            sessionsSection()
            Divider()
        }

        if let error = manager.error {
            errorView(error)
        } else if let usage = manager.usage {
            usageContent(usage)
        } else {
            loadingView()
        }
    }

    /// "4.2M / ~10.0M tokens (est., this Mac)" under the weekly gauge — nil
    /// whenever the estimate would be untrustworthy or the local scan found
    /// nothing. See `UsageData.impliedWeeklyBudget`.
    func weeklyTokenFootnote(_ usage: UsageData) -> String? {
        guard let stats = manager.tokenStats,
              let budget = usage.impliedWeeklyBudget(windowTokens: stats.windowTokens)
        else { return nil }
        return "\(formatTokenCount(stats.windowTokens)) / ~\(formatTokenCount(budget)) tokens (est., this Mac)"
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
                gaugeStyle: effectiveGauge,
                footnote: weeklyTokenFootnote(usage)
            )

            if !usage.modelLimits.isEmpty {
                ForEach(usage.modelLimits, id: \.displayName) { limit in
                    UsageRow(
                        title: "\(limit.displayName) Only",
                        subtitle: "Model-specific",
                        percentage: limit.percentage,
                        resetsAt: limit.resetsAt,
                        color: theme.colorForPercentage(limit.percentage),
                        theme: theme,
                        gaugeStyle: effectiveGauge
                    )
                }
            } else if let sonnetPct = usage.sonnetPercentage {
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

    // MARK: - Error / Loading

    @ViewBuilder
    func sessionsSection() -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("CLAUDE SESSIONS")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            ForEach(sessionMonitor.sessions) { session in
                Button(action: {
                    AppDelegate.shared?.popover?.performClose(nil)
                    sessionMonitor.focusSession(session)
                }) {
                    HStack(spacing: 8) {
                        Text(sessionIcon(session))
                            .font(.caption)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(session.projectName)
                                .font(.caption)
                                .fontWeight(.medium)
                                .lineLimit(1)
                            Text(sessionLabel(session))
                                .font(.caption2)
                                .foregroundColor(session.status == .needsAttention && !session.acknowledged ? .orange : .secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Text(session.updatedAt.formatted(.relative(presentation: .named)))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 2)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Jump to this session's terminal window")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    func sessionIcon(_ session: ClaudeSession) -> String {
        switch session.status {
        case .needsAttention: return session.acknowledged ? "🔕" : "🔔"
        case .running: return "⚙️"
        case .finished: return "✅"
        }
    }

    func sessionLabel(_ session: ClaudeSession) -> String {
        switch session.status {
        case .needsAttention:
            if session.acknowledged { return "Waiting (seen)" }
            return session.message.isEmpty ? "Needs your input" : session.message
        case .running:
            return "Working…"
        case .finished:
            return "Finished"
        }
    }

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
    func updateBanner(_ newVersion: String) -> some View {
        VStack(spacing: 4) {
            switch updateInstaller.state {
            case .idle:
                if let downloadURL = manager.updateDownloadURL {
                    Button(action: {
                        Task { await updateInstaller.installUpdate(from: downloadURL) }
                    }) {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("Update to v\(newVersion) & Relaunch")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                } else {
                    // No zip asset found — fall back to manual download
                    Button(action: {
                        openURL(URL(string: "https://github.com/richhickson/claudecodeusage/releases/latest")!)
                    }) {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("Update Available: v\(newVersion)")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
            case .downloading:
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.6)
                    Text("Downloading v\(newVersion)…").font(.caption)
                }
            case .installing:
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.6)
                    Text("Verifying & installing…").font(.caption)
                }
            case .relaunching:
                Text("Relaunching…").font(.caption)
            case .failed(let message):
                Text("Update failed: \(message)")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Download manually") {
                    openURL(URL(string: "https://github.com/richhickson/claudecodeusage/releases/latest")!)
                }
                .font(.caption)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    func statusRow() -> some View {
        if let indicator = statusMonitor.indicator {
            Button(action: {
                openURL(URL(string: StatusMonitor.statusPageURL)!)
            }) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor(indicator))
                        .frame(width: 8, height: 8)
                    Text(statusMonitor.statusDescription.isEmpty ? "Claude status" : statusMonitor.statusDescription)
                        .font(.caption)
                        .foregroundColor(indicator == "none" ? .secondary : .primary)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(statusMonitor.incidentName.isEmpty ? "Open status.claude.com" : statusMonitor.incidentName)
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
    }

    func statusColor(_ indicator: String) -> Color {
        switch indicator {
        case "none": return .green
        case "minor": return .yellow
        case "major": return .orange
        default: return .red // critical
        }
    }

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
                Button(action: { withAnimation(.easeInOut(duration: 0.15)) { themeExpanded.toggle() } }) {
                    HStack(spacing: 4) {
                        Image(systemName: themeExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption2)
                        Text("Theme")
                            .font(.caption)
                        Spacer()
                        Text(theme.rawValue)
                            .font(.caption2)
                            .foregroundColor(theme.secondaryText.opacity(0.7))
                    }
                    .foregroundColor(theme.secondaryText)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if themeExpanded {
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

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Gauge Style")
                            .font(.caption2)
                            .foregroundColor(theme.secondaryText)

                        HStack(spacing: 6) {
                            Picker("", selection: $gaugeOverride) {
                                Text("Theme default (\(theme.defaultGauge.displayName))").tag("")
                                ForEach(GaugeStyle.allCases) { g in
                                    Text(g.displayName).tag(g.rawValue)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()

                            if !gaugeOverride.isEmpty {
                                Button(action: { gaugeOverride = "" }) {
                                    Image(systemName: "arrow.counterclockwise")
                                        .foregroundColor(theme.secondaryText)
                                }
                                .buttonStyle(.borderless)
                                .help("Reset to theme default")
                            }
                        }
                    }
                    .padding(.top, 4)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Icon Pack")
                            .font(.caption2)
                            .foregroundColor(theme.secondaryText)

                        HStack(spacing: 6) {
                            Picker("", selection: $iconOverride) {
                                Text("Theme default (\(theme.defaultIconPack.displayName))").tag("")
                                ForEach(IconPack.allCases) { p in
                                    Text(p.displayName).tag(p.rawValue)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()

                            if !iconOverride.isEmpty {
                                Button(action: { iconOverride = "" }) {
                                    Image(systemName: "arrow.counterclockwise")
                                        .foregroundColor(theme.secondaryText)
                                }
                                .buttonStyle(.borderless)
                                .help("Reset to theme default")
                            }
                        }
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
                    Task { await manager.refresh() }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(theme.secondaryText)
                }
                .buttonStyle(.borderless)
                .disabled(manager.isLoading)

                Button(action: {
                    openURL(URL(string: "https://claude.ai")!)
                }) {
                    Image(systemName: "globe")
                        .foregroundColor(theme.secondaryText)
                }
                .buttonStyle(.borderless)

                Button(action: {
                    AppDelegate.shared?.openSettingsWindow()
                }) {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.borderless)
                .help("Claude Code settings (CLAUDE.md, retention)")

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

// MARK: - Usage Row

struct UsageRow: View {
    let title: String
    let subtitle: String
    let percentage: Int
    let resetsAt: Date?
    let color: Color
    var theme: AppTheme = .standard
    var gaugeStyle: GaugeStyle = .linear
    var footnote: String? = nil

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

            if let footnote = footnote {
                Text(footnote)
                    .font(.caption2)
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

func formatTokenCount(_ n: Int) -> String {
    if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
    if n >= 1_000     { return String(format: "%.1fk", Double(n) / 1_000) }
    return "\(n)"
}

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

    func formatTokens(_ n: Int) -> String { formatTokenCount(n) }
}

#Preview {
    UsageView(
        manager: UsageManager(),
        sessionMonitor: SessionMonitor(),
        statusMonitor: StatusMonitor(),
        updateInstaller: UpdateInstaller()
    )
}
