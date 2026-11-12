#if os(tvOS)
    import AntennaCore
    import CoreGraphics
    import Foundation
    import ImageIO
    import TVServices
    import os

    /// What the shelf is written from, gathered on the main actor for the
    /// current profile (top-shelf/the-shelf-shows-the-current-profile).
    struct TopShelfInputs {
        /// Favorite channels in the catalogue's order.
        var favorites: [Channel]
        /// Favorites whose source is still loading or waiting for its login.
        var unresolvedFavorites: Int
        /// Continue watching, most recent first, with "S2 E4" for an episode once known.
        var titles: [TopShelfSnapshot.TitleInput]
        /// True while any source is loading. Nothing is written until it is false.
        var loading: Bool
    }

    /// Writes the Top Shelf snapshot and tiles for the extension
    /// (top-shelf/the-shelf-keeps-up-with-the-app). Changes batch into one
    /// write 30 seconds after the first, a later change does not push the
    /// write back, and leaving the app writes at once. It never fetches:
    /// artwork comes from what the app has cached.
    @MainActor
    final class TopShelfWriter {
        struct Dependencies {
            /// Nil when the shared folder is unavailable; nothing is written then.
            var store: (any TopShelfStoring)?
            var sleep: @MainActor (Duration) async throws -> Void
            var now: @MainActor () -> Date
            /// Programmes for each channel in the interval, in the channels' order.
            var programmes: @MainActor ([Channel], DateInterval) -> [[Programme]]
            /// A cached channel logo; nil without fetching when there is none.
            var logo: @Sendable (URL) async -> CGImage?
            /// A cached poster; nil without fetching when there is none.
            var poster: @Sendable (URL) async -> CGImage?
            /// Tells the system the shelf changed.
            var contentChanged: @MainActor () -> Void
        }

        static let batchWindow = Duration.seconds(30)
        static let refreshInterval = Duration.seconds(6 * 60 * 60)
        static let logger = Logger(subsystem: "se.codecrave.antenna", category: "topShelf")

        private let dependencies: Dependencies
        private var inputs: TopShelfInputs?
        private var window: Task<Void, Never>?
        /// Writes that reached the store, for tests.
        private(set) var written = 0

        init(_ dependencies: Dependencies) {
            self.dependencies = dependencies
        }

        /// Keeps `inputs` as the latest and starts the batch window. A write
        /// due while a source loads waits for the next change.
        func update(_ inputs: TopShelfInputs) {
            self.inputs = inputs
            trigger()
        }

        /// Starts the batch window unless one is running.
        func trigger() {
            guard window == nil else { return }
            window = Task { [weak self, sleep = dependencies.sleep] in
                do {
                    try await sleep(Self.batchWindow)
                } catch {
                    return
                }
                guard let self, !Task.isCancelled else { return }
                window = nil
                await write()
            }
        }

        /// Writes now, as when the app goes to the background.
        func flush() async {
            window?.cancel()
            window = nil
            await write()
        }

        /// Starts the batch window every six hours while the app is open,
        /// so the guide in the snapshot does not run out. Returns when cancelled.
        func refreshPeriodically() async {
            while !Task.isCancelled {
                do {
                    try await dependencies.sleep(Self.refreshInterval)
                } catch {
                    return
                }
                trigger()
            }
        }

        /// Writes the latest inputs unless a source is loading. A failed
        /// write leaves the previous shelf and is logged by case name.
        private func write() async {
            guard let inputs, !inputs.loading, let store = dependencies.store else { return }
            let now = dependencies.now()
            let guide = dependencies.programmes(inputs.favorites, DateInterval(start: now, duration: TopShelfSnapshot.guideWindow))
            let favorites = zip(inputs.favorites, guide + Array(repeating: [], count: max(inputs.favorites.count - guide.count, 0)))
                .map { TopShelfSnapshot.FavoriteInput(channel: $0, programmes: $1) }
            let snapshot = TopShelfSnapshot(
                favorites: favorites, titles: inputs.titles, unresolvedFavorites: inputs.unresolvedFavorites, now: now)
            let sources = Self.artSources(snapshot: snapshot, inputs: inputs)
            let result = await Self.store(snapshot, art: sources, in: store, logo: dependencies.logo, poster: dependencies.poster)
            switch result {
            case .success:
                written += 1
                dependencies.contentChanged()
            case .failure(let failure):
                Self.logger.error("Top Shelf write failed: \(String(describing: failure), privacy: .public)")
            }
        }

        /// Writes the cleared snapshot, which shows the add-favorites tile, as
        /// when the unlock lapses (top-shelf/an-empty-shelf-says-how-to-fill-it).
        static func clear(_ store: (any TopShelfStoring)?, now: Date, contentChanged: @MainActor () -> Void) async {
            guard let store else { return }
            let result = await Self.store(.cleared(now: now), art: [:], in: store, logo: { _ in nil }, poster: { _ in nil })
            if case .failure(let failure) = result {
                logger.error("Top Shelf clear failed: \(String(describing: failure), privacy: .public)")
            } else {
                contentChanged()
            }
        }

        /// Where each tile's artwork comes from, by tile file.
        enum ArtSource: Sendable {
            case logo(URL?, name: String)
            case poster(URL?, name: String)
        }

        private static func artSources(snapshot: TopShelfSnapshot, inputs: TopShelfInputs) -> [String: ArtSource] {
            var channels: [UUID: Channel] = [:]
            for channel in inputs.favorites {
                if let id = TopShelfItemID.channel(channel) { channels[id] = channel }
            }
            let titles = Dictionary(
                inputs.titles.map { (TopShelfItemID.title($0.item.title), $0.item.title) }, uniquingKeysWith: { first, _ in first })
            var sources: [String: ArtSource] = [:]
            for favorite in snapshot.favorites {
                sources[favorite.tileFile] = .logo(channels[favorite.itemID]?.logoURL, name: favorite.name)
            }
            for title in snapshot.titles {
                sources[title.tileFile] = .poster(titles[title.itemID]?.posterURL, name: title.title)
            }
            return sources
        }

        /// Draws the tiles and writes everything off the main actor.
        nonisolated private static func store(
            _ snapshot: TopShelfSnapshot, art: [String: ArtSource], in store: any TopShelfStoring,
            logo: @Sendable (URL) async -> CGImage?, poster: @Sendable (URL) async -> CGImage?
        ) async -> Result<Void, TopShelfFolder.Failure> {
            var tiles: [String: Data] = [:]
            for (file, source) in art {
                let picture: TopShelfTiles.Art
                switch source {
                case .logo(let url, let name):
                    let image = if let url { await logo(url) } else { CGImage?.none }
                    picture = image.map(TopShelfTiles.Art.logo) ?? .initials(Channel.initials(for: name))
                case .poster(let url, let name):
                    let image = if let url { await poster(url) } else { CGImage?.none }
                    picture = image.map(TopShelfTiles.Art.poster) ?? .text(name)
                }
                if let data = TopShelfTiles.png(picture) { tiles[file] = data }
            }
            if let empty = TopShelfTiles.png(.empty) { tiles[TopShelfSnapshot.emptyTileFile] = empty }
            do {
                let data = try snapshot.encoded()
                try store.write(snapshot: data, tiles: tiles)
                return .success(())
            } catch let failure as TopShelfFolder.Failure {
                return .failure(failure)
            } catch {
                return .failure(.writeFailed)
            }
        }
    }

    extension TopShelfWriter.Dependencies {
        /// The app's writer: the App Group folder, the app's guide, the
        /// browser's cache for logos and the poster cache.
        @MainActor
        static func app(guide: AppGuideStore?) -> Self {
            Self(
                store: TopShelfFolder.shared(),
                sleep: { try await Task.sleep(for: $0) },
                now: { .now },
                programmes: { channels, interval in
                    guard let guide else { return channels.map { _ in [] } }
                    let keys = channels.map(guide.key(for:))
                    let found = guide.programmes(for: keys.compactMap(\.self), in: interval)
                    return keys.map { key in key.flatMap { found[$0] } ?? [] }
                },
                logo: { url in
                    // AsyncImage loads logos through the shared URL cache; this reads it without a request.
                    guard let data = URLCache.shared.cachedResponse(for: URLRequest(url: url))?.data,
                        let source = CGImageSourceCreateWithData(data as CFData, nil)
                    else { return nil }
                    return CGImageSourceCreateImageAtIndex(source, 0, nil)
                },
                poster: { url in await PosterCache.shared.cached(for: url)?.image },
                contentChanged: { TVTopShelfContentProvider.topShelfContentDidChange() })
        }
    }
#endif
