import Foundation

/// The loaded channels as every screen lists them: groups in display order,
/// one number per row, the All channels order, the resolved favorites, the
/// resolved recents and the New group.
///
/// Build it from every source's tagged channels, concatenated in source
/// order. Channels without a `sourceID` or `position` are left out. The same
/// input always gives the same catalogue.
public struct Catalogue<Token: Hashable & Sendable>: Sendable {
    let index: CatalogueIndex
    private let favorites: CatalogueFavorites<Token>
    private let recents: CatalogueRecents
    /// The New group, set by `NewChannels.group(_:seen:now:)`.
    private let fresh: CatalogueRecents
    /// The group rules applied; nil when there are none, so every query
    /// reads the index as it is.
    let policy: CataloguePolicy?
    /// Favorites and Recents with locked channels left out.
    private let shownFavorites: RankedRows
    private let shownRecents: RankedRows
    private let shownNew: RankedRows
    /// The groups listed, worked out once per catalogue because every
    /// focus move in a channel list reads them.
    private let listed: [CatalogueGroup]
    /// Differs between any two catalogues built or replaced separately, and
    /// is the same for copies of one value. Screens compare it to tell
    /// whether a list can stay as drawn.
    public let revision: UUID

    /// - Parameters:
    ///   - channels: every source's output of `Channel.tagged(_:sourceID:)`,
    ///     concatenated. Source order is the order in which each `sourceID`
    ///     first appears.
    ///   - groupOrder: per source, its group names in provider order. A source
    ///     with no entry lists its groups in first-appearance order.
    ///   - favorites: the stored favorites, resolved or not.
    ///   - recents: the channels watched lately, newest first.
    ///   - rules: the user's group rules; the default changes nothing.
    public init(
        channels: [Channel], groupOrder: [UUID: [String]], favorites: [FavoriteSnapshot<Token>], recents: [LastChannelKey] = [],
        rules: GroupRules = GroupRules()
    ) {
        let index = CatalogueIndex(channels: channels, groupOrder: groupOrder)
        self.init(
            index: index, favorites: CatalogueFavorites(snapshots: favorites, index: index),
            recents: recents.isEmpty ? .empty : CatalogueRecents(entries: recents, index: index), fresh: .empty,
            policy: rules.isEmpty ? nil : CataloguePolicy(index: index, rules: rules))
    }

    private init(
        index: CatalogueIndex, favorites: CatalogueFavorites<Token>, recents: CatalogueRecents, fresh: CatalogueRecents,
        policy: CataloguePolicy?
    ) {
        self.index = index
        self.favorites = favorites
        self.recents = recents
        self.fresh = fresh
        self.policy = policy
        let favoriteRows = RankedRows(rows: favorites.rows, rankByEntry: favorites.rankByEntry)
        let recentRows = RankedRows(rows: recents.rows, rankByEntry: recents.rankByEntry)
        let newRows = RankedRows(rows: fresh.rows, rankByEntry: fresh.rankByEntry)
        self.shownFavorites = policy?.filter(favoriteRows, index: index) ?? favoriteRows
        self.shownRecents = policy?.filter(recentRows, index: index) ?? recentRows
        self.shownNew = policy?.filter(newRows, index: index) ?? newRows
        let top: [CatalogueGroup] =
            [.favorites] + (shownRecents.rows.isEmpty ? [] : [.recents]) + (shownNew.rows.isEmpty ? [] : [.new]) + [.all]
        if let policy {
            self.listed =
                top.filter { !policy.isHidden($0) } + policy.ordered.filter { !policy.isHidden($0) && !policy.isLocked($0) }
        } else {
            self.listed = top + index.groups
        }
        self.revision = UUID()
    }

    /// `.favorites`, `.recents` when a recent channel resolves, `.new` when a
    /// channel is new, `.all`, then
    /// each source's named groups and its Ungrouped group, sources in source
    /// order. Groups with no channels are not listed, except `.favorites`
    /// and `.all`.
    ///
    /// With group rules, the source groups and the user's own groups follow
    /// the user's order, and hidden groups and groups locked now are left
    /// out. A hidden `.all` is left out too.
    public var groups: [CatalogueGroup] { listed }

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
    /// of their source, newest first. `.new` lists the channels first seen
    /// lately, newest first.
    ///
    /// With group rules, locked channels are left out of every group while
    /// locks are closed, channels of hidden groups are left out of `.all`,
    /// and a hidden or locked group has no rows. An `.own` group lists its
    /// loaded members in the user's order.
    public func rows(in group: CatalogueGroup) -> [RowKey] {
        if let policy, policy.isLocked(group) || (policy.isHidden(group) && group != .all) { return [] }
        switch group {
        case .favorites: return shownFavorites.rows
        case .recents: return shownRecents.rows
        case .new: return shownNew.rows
        case .all: return policy?.allRows ?? index.allRows
        case .named, .ungrouped: return (policy?.rowsByGroup ?? index.rowsByGroup)[group] ?? []
        case .own(let id): return policy?.ownRanked(id, index: index).rows ?? []
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
    /// Nil too for a locked channel while locks are closed.
    public func number(for key: RowKey) -> Int? {
        guard let entry = index.entry(for: key), policy?.blocked[entry] != true else { return nil }
        return index.numbers[entry]
    }

    /// The number to show for `key`, with the provider's part after the dot
    /// when it has one (channel-catalogue/numbers-with-a-part-after-the-dot).
    /// Nil where `number(for:)` is nil.
    public func channelNumber(for key: RowKey) -> ChannelNumber? {
        guard let major = number(for: key), let entry = index.entry(for: key) else { return nil }
        return ChannelNumber(major: major, minor: index.minors[entry])
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
        if let policy, policy.blocked[entry] || policy.isLocked(group) || (policy.isHidden(group) && group != .all) { return nil }
        let rank: Int?
        switch group {
        case .favorites: rank = shownFavorites.rankByEntry[entry]
        case .recents: rank = shownRecents.rankByEntry[entry]
        case .new: rank = shownNew.rankByEntry[entry]
        case .all:
            let ranked = policy.map { $0.allRank[entry] } ?? index.allRank[entry]
            rank = ranked < 0 ? nil : ranked
        case .named, .ungrouped:
            guard index.entryGroup[entry] == group else { return nil }
            rank = policy?.rowsByGroup == nil ? index.groupRank[entry] : policy?.groupRank[entry]
        case .own(let id): rank = policy?.ownRanked(id, index: index).rankByEntry[entry]
        }
        return rank.map { ($0 + 1, count(of: group)) }
    }

    /// The row whose assigned number is the lowest that starts with `digits`,
    /// leading zeros ignored, ties going to source order then position. Nil
    /// when `digits` is empty, all zeros, has a character other than 0-9, or
    /// nothing matches. Searches All channels whatever group is on screen,
    /// so hidden and locked channels never match while left out of it.
    public func match(digits: String) -> RowKey? {
        guard let policy else { return index.match(digits: digits) }
        return CatalogueIndex.match(digits: digits, sortedNumbers: policy.sortedNumbers, rows: policy.allRows)
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
        Catalogue(
            index: index, favorites: CatalogueFavorites(snapshots: favorites, index: index), recents: recents, fresh: fresh,
            policy: policy)
    }

    /// This catalogue with `recents`, newest first, in place of the current
    /// ones. Groups, rows and numbers outside `.recents` stay as they are,
    /// and the channels are not indexed again.
    public func replacingRecents(_ recents: [LastChannelKey]) -> Catalogue {
        Catalogue(
            index: index, favorites: favorites, recents: CatalogueRecents(entries: recents, index: index), fresh: fresh, policy: policy)
    }

    /// This catalogue with `fresh` as its New group, built by
    /// `NewChannels.group(_:seen:now:)`. The channels are not indexed again
    /// (channel-catalogue/recents-replaced-without-rebuild is the model).
    func replacingNew(_ fresh: CatalogueRecents) -> Catalogue {
        Catalogue(index: index, favorites: favorites, recents: recents, fresh: fresh, policy: policy)
    }

    /// This catalogue with `rules` in place of the current group rules.
    /// The channels are not indexed again.
    public func replacingRules(_ rules: GroupRules) -> Catalogue {
        let policy = rules.isEmpty ? nil : CataloguePolicy(index: index, rules: rules)
        return Catalogue(index: index, favorites: favorites, recents: recents, fresh: fresh, policy: policy)
    }
}
