import Foundation

/// What the Top Shelf shows for a snapshot: rows of tiles, the single
/// add-favorites tile, or nothing (top-shelf capability).
public enum TopShelfContent: Sendable, Hashable {
    case sections([Section])
    case empty(Item)

    /// A shelf row.
    public struct Section: Sendable, Hashable, Identifiable {
        public enum Kind: String, Sendable, Hashable {
            case favorites, continueWatching
        }

        public var kind: Kind
        public var items: [Item]

        public var id: String { "topShelf.section.\(kind.rawValue)" }

        public var title: String { title(.autoupdatingCurrent) }

        public func title(_ locale: Locale) -> String {
            let words = Words(locale)
            return switch kind {
            case .favorites: words("Favorites")
            case .continueWatching: words("Continue watching")
            }
        }
    }

    /// A tile.
    public struct Item: Sendable, Hashable, Identifiable {
        /// "topShelf.item.<item id>", or "topShelf.emptyItem".
        public var id: String
        public var title: String
        /// The tile image, relative to the shelf folder.
        public var tileFile: String
        /// How far into the programme, or how far the user got, 0 to 1. Nil
        /// draws no bar.
        public var progress: Double?
        public var link: TopShelfLink
    }

    /// The add-favorites tile's text.
    public static func emptyTitle(_ locale: Locale = .autoupdatingCurrent) -> String {
        Words(locale)("Add favorites in Antuna to see them here")
    }

    /// The shelf for `snapshot` at `now`. Nil, a blank shelf, when there is
    /// no readable snapshot, or when favorites are still loading and nothing
    /// else shows. A row with no tiles is left out; with no rows at all the
    /// add-favorites tile shows.
    public static func make(from snapshot: TopShelfSnapshot?, now: Date, locale: Locale = .autoupdatingCurrent) -> TopShelfContent? {
        guard let snapshot else { return nil }
        let favorites = snapshot.favorites.prefix(TopShelfSnapshot.favoriteLimit).map { favorite($0, now: now, locale: locale) }
        let titles = snapshot.titles.prefix(TopShelfSnapshot.titleLimit).map { title($0, locale: locale) }
        let sections = [
            Section(kind: .favorites, items: Array(favorites)),
            Section(kind: .continueWatching, items: Array(titles)),
        ].filter { !$0.items.isEmpty }
        if !sections.isEmpty { return .sections(sections) }
        if snapshot.unresolvedFavorites > 0 { return nil }
        return .empty(
            Item(id: "topShelf.emptyItem", title: emptyTitle(locale), tileFile: TopShelfSnapshot.emptyTileFile, progress: nil, link: .empty)
        )
    }

    /// "<channel> · <programme>" with the share of the programme gone by,
    /// or the channel alone when no programme airs at `now`
    /// (top-shelf/favorites-show-what-is-on-now, top-shelf/a-channel-with-no-guide-left-shows-its-name).
    private static func favorite(_ favorite: TopShelfSnapshot.Favorite, now: Date, locale: Locale) -> Item {
        let airing = favorite.programmes.first { $0.start <= now && now < $0.stop }
        let title = airing.map { [favorite.name, $0.title].joinedAsDetail(locale) } ?? favorite.name
        let progress = airing.map { min(max(now.timeIntervalSince($0.start) / $0.stop.timeIntervalSince($0.start), 0), 1) }
        return Item(
            id: "topShelf.item.\(favorite.itemID.uuidString.lowercased())", title: title, tileFile: favorite.tileFile, progress: progress,
            link: .item(favorite.itemID))
    }

    /// The title, with "S2 E4" for an episode, and how far the user got
    /// (top-shelf/continue-watching-shows-titles-in-progress).
    private static func title(_ title: TopShelfSnapshot.Title, locale: Locale) -> Item {
        let text = title.detail.map { [title.title, $0].joinedAsDetail(locale) } ?? title.title
        return Item(
            id: "topShelf.item.\(title.itemID.uuidString.lowercased())", title: text, tileFile: title.tileFile,
            progress: min(max(title.progress, 0), 1), link: .item(title.itemID))
    }
}
