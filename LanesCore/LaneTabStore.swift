import Foundation
import os

/// Lane to last recorded herdr tab, persisted to disk.
///
/// This must outlive the hook's sidecar files: SessionMonitor hides a sidecar
/// after 12h and deletes it after 48h, while the lanes worth resuming are the
/// ones idle for days.
///
/// Not thread safe. The app only touches it from the main actor.
public final class LaneTabStore {
    private static let logger = Logger(subsystem: "com.helpfully.ClaudeUsage", category: "lanes")
    private let url: URL
    private var map: [String: RecordedTab]

    public init(url: URL) {
        self.url = url
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .secondsSince1970
        map = (try? Data(contentsOf: url)).flatMap { try? dec.decode([String: RecordedTab].self, from: $0) } ?? [:]
    }

    public func all() -> [String: RecordedTab] { map }

    /// Keeps the newest record per lane; an older one is ignored.
    public func record(lane: String, _ tab: RecordedTab) {
        if let old = map[lane], old.recordedAt > tab.recordedAt { return }
        guard map[lane] != tab else { return }
        map[lane] = tab

        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .secondsSince1970
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data: Data
        do {
            data = try enc.encode(map)
        } catch {
            Self.logger.error("lane-tabs write failed: \(error.localizedDescription, privacy: .public)")
            return
        }

        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                     withIntermediateDirectories: true)
        } catch {
            Self.logger.error("lane-tabs write failed: \(error.localizedDescription, privacy: .public)")
            return
        }

        do {
            try data.write(to: url, options: .atomic)
        } catch {
            Self.logger.error("lane-tabs write failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
