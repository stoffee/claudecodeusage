import Foundation

public enum WorkItems {
    public enum ParseError: Error, Equatable { case notAThread }

    /// Open WORK items per lane, from `GET /t/work?json=1`.
    ///
    /// Open (LANES-SPEC, "Board API"): the body starts with `WORK:`, its
    /// `STATE:` is `open`, and no post in the thread says `Closes /p/<its id>`.
    /// `claimed` and `blocked` are not open: the spec names `open` only.
    ///
    /// Also skipped: posts the board marks `superseded_by`. The replacement is
    /// a newer WORK post, so counting both would count one item twice.
    public static func openCounts(_ data: Data) throws -> [String: Int] {
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let posts = obj["posts"] as? [[String: Any]] else { throw ParseError.notAThread }

        var closed = Set<Int>()
        for p in posts {
            if let body = p["body"] as? String { closed.formUnion(closedIds(in: body)) }
        }

        var counts: [String: Int] = [:]
        for p in posts {
            guard let body = p["body"] as? String, body.hasPrefix("WORK:"),
                  let id = (p["id"] as? NSNumber)?.intValue,
                  !closed.contains(id),
                  !(p["superseded_by"] is NSNumber),
                  field("STATE", in: body)?.split(separator: " ").first?.lowercased() == "open",
                  let lane = field("LANE", in: body) else { continue }
            counts[lane, default: 0] += 1
        }
        return counts
    }

    /// Value of a `KEY: value` line, trimmed. nil when absent or empty.
    static func field(_ key: String, in body: String) -> String? {
        let prefix = key + ":"
        for line in body.split(whereSeparator: \.isNewline) where line.hasPrefix(prefix) {
            let value = line.dropFirst(prefix.count).trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        }
        return nil
    }

    /// Post ids named by the board's `Closes /p/<id>` convention.
    static func closedIds(in body: String) -> [Int] {
        let regex = try! NSRegularExpression(pattern: #"[Cc]loses /p/(\d+)"#)
        let range = NSRange(body.startIndex..., in: body)
        return regex.matches(in: body, range: range).compactMap { m in
            Range(m.range(at: 1), in: body).flatMap { Int(body[$0]) }
        }
    }
}
