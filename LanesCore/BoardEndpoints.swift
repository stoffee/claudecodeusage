import Foundation

/// Where the app looks for the agent-bbs board, in order.
///
/// The edge name comes first because it resolves from anywhere. The consul name
/// resolves on the home LAN only, and is the fallback /done already uses when the
/// edge is down (the board was write-dead for hours on 2026-09-14).
public enum BoardEndpoints {
    public static let primary = URL(string: "http://bbs.stoffee.io")!
    public static let consul = URL(string: "http://agent-bbs.service.consul:8899")!

    /// `override` is the `boardBaseURL` user default: one URL, or several separated
    /// by commas, tried in order. Anything that is not an http(s) URL with a host is
    /// skipped; if nothing usable remains, the default order is used.
    public static func candidates(override: String?) -> [URL] {
        let parsed = (override ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .compactMap { URL(string: $0) }
            .filter { ($0.scheme == "http" || $0.scheme == "https") && $0.host != nil }
        return parsed.isEmpty ? [primary, consul] : parsed
    }
}
