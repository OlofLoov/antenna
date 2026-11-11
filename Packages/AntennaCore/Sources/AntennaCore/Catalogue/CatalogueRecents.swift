import Foundation

/// The Recents half of a catalogue, rebuilt on its own by
/// `Catalogue.replacingRecents(_:)`.
struct CatalogueRecents: Sendable {
    let rows: [RowKey]
    /// Entry index to position in `rows`.
    let rankByEntry: [Int: Int]

    static let empty = CatalogueRecents(rows: [], rankByEntry: [:])

    private init(rows: [RowKey], rankByEntry: [Int: Int]) {
        self.rows = rows
        self.rankByEntry = rankByEntry
    }

    /// Each entry resolves to the one loaded channel with its source and id.
    /// An entry that matches none, or two, is left out.
    init(entries: [LastChannelKey], index: CatalogueIndex) {
        var rows: [RowKey] = []
        var rankByEntry: [Int: Int] = [:]
        for key in entries {
            let matches = (index.indicesByID[key.channelID] ?? []).filter { index.keys[$0].sourceID == key.sourceID }
            guard matches.count == 1, rankByEntry[matches[0]] == nil else { continue }
            rankByEntry[matches[0]] = rows.count
            rows.append(index.keys[matches[0]])
        }
        self.init(rows: rows, rankByEntry: rankByEntry)
    }
}
