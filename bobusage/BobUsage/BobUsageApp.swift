import SwiftUI
import Combine

@main
struct BobUsageApp: App {
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
    var usageManager = BobUsageManager()
    var timer: Timer?
    var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon - menubar only
        NSApp.setActivationPolicy(.accessory)

        setupStatusItem()
        setupPopover()
        setupUsageObserver()
        startFetching()
    }

    func setupUsageObserver() {
        // Auto-update status item when usage changes
        usageManager.$stats
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateStatusItem() }
            .store(in: &cancellables)

        usageManager.$error
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateStatusItem() }
            .store(in: &cancellables)
    }

    func startFetching() {
        // Initial fetch
        Task {
            await usageManager.refresh()
        }

        // Refresh every 2 minutes
        timer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.usageManager.refresh()
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
        popover?.contentSize = NSSize(width: 340, height: 400)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(
            rootView: BobUsageView(manager: usageManager)
        )
    }

    func updateStatusItem() {
        guard let button = statusItem?.button else { return }

        if let stats = usageManager.stats {
            let emoji = usageManager.statusEmoji
            button.title = "\(emoji) \(stats.todayMessages)"
        } else if usageManager.error != nil {
            button.title = "❌"
        } else {
            button.title = "⏳"
        }
    }

    @objc func togglePopover() {
        guard let button = statusItem?.button, let popover = popover else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
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
