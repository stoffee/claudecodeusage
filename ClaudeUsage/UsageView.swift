import SwiftUI
import AppKit
import ServiceManagement

enum AppTab: String, CaseIterable {
    case usage = "Usage"
    case sessions = "Sessions"
}

struct UsageView: View {
    @ObservedObject var manager: UsageManager
    @ObservedObject var sessionManager: SessionManager
    @Environment(\.openURL) var openURL
    @State private var selectedTab: AppTab = .usage
    @State private var sessionSearchText: String = ""
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
                    .foregroundColor(.accentColor)
                Text("Claude Usage")
                    .font(.headline)
                Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()

                if manager.isLoading || sessionManager.isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            // Tab picker
            Picker("", selection: $selectedTab) {
                ForEach(AppTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            // Update available banner
            if let newVersion = manager.updateAvailable {
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
                .padding(.horizontal)
                .padding(.bottom, 8)
            }

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
                color: colorForPercentage(usage.sessionPercentage)
            )

            UsageRow(
                title: "Weekly",
                subtitle: "7-day window",
                percentage: usage.weeklyPercentage,
                resetsAt: usage.weeklyResetsAt,
                color: colorForPercentage(usage.weeklyPercentage)
            )

            if let sonnetPct = usage.sonnetPercentage {
                UsageRow(
                    title: "Sonnet Only",
                    subtitle: "Model-specific",
                    percentage: sonnetPct,
                    resetsAt: usage.sonnetResetsAt,
                    color: colorForPercentage(sonnetPct)
                )
            }

            // Extra usage / overage (if enabled)
            if usage.extraUsageEnabled, let limit = usage.extraUsageMonthlyLimit, let used = usage.extraUsageUsedCredits {
                OverageRow(
                    usedDollars: used / 100,
                    limitDollars: limit / 100,
                    percentage: usage.extraUsagePercentage ?? 0
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
                    .foregroundColor(.secondary)
                TextField("Search sessions...", text: $sessionSearchText)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
                if !sessionSearchText.isEmpty {
                    Button(action: { sessionSearchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal)
            .padding(.vertical, 6)

            if filteredSessions.isEmpty && !sessionManager.isLoading {
                VStack(spacing: 12) {
                    Image(systemName: sessionSearchText.isEmpty ? "tray" : "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text(sessionSearchText.isEmpty ? "No sessions found" : "No matching sessions")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, minHeight: 180)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredSessions) { session in
                            SessionRow(session: session, onTap: {
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
            Button(action: {
                Task { await manager.checkForUpdates() }
            }) {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Check for Updates")
                }
            }
            .buttonStyle(.borderless)
            .font(.caption)
            .padding(.top, 8)

            if #available(macOS 14.0, *) {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .toggleStyle(.checkbox)
                    .font(.caption)
                    .onChange(of: launchAtLogin) { _, newValue in setLaunchAtLogin(newValue) }
                    .padding(.horizontal)
            } else {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .toggleStyle(.checkbox)
                    .font(.caption)
                    .onChange(of: launchAtLogin) { newValue in setLaunchAtLogin(newValue) }
                    .padding(.horizontal)
            }

            Divider()

            HStack {
                if let lastUpdated = manager.lastUpdated {
                    Text("Updated \(lastUpdated.formatted(.relative(presentation: .named)))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: {
                    sessionManager.loadSessions()
                    Task { await manager.refresh() }
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .disabled(manager.isLoading && sessionManager.isLoading)

                Button(action: {
                    openURL(URL(string: "https://claude.ai")!)
                }) {
                    Image(systemName: "globe")
                }
                .buttonStyle(.borderless)

                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Image(systemName: "xmark.circle")
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal)

            Divider()

            Button(action: {
                openURL(URL(string: "https://x.com/richhickson")!)
            }) {
                Text("Created by @richhickson")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.borderless)
            .padding(.bottom, 8)
        }
        .background(Color(NSColor.controlBackgroundColor))
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

    func colorForPercentage(_ pct: Int) -> Color {
        if pct >= 90 { return .red }
        if pct >= 70 { return .orange }
        return .green
    }

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
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Delete button
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
                        .foregroundColor(.primary)

                    HStack(spacing: 8) {
                        Label(session.shortProjectName, systemImage: "folder")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)

                        if let branch = session.branchDisplay {
                            Label(branch, systemImage: "arrow.triangle.branch")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        if session.messageCount > 0 {
                            Label("\(session.messageCount)", systemImage: "message")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if !session.relativeModified.isEmpty {
                        Text(session.relativeModified)
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .background(Color(NSColor.controlBackgroundColor))
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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
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
                        .fill(Color(NSColor.separatorColor))
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
                .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
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

    var color: Color {
        if percentage >= 90 { return .red }
        if percentage >= 70 { return .orange }
        return .blue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Overage")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("Extra usage this month")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("$\(String(format: "%.2f", usedDollars))")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(color)
                    Text("of $\(String(format: "%.0f", limitDollars)) limit")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(NSColor.separatorColor))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(min(percentage, 100)) / 100, height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

#Preview {
    UsageView(manager: UsageManager(), sessionManager: SessionManager())
}
