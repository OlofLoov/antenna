import Foundation

/// What the user typed into a search or filter field, matched the way
/// Search matches channels: case and accents ignored, every word a part of
/// the name, or digits that start the channel's number
/// (live-tv-on-iphone-ipad-mac/type-to-narrow-the-list).
public struct ChannelFilter: Sendable, Equatable {
    /// Queries longer than this are cut.
    public static let maximumLength = 100

    /// The words to find, folded. Empty when the query is blank.
    public let tokens: [String]
    /// The query's digits with leading zeros removed, when it is only
    /// digits and not all zeros; nil otherwise.
    public let digits: String?

    /// Trims the query, collapses runs of spaces and splits it into words.
    public init(_ query: String) {
        let cut = String(query.prefix(Self.maximumLength))
        tokens = cut.split(whereSeparator: \.isWhitespace).map { Self.fold(String($0)) }
        let trimmed = cut.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty, trimmed.allSatisfy({ $0.isASCII && $0.isNumber }) {
            let stripped = trimmed.drop { $0 == "0" }
            digits = stripped.isEmpty ? nil : String(stripped)
        } else {
            digits = nil
        }
    }

    /// True when nothing was typed, so every channel passes.
    public var isEmpty: Bool { tokens.isEmpty }

    /// True when every word appears in `name`, or `number` starts with the
    /// typed digits. A blank query matches everything.
    public func matches(name: String, number: Int?) -> Bool {
        guard !tokens.isEmpty else { return true }
        if let digits, let number, String(number).hasPrefix(digits) { return true }
        let folded = Self.fold(name)
        return tokens.allSatisfy { folded.contains($0) }
    }

    static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}

/// Every channel's name folded once, so filtering a group on each
/// keystroke only compares text. Build it again when the catalogue's
/// channels change; favorites do not matter.
public struct ChannelNameIndex: Sendable {
    struct Entry: Sendable {
        let name: String
        let number: String
    }

    private let entries: [RowKey: Entry]

    public init<Token>(_ catalogue: Catalogue<Token>) {
        var entries: [RowKey: Entry] = [:]
        let rows = catalogue.searchRows(includingHidden: true)
        entries.reserveCapacity(rows.count)
        for key in rows {
            guard let channel = catalogue.channel(for: key) else { continue }
            entries[key] = Entry(name: ChannelFilter.fold(channel.name), number: catalogue.number(for: key).map(String.init) ?? "")
        }
        self.entries = entries
    }

    /// The members of `rows`, in their order, that `filter` matches by
    /// channel name or assigned number. A blank filter returns `rows`.
    public func filter(_ rows: [RowKey], by filter: ChannelFilter) -> [RowKey] {
        guard !filter.isEmpty else { return rows }
        return rows.filter { key in
            guard let entry = entries[key] else { return false }
            if let digits = filter.digits, entry.number.hasPrefix(digits) { return true }
            return filter.tokens.allSatisfy { entry.name.contains($0) }
        }
    }
}

extension Catalogue {
    /// The rows of `group` in display order that `filter` matches by
    /// channel name or assigned number. A blank filter returns the whole
    /// group. Folds every name; for repeated filtering keep a `ChannelNameIndex`.
    public func rows(in group: CatalogueGroup, matching filter: ChannelFilter) -> [RowKey] {
        ChannelNameIndex(self).filter(rows(in: group), by: filter)
    }
}
