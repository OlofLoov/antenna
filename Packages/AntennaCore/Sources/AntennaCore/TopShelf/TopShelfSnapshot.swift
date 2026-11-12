import Foundation

/// What the app hands the Top Shelf extension: favorites with the next
/// hours of guide, and titles in progress. It holds names, programme
/// titles, times, progress and tile file names, never a link, channel or
/// title id, username or password (top-shelf/no-passwords-or-links-leave-the-app).
public struct TopShelfSnapshot: Codable, Sendable, Hashable {
    /// The format this build writes and reads. A snapshot of any other
    /// version reads as no snapshot.
    public static let currentVersion = 1
    /// At most this many favorites, in catalogue order.
    public static let favoriteLimit = 20
    /// At most this many titles, most recent first.
    public static let titleLimit = 10
    /// Programmes overlapping now to now plus this many seconds are kept.
    public static let guideWindow: TimeInterval = 12 * 60 * 60
    /// The encoded snapshot stays under this many bytes.
    public static let byteLimit = 256 * 1024

    /// A favorite channel's tile.
    public struct Favorite: Codable, Sendable, Hashable {
        public var itemID: UUID
        public var name: String
        /// The tile image, relative to the shelf folder.
        public var tileFile: String
        /// Start order, none ending at or before the time of writing.
        public var programmes: [Programme]
    }

    /// A programme as the shelf shows it.
    public struct Programme: Codable, Sendable, Hashable {
        public var title: String
        public var start: Date
        public var stop: Date
    }

    /// A movie or series in progress.
    public struct Title: Codable, Sendable, Hashable {
        public var itemID: UUID
        public var title: String
        /// "S2 E4" for an episode; nil for a movie.
        public var detail: String?
        public var tileFile: String
        /// How far the user got, 0 to 1.
        public var progress: Double
        public var updatedAt: Date
    }

    public var version: Int
    public var writtenAt: Date
    public var favorites: [Favorite]
    public var titles: [Title]
    /// Favorites left out because their source has not loaded or its login
    /// has not reached this device. While above zero an empty snapshot
    /// shows a blank shelf, not the add-favorites tile.
    public var unresolvedFavorites: Int

    /// The empty snapshot written when the unlock lapses: the shelf shows
    /// the add-favorites tile.
    public static func cleared(now: Date) -> TopShelfSnapshot {
        TopShelfSnapshot(version: currentVersion, writtenAt: now, favorites: [], titles: [], unresolvedFavorites: 0)
    }

    /// The tile file of an item.
    public static func tileFile(_ itemID: UUID) -> String {
        "tiles/\(itemID.uuidString.lowercased()).png"
    }

    /// The tile file of the add-favorites tile.
    public static let emptyTileFile = "empty.png"
}

extension TopShelfSnapshot {
    /// A favorite channel and its guide, as the app knows them.
    public struct FavoriteInput: Sendable {
        public var channel: Channel
        public var programmes: [AntennaCore.Programme]

        public init(channel: Channel, programmes: [AntennaCore.Programme]) {
            self.channel = channel
            self.programmes = programmes
        }
    }

    /// A Continue watching item and its "S2 E4" when it is an episode.
    public struct TitleInput: Sendable {
        public var item: ContinueWatching.Item
        public var detail: String?

        public init(item: ContinueWatching.Item, detail: String?) {
            self.item = item
            self.detail = detail
        }
    }

    /// The snapshot for `favorites` in catalogue order and `titles` most
    /// recent first: at most 20 favorites with programmes overlapping the
    /// next 12 hours, and at most 10 titles in progress. A channel with no
    /// source and a series offered as "Next episode" are left out.
    public init(favorites: [FavoriteInput], titles: [TitleInput], unresolvedFavorites: Int, now: Date) {
        let end = now.addingTimeInterval(Self.guideWindow)
        let favorites = favorites.compactMap { input -> Favorite? in
            guard let itemID = TopShelfItemID.channel(input.channel) else { return nil }
            let programmes =
                input.programmes
                .filter { $0.stop > now && $0.start < end && $0.start < $0.stop }
                .sorted { $0.start < $1.start }
                .map { Programme(title: $0.title, start: $0.start, stop: $0.stop) }
            return Favorite(itemID: itemID, name: input.channel.name, tileFile: Self.tileFile(itemID), programmes: programmes)
        }
        let titles =
            titles
            .filter { !$0.item.isNextEpisode && $0.item.progress.state == .inProgress }
            .sorted { WatchProgress.newestFirst($0.item.progress, $1.item.progress) }
            .compactMap { input -> Title? in
                guard let length = input.item.progress.knownDuration else { return nil }
                let itemID = TopShelfItemID.title(input.item.title)
                return Title(
                    itemID: itemID, title: input.item.title.name, detail: input.detail, tileFile: Self.tileFile(itemID),
                    progress: min(max(input.item.progress.position / length, 0), 1), updatedAt: input.item.progress.updatedAt)
            }
        self.init(
            version: Self.currentVersion, writtenAt: now, favorites: Array(favorites.prefix(Self.favoriteLimit)),
            titles: Array(titles.prefix(Self.titleLimit)), unresolvedFavorites: max(unresolvedFavorites, 0))
    }

    /// The snapshot as JSON under `byteLimit`, dropping the latest
    /// programmes of every favorite until it fits.
    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        var trimmed = self
        var data = try encoder.encode(trimmed)
        var keep = favorites.map(\.programmes.count).max() ?? 0
        while data.count >= Self.byteLimit, keep > 0 {
            keep /= 2
            for index in trimmed.favorites.indices {
                trimmed.favorites[index].programmes = Array(favorites[index].programmes.prefix(keep))
            }
            data = try encoder.encode(trimmed)
        }
        return data
    }

    /// The snapshot in `data`; nil when there is none, it is damaged, or it
    /// was written in another version (top-shelf/the-shelf-keeps-up-with-the-app).
    public init?(data: Data?) {
        guard let data, data.count < Self.byteLimit,
            let snapshot = try? JSONDecoder().decode(TopShelfSnapshot.self, from: data),
            snapshot.version == Self.currentVersion
        else { return nil }
        self = snapshot
    }
}
