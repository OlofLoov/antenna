import Foundation

/// The favorites half of a catalogue, rebuilt on its own by
/// `Catalogue.replacingFavorites(_:)`.
struct CatalogueFavorites<Token: Hashable & Sendable>: Sendable {
    let snapshots: [FavoriteSnapshot<Token>]
    let rows: [RowKey]
    /// Entry index to position in `rows`.
    let rankByEntry: [Int: Int]
    let unresolved: [FavoriteSnapshot<Token>]
    let byChannelID: [String: [FavoriteSnapshot<Token>]]

    init(snapshots: [FavoriteSnapshot<Token>], index: CatalogueIndex) {
        var lowestSortOrder: [Int: Int] = [:]
        var unresolved: [FavoriteSnapshot<Token>] = []
        for snapshot in snapshots {
            let candidates = index.indicesByID[snapshot.channelID] ?? []
            let match =
                candidates
                .filter { snapshot.sourceID == nil || index.keys[$0].sourceID == snapshot.sourceID }
                .min { index.allRank[$0] < index.allRank[$1] }
            guard let match else {
                unresolved.append(snapshot)
                continue
            }
            lowestSortOrder[match] = min(lowestSortOrder[match] ?? .max, snapshot.sortOrder)
        }
        let ordered = lowestSortOrder.sorted {
            ($0.value, index.allRank[$0.key]) < ($1.value, index.allRank[$1.key])
        }
        self.snapshots = snapshots
        self.rows = ordered.map { index.keys[$0.key] }
        self.rankByEntry = Dictionary(uniqueKeysWithValues: zip(ordered.map(\.key), ordered.indices))
        self.unresolved = unresolved.sorted { ($0.sortOrder, $0.channelID) < ($1.sortOrder, $1.channelID) }
        self.byChannelID = Dictionary(grouping: snapshots, by: \.channelID)
    }

    func toRemove(for channel: Channel) -> [FavoriteSnapshot<Token>] {
        (byChannelID[channel.id] ?? []).filter { $0.sourceID == nil || $0.sourceID == channel.sourceID }
    }
}
