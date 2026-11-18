import Foundation

/// A provider's title name made ready for a database search
/// (title-metadata/a-title-is-matched-by-its-database-id-first).
public enum TitleName {
    /// "EN | Dune: Part Two (2024) 4K" becomes "Dune: Part Two" and 2024.
    /// Strips, in order, a leading language or country tag, a year in
    /// parentheses or brackets (kept as the year), and quality and release
    /// words. Case and inner spacing are kept.
    public static func clean(_ raw: String) -> (name: String, year: Int?) {
        var name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        name = replacing(leadingTag, in: name, with: "")
        let found = yearInBrackets?.matches(in: name, range: NSRange(name.startIndex..., in: name)).last
        let range = found.flatMap { Range($0.range, in: name) }
        let digits = found.flatMap { Range($0.range(at: 1), in: name) }
        let year = digits.flatMap { Int(name[$0]) }
        if let range { name.replaceSubrange(range, with: " ") }
        name = replacing(qualityWords, in: name, with: " ")
        name = replacing(spaces, in: name, with: " ")
        name = name.trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: "-|·")))
        return (name.isEmpty ? raw.trimmingCharacters(in: .whitespacesAndNewlines) : name, year)
    }

    /// The name lowercased, without accents and with single spaces, for
    /// comparing two names.
    public static func folded(_ name: String) -> String {
        let folded = name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        return replacing(spaces, in: folded, with: " ").trimmingCharacters(in: .whitespaces)
    }

    // "EN |", "[MULTI]", "4K-NF:", "UK -". A dash or colon needs an
    // upper-case tag of up to four characters, so "Dune: Part Two" keeps its name.
    private static let leadingTag = regex(
        "^(?:"
            + [
                #"\[[^\]]{1,12}\]\s*[|:\-]?\s*"#,
                #"[A-Za-z0-9]{2,8}(?:-[A-Za-z0-9]{2,8})*\s*\|\s*"#,
                #"[A-Z0-9]{2,4}(?:-[A-Z0-9]{2,4})*\s*[:\-]\s+"#,
                #"[A-Z0-9]{2,4}(?:-[A-Z0-9]{2,4})+:\s*"#,
            ].joined(separator: "|") + ")")
    private static let yearInBrackets = regex(#"\s*[\(\[]((?:19|20)\d{2})[\)\]]"#)
    private static let qualityWords = regex(
        #"(?i)(?<![A-Za-z0-9])(?:4K|UHD|FHD|2160p|1080p|720p|HDR10\+?|HDR|x264|x265|HEVC|MULTI|VOSTFR|DUBBED)(?![A-Za-z0-9])"#)
    private static let spaces = regex(#"\s+"#)

    private static func regex(_ pattern: String) -> NSRegularExpression? {
        try? NSRegularExpression(pattern: pattern)
    }

    private static func replacing(_ regex: NSRegularExpression?, in text: String, with template: String) -> String {
        regex?.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: template) ?? text
    }
}
