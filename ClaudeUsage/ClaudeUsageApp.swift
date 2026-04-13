import SwiftUI
import Combine

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
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var usageManager = UsageManager()
    var sessionManager = SessionManager()
    var timer: Timer?
    var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon - menubar only
        NSApp.setActivationPolicy(.accessory)

        setupStatusItem()
        setupPopover()
        setupWakeNotification()
        setupUsageObserver()
        startFetching()
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
    }

    @objc func handleWake() {
        // Delay refresh after wake to allow keychain to unlock
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            await usageManager.refresh()
        }
    }

    func startFetching() {
        // Initial fetch and update check
        Task {
            // If system recently booted (within 60 seconds), wait before accessing keychain
            // The keychain/login system takes time to be fully available after boot
            let uptime = ProcessInfo.processInfo.systemUptime
            if uptime < 60 {
                let delaySeconds = max(30 - uptime, 5) // Wait until ~30s after boot, minimum 5s
                try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
            }

            await usageManager.refresh()
        }

        // Refresh every 5 minutes (usage + sessions)
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.usageManager.refresh()
                self?.sessionManager.loadSessions()
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
        popover?.contentViewController = NSHostingController(
            rootView: UsageView(manager: usageManager, sessionManager: sessionManager)
        )
    }

    func updateStatusItem() {
        guard let button = statusItem?.button else { return }

        if let usage = usageManager.usage {
            // Overage mode: only when session is maxed (≥90%) AND extra usage is being drawn
            if usage.extraUsageEnabled,
               let limit = usage.extraUsageMonthlyLimit,
               let used = usage.extraUsageUsedCredits,
               limit > 0, used > 0, usage.sessionPercentage >= 90 {
                let pct = min(Int((used / limit) * 100), 999)
                let dollars = String(format: "$%.2f", used / 100)
                let pink = NSColor(red: 1.0, green: 0.2, blue: 0.6, alpha: 1.0)
                let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
                let attrs: [NSAttributedString.Key: Any] = [.foregroundColor: pink, .font: font]
                button.attributedTitle = NSAttributedString(string: "$$ \(pct)% \(dollars)", attributes: attrs)
            } else {
                // Normal mode: clear any attributed title, use plain text
                button.attributedTitle = NSAttributedString(string: "")
                let sessionPct = usage.sessionPercentage
                button.title = "\(usageManager.statusEmoji) \(sessionPct)%"
            }
        } else if usageManager.error != nil {
            button.attributedTitle = NSAttributedString(string: "")
            button.title = "\u{274C}"
        } else {
            button.attributedTitle = NSAttributedString(string: "")
            button.title = "\u{23F3}"
        }
    }

    @objc func togglePopover() {
        guard let button = statusItem?.button, let popover = popover else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            // Refresh sessions each time the popover opens (lightweight local I/O)
            sessionManager.loadSessions()

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
