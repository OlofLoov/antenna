import Foundation

/// The loaded channels as every screen lists them: groups in display order,
/// one number per row, the All channels order, the resolved favorites and
/// the resolved recents.
///
/// Build it from every source's tagged channels, concatenated in source
/// order. Channels without a `sourceID` or `position` are left out. The same
/// input always gives the same catalogue.
public struct Catalogue<Token: Hashable & Sendable>: Sendable {
    private let index: CatalogueIndex
    private let favorites: CatalogueFavorites<Token>
    private let recents: CatalogueRecents

    /// - Parameters:
    ///   - channels: every source's output of `Channel.tagged(_:sourceID:)`,
    ///     concatenated. Source order is the order in which each `sourceID`
    ///     first appears.
    ///   - groupOrder: per source, its group names in provider order. A source
    ///     with no entry lists its groups in first-appearance order.
    ///   - favorites: the stored favorites, resolved or not.
    ///   - recents: the channels watched lately, newest first.
    public init(
        channels: [Channel], groupOrder: [UUID: [String]], favorites: [FavoriteSnapshot<Token>], recents: [LastChannelKey] = []
    ) {
        let index = CatalogueIndex(channels: channels, groupOrder: groupOrder)
        self.index = index
        self.favorites = CatalogueFavorites(snapshots: favorites, index: index)
        self.recents = recents.isEmpty ? .empty : CatalogueRecents(entries: recents, index: index)
    }

    private init(index: CatalogueIndex, favorites: CatalogueFavorites<Token>, recents: CatalogueRecents) {
        self.index = index
        self.favorites = favorites
        self.recents = recents
    }

    /// `.favorites`, `.recents` when a recent channel resolves, `.all`, then
    /// each source's named groups and its Ungrouped group, sources in source
    /// order. Groups with no channels are not listed, except `.favorites`
    /// and `.all`.
    public var groups: [CatalogueGroup] {
        (recents.rows.isEmpty ? [.favorites, .all] : [.favorites, .recents, .all]) + index.groups
    }

    /// The number of rows `rows(in:)` returns; 0 for a group not in `groups`.
    public func count(of group: CatalogueGroup) -> Int {
        rows(in: group).count
    }

    /// The rows of `group` in display order; empty for a group not in `groups`.
    ///
    /// `.all` sorts by assigned number, then source order, then position.
    /// A source's group sorts by assigned number, then position. `.favorites`
    /// sorts by `sortOrder`, then All channels order, one row per channel.
    /// `.recents` lists the recents that match exactly one loaded channel
    /// of their source, newest first.
    public func rows(in group: CatalogueGroup) -> [RowKey] {
        switch group {
        case .favorites: favorites.rows
        case .recents: recents.rows
        case .all: index.allRows
        case .named, .ungrouped: index.rowsByGroup[group] ?? []
        }
    }

    /// The channel with exactly `key`. Failing that, the one loaded channel
    /// with `key`'s `sourceID` and `id`, if there is exactly one; otherwise nil.
    public func channel(for key: RowKey) -> Channel? {
        if let entry = index.entry(for: key) { return index.channels[entry] }
        let sameSource = (index.indicesByID[key.id] ?? []).filter { index.keys[$0].sourceID == key.sourceID }
        return sameSource.count == 1 ? index.channels[sameSource[0]] : nil
    }

    /// The number to show for `key`: the provider's when it is within
    /// 1...99 999, otherwise one above the highest such number, counted in
    /// source order then position. Nil for a key not in the catalogue.
    public func number(for key: RowKey) -> Int? {
        index.entry(for: key).map { index.numbers[$0] }
    }

    /// The source group `channel` belongs to, `.named` when its group has a
    /// non-whitespace character and `.ungrouped` otherwise. Nil when the
    /// channel has no `sourceID`.
    public func sourceGroup(of channel: Channel) -> CatalogueGroup? {
        channel.sourceID.map { CatalogueIndex.group(sourceID: $0, name: channel.group) }
    }

    /// The 1-based position of `key` in `rows(in: group)` and that group's
    /// count, or nil when the group does not list `key`.
    public func position(of key: RowKey, in group: CatalogueGroup) -> (Int, Int)? {
        guard let entry = index.entry(for: key) else { return nil }
        let rank: Int?
        switch group {
        case .favorites: rank = favorites.rankByEntry[entry]
        case .recents: rank = recents.rankByEntry[entry]
        case .all: rank = index.allRank[entry]
        case .named, .ungrouped: rank = index.entryGroup[entry] == group ? index.groupRank[entry] : nil
        }
        return rank.map { ($0 + 1, count(of: group)) }
    }

    /// The row whose assigned number is the lowest that starts with `digits`,
    /// leading zeros ignored, ties going to source order then position. Nil
    /// when `digits` is empty, all zeros, has a character other than 0-9, or
    /// nothing matches. Searches All channels whatever group is on screen.
    public func match(digits: String) -> RowKey? {
        index.match(digits: digits)
    }

    /// True when `favoritesToRemove(for: channel)` is non-empty.
    public func isFavorite(_ channel: Channel) -> Bool {
        !favorites.toRemove(for: channel).isEmpty
    }

    /// Every snapshot with `channel`'s id whose `sourceID` is nil or equals
    /// the channel's. Deleting these records unfavorites the channel.
    public func favoritesToRemove(for channel: Channel) -> [FavoriteSnapshot<Token>] {
        favorites.toRemove(for: channel)
    }

    /// The snapshot to store to favorite `channel`, bound to its source and
    /// placed after every existing favorite. Nil when the channel is already
    /// a favorite or has no `sourceID`.
    public func addFavorite(_ channel: Channel) -> FavoriteSnapshot<Token>? {
        guard let sourceID = channel.sourceID, !isFavorite(channel) else { return nil }
        let next = (favorites.snapshots.map(\.sortOrder).max() ?? -1) + 1
        return FavoriteSnapshot(channelID: channel.id, sourceID: sourceID, sortOrder: next)
    }

    /// Snapshots that match no loaded channel, by `sortOrder` then `channelID`.
    public var unresolvedFavorites: [FavoriteSnapshot<Token>] { favorites.unresolved }

    /// This catalogue with `favorites` in place of the current snapshots.
    /// Groups, rows and numbers outside `.favorites` stay as they are, and
    /// the channels are not indexed again.
    public func replacingFavorites(_ favorites: [FavoriteSnapshot<Token>]) -> Catalogue {
        Catalogue(index: index, favorites: CatalogueFavorites(snapshots: favorites, index: index), recents: recents)
    }

    /// This catalogue with `recents`, newest first, in place of the current
    /// ones. Groups, rows and numbers outside `.recents` stay as they are,
    /// and the channels are not indexed again.
    public func replacingRecents(_ recents: [LastChannelKey]) -> Catalogue {
        Catalogue(index: index, favorites: favorites, recents: CatalogueRecents(entries: recents, index: index))
    }
}
