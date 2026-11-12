import Foundation

/// Every channel Siri and Shortcuts may name, folded once, so asking for a
/// channel only compares bytes (app-intents/ask-for-a-channel-by-name-or-number).
/// Build it again when the catalogue's channels or group rules change;
/// favorites do not matter.
///
/// Locked channels are left out while the locks are closed. Channels of
/// hidden groups stay in, so a channel can be named even when it is not
/// listed.
public struct ChannelMatcher: Sendable {
    struct Entry: Sendable {
        let key: RowKey
        /// The folded name as UTF-8, runs of whitespace made one space.
        let name: [UInt8]
        let number: Int?
        /// `number` in decimal as UTF-8, empty without one.
        let numberText: [UInt8]
        /// The entry's place when every entry is sorted by folded name,
        /// ties in All channels order.
        var nameRank = 0
    }

    /// In All channels order: number, then source order, then position.
    private let entries: [Entry]

    public init<Token>(_ catalogue: Catalogue<Token>) {
        let rows = catalogue.searchRows(includingHidden: true)
        var entries: [Entry] = []
        entries.reserveCapacity(rows.count)
        for key in rows {
            guard let channel = catalogue.channel(for: key) else { continue }
            let name = Self.collapsed(ChannelFilter.fold(channel.name))
            let number = catalogue.number(for: key)
            entries.append(
                Entry(key: key, name: Array(name.utf8), number: number, numberText: number.map { Array(String($0).utf8) } ?? []))
        }
        let byName = entries.indices.sorted { lhs, rhs in
            entries[lhs].name == entries[rhs].name ? lhs < rhs : entries[lhs].name.lexicographicallyPrecedes(entries[rhs].name)
        }
        for (rank, entry) in byName.enumerated() { entries[entry].nameRank = rank }
        self.entries = entries
    }

    /// The channels `query` names, at most `limit`.
    ///
    /// A query of digits only finds channel numbers, never names, leading
    /// zeros ignored: the channels with exactly that number when there are
    /// any, otherwise every number that starts with it, by number, then
    /// source order, then position. Any other query finds names, case and
    /// accents ignored, every word a part of the name: the channels whose
    /// whole name is the query when there are any, otherwise names that
    /// start with the query, then names with a word that starts with its
    /// first word, then the rest, each by name and then in All channels
    /// order. Group names never match. A blank query finds nothing.
    public func matches(_ query: String, limit: Int) -> [RowKey] {
        let filter = ChannelFilter(query)
        guard limit > 0, !filter.isEmpty else { return [] }
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if trimmed.allSatisfy({ $0.isASCII && $0.isNumber }) {
            guard let digits = filter.digits else { return [] }
            return numbers(digits, limit: limit)
        }
        return names(filter.tokens, limit: limit)
    }

    private func numbers(_ digits: String, limit: Int) -> [RowKey] {
        if let exact = Int(digits) {
            let same = entries.filter { $0.number == exact }
            if !same.isEmpty { return Array(same.prefix(limit).map(\.key)) }
        }
        let prefix = Array(digits.utf8)
        var found: [RowKey] = []
        for entry in entries {
            guard entry.numberText.starts(with: prefix) else { continue }
            found.append(entry.key)
            if found.count == limit { break }
        }
        return found
    }

    private func names(_ tokens: [String], limit: Int) -> [RowKey] {
        let whole = Array(tokens.joined(separator: " ").utf8)
        let needles = tokens.map { Array($0.utf8) }
        var exact: [RowKey] = []
        // Band first, then name order, folded into one number.
        var ranked: [(order: Int, entry: Int)] = []
        for (offset, entry) in entries.enumerated() where needles.allSatisfy({ Self.firstOffset(of: $0, in: entry.name) != nil }) {
            if entry.name == whole {
                exact.append(entry.key)
            } else if exact.isEmpty {
                let band = Self.band(entry.name, whole: whole, first: needles[0])
                ranked.append((band * entries.count + entry.nameRank, offset))
            }
        }
        if !exact.isEmpty { return Array(exact.prefix(limit)) }
        ranked.sort { $0.order < $1.order }
        return ranked.prefix(limit).map { entries[$0.entry].key }
    }

    /// `name` trimmed, with runs of whitespace made one space.
    private static func collapsed(_ name: String) -> String {
        name.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// 0 when `name` starts with the whole query, 1 when one of its words
    /// starts with the first word, 2 otherwise, as Search ranks names.
    private static func band(_ name: [UInt8], whole: [UInt8], first: [UInt8]) -> Int {
        if name.starts(with: whole) { return 0 }
        var from = 0
        while let found = firstOffset(of: first, in: name, from: from) {
            if found == 0 || !isWordByte(name[found - 1]) { return 1 }
            from = found + 1
        }
        return 2
    }

    /// Letters and digits, including every byte of a character beyond ASCII.
    private static func isWordByte(_ byte: UInt8) -> Bool {
        byte >= 0x80 || (byte >= 0x30 && byte <= 0x39) || (byte >= 0x41 && byte <= 0x5A) || (byte >= 0x61 && byte <= 0x7A)
    }

    /// Where `needle` first occurs in `haystack` at or after `from`.
    private static func firstOffset(of needle: [UInt8], in haystack: [UInt8], from: Int = 0) -> Int? {
        guard let head = needle.first, needle.count <= haystack.count else { return needle.isEmpty ? from : nil }
        let last = haystack.count - needle.count
        var start = from
        while start <= last {
            if haystack[start] == head {
                var offset = 1
                while offset < needle.count, haystack[start + offset] == needle[offset] { offset += 1 }
                if offset == needle.count { return start }
            }
            start += 1
        }
        return nil
    }
}

extension Catalogue {
    /// The channels `query` names, at most `limit`, as `ChannelMatcher`
    /// finds them. Builds the matcher each call; keep a `ChannelMatcher`
    /// to answer many queries.
    public func channels(matching query: String, limit: Int) -> [RowKey] {
        ChannelMatcher(self).matches(query, limit: limit)
    }
}
