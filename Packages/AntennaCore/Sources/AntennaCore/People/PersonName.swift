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
        var cache = Cache()
        return split(field, cache: &cache)
    }

    /// The cleaned names of field parts already seen, so a name that many
    /// titles carry is cleaned once per index build.
    struct Cache {
        var names: [String: PersonName?] = [:]
    }

    /// `split(_:)`, reading and filling `cache`. Reads the field's bytes:
    /// every separator but the middle dot is one ASCII byte.
    static func split(_ field: String?, cache: inout Cache) -> [PersonName] {
        guard var field, !field.isEmpty else { return [] }
        // "N/A" holds a slash, so it goes before the split.
        if field.utf8.contains(UInt8(ascii: "/")) {
            field = field.replacingOccurrences(of: #"(?i)(?<!\p{L})n/a(?!\p{L})"#, with: ",", options: .regularExpression)
        }
        field.makeContiguousUTF8()
        var names: [PersonName] = []
        func add(_ part: Slice<UnsafeBufferPointer<UInt8>>) {
            let trimmed = part.drop { $0 == UInt8(ascii: " ") }
            guard !trimmed.isEmpty else { return }
            let raw = String(decoding: UnsafeBufferPointer(rebasing: trimmed), as: UTF8.self)
            let name: PersonName?
            if let known = cache.names[raw] {
                name = known
            } else {
                name = PersonName(raw)
                cache.names[raw] = name
            }
            guard let name, !names.contains(where: { $0.key == name.key }) else { return }
            names.append(name)
        }
        _ = field.utf8.withContiguousStorageIfAvailable { bytes in
            var start = 0
            var index = 0
            while index < bytes.count {
                let width = separatorWidth(bytes, at: index)
                guard width > 0 else {
                    index += 1
                    continue
                }
                add(bytes[start..<index])
                index += width
                start = index
            }
            add(bytes[start..<bytes.count])
        }
        return names
    }

    /// The bytes of the separator at `index`, 0 when none starts there.
    private static func separatorWidth(_ bytes: UnsafeBufferPointer<UInt8>, at index: Int) -> Int {
        let byte = bytes[index]
        if separatorBytes.contains(byte) { return 1 }
        // The middle dot, U+00B7.
        return byte == 0xC2 && index + 1 < bytes.count && bytes[index + 1] == 0xB7 ? 2 : 0
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
    /// Commas, slashes, vertical bars, semicolons and line breaks.
    private static let separatorBytes = Set(",/|;\n\r".utf8)
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
