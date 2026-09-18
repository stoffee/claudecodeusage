import SwiftUI
import Combine
import UserNotifications

@main
struct ClaudeUsageApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    static private(set) var shared: AppDelegate?

    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var settingsWindow: NSWindow?
    var usageManager = UsageManager()
    var sessionMonitor = SessionMonitor()
    var statusMonitor = StatusMonitor()
    var updateInstaller = UpdateInstaller()
    lazy var laneManager = LaneManager(sessionMonitor: sessionMonitor)
    var timer: Timer?
    var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self

        // One-shot migration: legacy "System" theme is merged into "Default" (Standard).
        if UserDefaults.standard.string(forKey: "appTheme") == "System" {
            UserDefaults.standard.set("Default", forKey: "appTheme")
        }

        // Hide dock icon - menubar only
        NSApp.setActivationPolicy(.accessory)

        // Present notification banners even when the app is considered active
        UNUserNotificationCenter.current().delegate = self

        setupStatusItem()
        setupPopover()
        setupWakeNotification()
        setupUsageObserver()
        startFetching()
        statusMonitor.start()

        // Request notification permission after launch completes (too early fails silently)
        if sessionMonitor.hooksInstalled {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.sessionMonitor.requestNotificationPermission()
            }
        }
    }

    func setupWakeNotification() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    func setupUsageObserver() {
        // Auto-update status item when usage or error changes
        usageManager.$usage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateStatusItem() }
            .store(in: &cancellables)

        usageManager.$error
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateStatusItem() }
            .store(in: &cancellables)

        sessionMonitor.$sessions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateStatusItem() }
            .store(in: &cancellables)

        // Refresh status item when appearance preferences change (theme / overrides)
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateStatusItem() }
            .store(in: &cancellables)
    }

    @objc func handleWake() {
        // Delay refresh after wake to allow keychain to unlock
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            await usageManager.refresh()
        }
    }

    func startFetching() {
        // Initial fetch
        Task {
            // If system recently booted (within 60 seconds), wait before accessing keychain
            // The keychain/login system takes time to be fully available after boot
            let uptime = ProcessInfo.processInfo.systemUptime
            if uptime < 60 {
                let delaySeconds = max(30 - uptime, 5) // Wait until ~30s after boot, minimum 5s
                try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
            }

            await usageManager.refresh()
            await laneManager.refresh(force: true)

            // Off by default, see UsageManager.autoUpdateCheckEnabled. Flipping
            // it on is how we approve pulling releases from our own fork.
            if UsageManager.autoUpdateCheckEnabled {
                await usageManager.checkForUpdates()
            }
        }

        // Refresh every 5 minutes
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.usageManager.refresh()
                await self?.laneManager.refresh(force: true)
            }
        }
    }

    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.title = "..."
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    func setupPopover() {
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 340, height: 480)
        popover?.behavior = .transient
        let hosting = NSHostingController(
            rootView: UsageView(
                manager: usageManager,
                sessionMonitor: sessionMonitor,
                statusMonitor: statusMonitor,
                updateInstaller: updateInstaller,
                laneManager: laneManager
            )
        )
        // Size the popover to its content. The fixed 480pt height clipped the
        // footer once the lanes section was added.
        hosting.sizingOptions = .preferredContentSize
        popover?.contentViewController = hosting
    }

    func updateStatusItem() {
        guard let button = statusItem?.button else { return }

        let attentionCount = sessionMonitor.needsAttentionSessions.count
        let bell = attentionCount > 0 ? "🔔\(attentionCount) " : ""

        if let usage = usageManager.usage {
            // Overage mode: only when session is maxed (>=90%) AND extra usage is being drawn
            if usage.extraUsageEnabled,
               let limit = usage.extraUsageMonthlyLimit,
               let used = usage.extraUsageUsedCredits,
               limit > 0, used > 0, usage.sessionPercentage >= 90 {
                let pct = min(Int((used / limit) * 100), 999)
                let dollars = String(format: "$%.2f", used / 100)
                let pink = NSColor(red: 1.0, green: 0.2, blue: 0.6, alpha: 1.0)
                let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
                let attrs: [NSAttributedString.Key: Any] = [.foregroundColor: pink, .font: font]
                button.attributedTitle = NSAttributedString(string: "\(bell)$$ \(pct)% \(dollars)", attributes: attrs)
            } else {
                // Normal mode: themed emoji + countdown timer
                button.attributedTitle = NSAttributedString(string: "")
                let sessionPct = usage.sessionPercentage
                let emoji = usageManager.statusEmoji
                let countdown = formatResetTime(usage.sessionResetsAt)
                button.title = "\(bell)\(emoji) \(sessionPct)%\(countdown)"
            }
        } else if usageManager.error != nil {
            button.attributedTitle = NSAttributedString(string: "")
            button.title = "\(bell)\u{274C}"
        } else {
            button.attributedTitle = NSAttributedString(string: "")
            button.title = "\(bell)\u{23F3}"
        }
    }

    func formatResetTime(_ date: Date?) -> String {
        guard let date = date else { return "" }
        let remaining = date.timeIntervalSince(Date())
        guard remaining > 0 else { return "" }

        let hours = Int(remaining / 3600)
        let minutes = Int((remaining.truncatingRemainder(dividingBy: 3600)) / 60)

        if hours >= 1 {
            return " \(hours)h"
        } else {
            return " \(max(minutes, 1))m"
        }
    }

    func openSettingsWindow() {
        popover?.performClose(nil)

        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 520),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "ClaudeUsage Settings"
            window.contentViewController = NSHostingController(rootView: ClaudeSettingsView(sessionMonitor: sessionMonitor, statusMonitor: statusMonitor))
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let sessionId = userInfo["session_id"] as? String
        let statusURL = userInfo["status_url"] as? String
        Task { @MainActor in
            if let sessionId {
                self.sessionMonitor.focusSession(id: sessionId)
            } else if let statusURL, let url = URL(string: statusURL) {
                NSWorkspace.shared.open(url)
            }
            completionHandler()
        }
    }

    @objc func togglePopover() {
        guard let button = statusItem?.button, let popover = popover else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            Task { await laneManager.refresh() }
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

            // Bring to front
            if #available(macOS 14.0, *) {
                NSApp.activate()
            } else {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}
