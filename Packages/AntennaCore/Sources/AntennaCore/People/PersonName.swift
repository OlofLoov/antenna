import Foundation

/// One name from a provider's cast or director field, with the key that
/// says two names are the same person
/// (browse-by-person/the-same-person-across-titles).
public struct PersonName: Sendable, Hashable, Codable {
    /// Matches across titles: case, accents, dots and apostrophes ignored,
    /// hyphens and runs of spaces made one space.
    public var key: String
    /// The name as the provider wrote it, trimmed, without a part in brackets.
    public var display: String

    public init(key: String, display: String) {
        self.key = key
        self.display = display
    }

    /// The name, or nil when it is a placeholder such as "Unknown", has
    /// fewer than two letters, or is too long to be a name.
    public init?(_ raw: String) {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let open = text.lastIndex(of: "("), text.hasSuffix(")"), open > text.startIndex {
            text = String(text[..<open]).trimmingCharacters(in: .whitespaces)
        }
        text = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        let key = Self.key(text)
        guard text.count <= Self.longest, key.count(where: \.isLetter) >= 2, !Self.placeholders.contains(key) else {
            return nil
        }
        self.key = key
        display = text
    }

    /// Every name in a provider field, in the provider's order, each key once.
    /// The field splits at commas, slashes, vertical bars, semicolons, middle
    /// dots and line breaks. "Last, First" is not put back together: in a
    /// comma list it cannot be told from two people.
    public static func split(_ field: String?) -> [PersonName] {
        guard var field else { return [] }
        // "N/A" holds a slash, so it goes before the split.
        if field.contains("/") {
            field = field.replacingOccurrences(of: #"(?i)(?<!\p{L})n/a(?!\p{L})"#, with: ",", options: .regularExpression)
        }
        var seen: Set<String> = []
        return field.split(whereSeparator: { separators.contains($0) }).compactMap { part in
            guard let name = PersonName(String(part)), seen.insert(name.key).inserted else { return nil }
            return name
        }
    }

    /// The matching key of `name`.
    public static func key(_ name: String) -> String {
        let folded = name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: posix)
        var scalars = String.UnicodeScalarView()
        for scalar in folded.unicodeScalars where !dropped.contains(scalar) {
            scalars.append(scalar == "-" || CharacterSet.whitespacesAndNewlines.contains(scalar) ? " " : scalar)
        }
        return String(scalars).split(separator: " ").joined(separator: " ")
    }

    /// Longer than this is a description pasted into the field, not a name.
    static let longest = 60
    private static let posix = Locale(identifier: "en_US_POSIX")
    private static let separators: Set<Character> = [",", "/", "|", ";", "·", "\n", "\r", "\r\n"]
    private static let dropped: Set<Unicode.Scalar> = [".", "'", "\u{2019}", "`"]
    private static let placeholders: Set<String> = [
        "n/a", "na", "n a", "none", "null", "nil", "unknown", "tba", "tbd", "various", "various artists", "not available",
    ]
}

/// What a title says about who is in it and who made it: names in the
/// provider's order, each person once per role.
public struct TitleCredits: Sendable, Hashable, Codable {
    public var cast: [PersonName]
    public var directors: [PersonName]

    public init(cast: [PersonName] = [], directors: [PersonName] = []) {
        self.cast = cast
        self.directors = directors
    }

    /// The provider's cast and director fields, split and cleaned.
    public init(cast: String?, director: String?) {
        self.init(cast: PersonName.split(cast), directors: PersonName.split(director))
    }

    public var isEmpty: Bool { cast.isEmpty && directors.isEmpty }

    /// How many names a title page shows (browse-by-person/pick-someone-in-the-cast).
    public static let chipLimit = 15

    /// The title page's names: the cast in order, then the directors, at
    /// most `chipLimit`. With directors, the cast stops one short so at
    /// least one director shows.
    public var chips: [CastChip] {
        let directorRoom = directors.isEmpty ? 0 : max(1, Self.chipLimit - cast.count)
        let shownDirectors = directors.prefix(min(directorRoom, Self.chipLimit))
        let shownCast = cast.prefix(Self.chipLimit - shownDirectors.count)
        return shownCast.map { CastChip(name: $0, role: .cast) } + shownDirectors.map { CastChip(name: $0, role: .director) }
    }
}

/// One selectable name on a title page.
public struct CastChip: Sendable, Hashable, Identifiable {
    public enum Role: String, Sendable, Hashable, Codable {
        case cast, director
    }

    public var name: PersonName
    public var role: Role
    public var id: String { "\(role.rawValue):\(name.key)" }

    public init(name: PersonName, role: Role) {
        self.name = name
        self.role = role
    }
}
