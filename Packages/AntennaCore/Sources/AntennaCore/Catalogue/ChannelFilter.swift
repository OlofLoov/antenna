import Foundation
import Synchronization

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
    /// `tokens` with the bytes a byte search compares.
    let needles: [FoldedNeedle]

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
        needles = tokens.map(FoldedNeedle.init)
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
        FoldedText.fold(text)
    }
}

/// Every channel's name folded once, so filtering a group on each
/// keystroke only compares bytes. Build it again when the catalogue's
/// channels change; favorites, recents and group rules do not matter, so
/// a catalogue from `replacingRules(_:)` and the like keeps its index.
/// Building takes a while for a large catalogue, so build it off the main
/// actor; it is `Sendable`.
public struct ChannelNameIndex: Sendable {
    private let names: FoldedTexts
    /// Each entry's number as typed digits, empty for none.
    private let numbers: [String]
    private let keys: [RowKey]
    /// Per source, by position, the entry with that key, -1 for none.
    private let entriesBySource: [UUID: [Int32]]

    public init<Token>(_ catalogue: Catalogue<Token>) {
        let index = catalogue.index
        names = FoldedTexts(index.channels.map { ChannelFilter.fold($0.name) })
        numbers = index.numbers.map(String.init)
        keys = index.keys
        // Entries run in source order, so each source's table fills in one go.
        var bySource: [UUID: [Int32]] = [:]
        var source: UUID?
        var slots: [Int32] = []
        for (entry, key) in index.keys.enumerated() {
            if key.sourceID != source {
                if let source { bySource[source] = slots }
                source = key.sourceID
                slots = bySource[key.sourceID] ?? []
            }
            if slots.count <= key.position { slots += repeatElement(-1, count: key.position + 1 - slots.count) }
            slots[key.position] = Int32(entry)
        }
        if let source { bySource[source] = slots }
        entriesBySource = bySource
        // All channels is the longest list, so its rows are looked up here rather than on the first keystroke.
        let all = catalogue.rows(in: .all)
        memo = FilterMemo()
        memo.last.withLock { $0 = FilterMemo.Last(rows: all, entries: entries(of: all), filter: nil, kept: []) }
    }

    /// The index for `catalogue`, built away from the caller's actor.
    @concurrent
    public static func build<Token>(_ catalogue: Catalogue<Token>) async -> ChannelNameIndex {
        ChannelNameIndex(catalogue)
    }

    /// The last filtering, so the next keystroke on the same rows starts
    /// from it.
    private let memo: FilterMemo

    /// The members of `rows`, in their order, that `filter` matches by
    /// channel name or assigned number. A blank filter returns `rows`.
    /// `rows` come from the catalogue the index was built from.
    ///
    /// Filtering the same rows array again skips looking up its rows, and
    /// a filter that only adds to the last one tests only the rows that
    /// one kept (live-tv-on-iphone-ipad-mac/type-to-narrow-the-list).
    public func filter(_ rows: [RowKey], by filter: ChannelFilter) -> [RowKey] {
        guard !filter.isEmpty else { return rows }
        let last = memo.last.withLock { $0 }
        let entries: [Int]
        let candidates: [Int]
        if let last, last.rows.sharesStorage(with: rows) {
            entries = last.entries
            candidates = last.filter.map(filter.narrows) == true ? last.kept : Array(rows.indices)
        } else {
            entries = self.entries(of: rows)
            candidates = Array(rows.indices)
        }
        let candidateEntries = candidates.map { entries[$0] }
        var named = names.matches(candidateEntries, all: filter.needles)
        if let digits = filter.digits {
            for (slot, entry) in candidateEntries.enumerated() where entry >= 0 && !named[slot] {
                named[slot] = numbers[entry].hasPrefix(digits)
            }
        }
        var kept: [Int] = []
        for (slot, row) in candidates.enumerated() where named[slot] { kept.append(row) }
        let memo = FilterMemo.Last(rows: rows, entries: entries, filter: filter, kept: kept)
        self.memo.last.withLock { $0 = memo }
        return kept.map { rows[$0] }
    }

    /// Each row's entry, -1 for a row not in this index.
    private func entries(of rows: [RowKey]) -> [Int] {
        var entries = [Int](repeating: -1, count: rows.count)
        var source: UUID?
        var slots: [Int32] = []
        for (row, key) in rows.enumerated() {
            if key.sourceID != source {
                source = key.sourceID
                slots = entriesBySource[key.sourceID] ?? []
            }
            guard key.position >= 0, key.position < slots.count else { continue }
            let entry = Int(slots[key.position])
            // Source and position already agree; the id tells a row of another catalogue.
            guard entry >= 0, keys[entry].id == key.id else { continue }
            entries[row] = entry
        }
        return entries
    }
}

/// The last filtering of a `ChannelNameIndex`, shared by its copies.
private final class FilterMemo: Sendable {
    struct Last: Sendable {
        let rows: [RowKey]
        let entries: [Int]
        /// Nil when nothing was filtered yet and only `entries` is known.
        let filter: ChannelFilter?
        /// Positions in `rows` the filter kept.
        let kept: [Int]
    }

    let last = Mutex<Last?>(nil)
}

extension ChannelFilter {
    /// True when every row this filter matches is one `previous` matches
    /// too: each earlier word is part of a word typed now, and typed
    /// digits only grew.
    func narrows(_ previous: ChannelFilter) -> Bool {
        if let digits {
            guard let earlier = previous.digits, digits.hasPrefix(earlier) else { return false }
        }
        return previous.tokens.allSatisfy { earlier in tokens.contains { $0.contains(earlier) } }
    }
}

extension Array {
    /// True when both arrays are views of one buffer, so they hold the same elements.
    func sharesStorage(with other: [Element]) -> Bool {
        count == other.count
            && withUnsafeBufferPointer { mine in other.withUnsafeBufferPointer { $0.baseAddress == mine.baseAddress } }
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
