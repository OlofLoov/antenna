import Foundation

/// One distinct guide id across a source's turned-on, loaded guides, as the
/// picker lists it.
public struct GuideEntry: Sendable, Equatable, Identifiable {
    public var id: String
    /// The display name, or the id when no guide names it.
    public var name: String
    /// The programmes in `guide`.
    public var programmes: Int
    /// The guide whose programmes the id would show: the highest with
    /// programmes for it, else the first that lists it.
    public var guide: GuideReference
    /// That guide's place among the loaded guides, top first.
    public var position: Int

    public init(id: String, name: String, programmes: Int, guide: GuideReference, position: Int) {
        self.id = id
        self.name = name
        self.programmes = programmes
        self.guide = guide
        self.position = position
    }
}

extension GuideIndex {
    /// The display name the source's highest loaded guide gives `id`.
    public func entryName(sourceID: UUID, id: String) -> String? {
        sources[sourceID]?.layers.lazy.compactMap { $0.guide.names[id] }.first
    }

    /// Every guide id the source's turned-on, loaded guides list or have
    /// programmes for.
    public func entries(sourceID: UUID) -> [GuideEntry] {
        guard let layers = sources[sourceID]?.layers else { return [] }
        var result: [String: GuideEntry] = [:]
        for (position, layer) in layers.enumerated() {
            let guide = layer.guide
            for id in Set(guide.names.keys).union(guide.schedules.keys) {
                let count = guide.schedules[id]?.count ?? 0
                if let existing = result[id], existing.programmes > 0 || count == 0 { continue }
                result[id] = GuideEntry(
                    id: id, name: guide.names[id] ?? result[id]?.name ?? id, programmes: count, guide: layer.reference, position: position)
            }
        }
        return Array(result.values)
    }
}

/// The picker's search over guide entries
/// (guide-sources-and-channel-mapping/pick-the-right-guide-entry-by-hand),
/// folded and split into words as Search does, ranked in six bands, then by
/// name, then by guide order.
public struct GuideEntrySearch: Sendable {
    /// The most rows the picker shows.
    public static let cap = 200

    public struct Result: Sendable, Equatable {
        public var entries: [GuideEntry]
        /// Every match, shown or not.
        public var total: Int

        public init(entries: [GuideEntry], total: Int) {
            self.entries = entries
            self.total = total
        }
    }

    private struct Folded: Sendable {
        var entry: GuideEntry
        var name: String
        var words: [String]
        var id: String
    }

    private let entries: [Folded]

    public init(_ entries: [GuideEntry]) {
        self.entries = entries.map { entry in
            let name = ChannelFilter.fold(entry.name).split(whereSeparator: \.isWhitespace).joined(separator: " ")
            return Folded(
                entry: entry, name: name, words: name.split(separator: " ").map(String.init), id: ChannelFilter.fold(entry.id))
        }
    }

    /// The matches for `query`, best first, at most `cap`. An empty query
    /// finds nothing.
    public func search(_ query: String) -> Result {
        let tokens = ChannelFilter(query).tokens
        guard !tokens.isEmpty else { return Result(entries: [], total: 0) }
        let whole = tokens.joined(separator: " ")
        var ranked: [(band: Int, folded: Folded)] = []
        for folded in entries {
            guard let band = Self.band(folded, whole: whole, tokens: tokens) else { continue }
            ranked.append((band, folded))
        }
        ranked.sort { lhs, rhs in
            if lhs.band != rhs.band { return lhs.band < rhs.band }
            if lhs.folded.name != rhs.folded.name { return lhs.folded.name < rhs.folded.name }
            return lhs.folded.entry.position < rhs.folded.entry.position
        }
        return Result(entries: ranked.prefix(Self.cap).map(\.folded.entry), total: ranked.count)
    }

    /// 1 the name equals the query, 2 starts with it, 3 has it from the
    /// start of a later word, 4 contains it, 5 has every word, 6 has every
    /// word in the name or the id.
    private static func band(_ folded: Folded, whole: String, tokens: [String]) -> Int? {
        if folded.name == whole { return 1 }
        if folded.name.hasPrefix(whole) { return 2 }
        if folded.words.indices.contains(where: { folded.words[$0...].joined(separator: " ").hasPrefix(whole) }) { return 3 }
        if folded.name.contains(whole) { return 4 }
        if tokens.allSatisfy(folded.name.contains) { return 5 }
        if tokens.allSatisfy({ folded.name.contains($0) || folded.id.contains($0) }) { return 6 }
        return nil
    }
}
