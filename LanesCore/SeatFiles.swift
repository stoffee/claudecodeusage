import Foundation

/// Lane folders from `.claude/bbs-agent` files.
///
/// A bbs-agent file that names exactly one seat is a record Stoaf wrote, and
/// LANES-SPEC already treats it as authoritative for the session hook. The
/// folder that holds it is where that lane works. This is NOT inference: a file
/// naming several seats, or a seat claimed by more than one folder, gives no
/// folder at all.
public enum SeatFiles {
    /// Seats named by a bbs-agent file, parsed the way the session hook does:
    /// `#` comments stripped, spaces, tabs and carriage returns removed,
    /// blank lines skipped.
    public static func seats(in contents: String) -> [String] {
        contents.split(whereSeparator: \.isNewline).compactMap { line in
            let noComment = line.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false).first ?? ""
            let seat = noComment.filter { !$0.isWhitespace }
            return seat.isEmpty ? nil : seat
        }
    }

    /// seat -> folder, from each bbs-agent file's folder and contents. Only
    /// single-seat files count, and a seat claimed by two or more folders is
    /// dropped as ambiguous.
    public static func folders(from files: [(folder: String, contents: String)]) -> [String: String] {
        var claims: [String: Set<String>] = [:]
        for file in files {
            let named = seats(in: file.contents)
            guard named.count == 1 else { continue }
            claims[named[0], default: []].insert(file.folder)
        }
        return claims.compactMapValues { $0.count == 1 ? $0.first : nil }
    }
}
