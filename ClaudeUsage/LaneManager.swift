import Foundation
import Combine
#if canImport(LanesCore)
import LanesCore
#endif

/// Dormant lanes (LANES-SPEC) for the popover.
@MainActor
final class LaneManager: ObservableObject {
    @Published private(set) var lanes: [Lane] = []
    /// Non-nil when any part of the list comes from the disk cache. The UI
    /// must show it (spec D4).
    @Published private(set) var cachedAt: Date?
    /// Board unreachable AND nothing cached.
    @Published private(set) var unavailable = false
    /// False when the work thread could not be loaded, live or cached, this
    /// refresh. `openCounts` is then empty, and every lane's count must read
    /// as unknown rather than "0 open" as if that were live data (spec D4).
    @Published private(set) var openCountsKnown = true
    /// Reason the most recent refresh served cached or missing data, for
    /// either half of the board. nil when both halves were live.
    @Published private(set) var boardError: String?
    @Published var lastError: String?

    let store = LaneTabStore(url: FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/claudeusage/lane-tabs.json"))

    private let board = BoardClient()
    /// Lane cards by lane, re-read on every refresh. Absent is normal.
    private(set) var cards: [String: LaneCard] = [:]
    private var roster: [RosterSeat] = []
    private var openCounts: [String: Int] = [:]
    private var liveLanes: Set<String> = []
    private var lastFetch: Date?
    private var cancellables = Set<AnyCancellable>()

    init(sessionMonitor: SessionMonitor) {
        sessionMonitor.$sessions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.absorb($0) }
            .store(in: &cancellables)
    }

    /// Keep the lane to tab links the hook reports, and note which lanes are live.
    private func absorb(_ sessions: [ClaudeSession]) {
        for s in sessions {
            guard let lane = s.lane, let tab = s.herdrTabId, !s.cwd.isEmpty else { continue }
            store.record(lane: lane, RecordedTab(tabId: tab, cwd: s.cwd, sessionId: s.id, recordedAt: s.updatedAt))
        }
        liveLanes = Set(sessions.compactMap(\.lane))
        rebuild()
    }

    /// `force: false` skips the network when the last fetch is under a minute
    /// old; the popover opens far more often than the board changes.
    func refresh(force: Bool = false) async {
        if !force, let last = lastFetch, Date().timeIntervalSince(last) < 60 { return }
        lastFetch = Date()

        // An empty but well-formed response is not good data: the 2026-09-14
        // outage was a 200 with an empty database, and it must not overwrite
        // a good cache (spec D4).
        let rosterF = await board.fetch("agents?json=1", cacheAs: "agents.json") {
            (try? Roster.parse($0))?.isEmpty == false
        }
        let workF = await board.fetch("t/work?json=1", cacheAs: "work.json") { data in
            guard let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return false }
            return (obj["posts"] as? [Any])?.isEmpty == false
        }

        boardError = [Self.reason(rosterF), Self.reason(workF)].compactMap { $0 }.first

        guard let rosterF, let seats = try? Roster.parse(rosterF.data) else {
            unavailable = true
            return
        }
        unavailable = false
        roster = seats
        openCountsKnown = workF != nil
        openCounts = workF.flatMap { try? WorkItems.openCounts($0.data) } ?? [:]
        cards = Self.loadCards()
        // If either half is stale the list is; report the older timestamp.
        cachedAt = [rosterF, workF].compactMap { $0 }.filter(\.fromCache).map(\.at).min()
        rebuild()
    }

    /// "board unreachable" when the fetch produced nothing at all (no live
    /// data, no cache); otherwise the fetch's own reason, nil when live.
    private static func reason(_ f: BoardClient.Fetched?) -> String? {
        guard let f else { return "board unreachable" }
        return f.liveFailure
    }

    private func rebuild() {
        lanes = LaneList.dormant(roster: roster,
                                 openCounts: openCounts,
                                 recordedCwd: store.all().mapValues(\.cwd),
                                 cardCwd: cards.compactMapValues(\.cwd),
                                 liveLanes: liveLanes)
    }

    /// `~/.claude/lanes/*.json`. Small files and few of them; unreadable or
    /// non-v1 cards are skipped. The filename is not trusted for the lane
    /// name, the card's own `lane` field is.
    private static func loadCards() -> [String: LaneCard] {
        let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/lanes")
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        var out: [String: LaneCard] = [:]
        for f in files where f.pathExtension == "json" {
            if let data = try? Data(contentsOf: f), let card = LaneCard.parse(data) { out[card.lane] = card }
        }
        return out
    }
}
