import AntennaCore
import Foundation
import TVServices
import Testing

@testable import AntennaTV

/// The extension's sectioned content, built from what a fake store holds.
@Suite struct TopShelfItemsTests {
    let source = UUID()
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func favorite(_ name: String) -> TopShelfSnapshot.FavoriteInput {
        let channel = Channel.tagged([Channel(id: name, name: name, streamURL: URL(fileURLWithPath: "/\(name)"))], sourceID: source)[0]
        let programme = Programme(
            channelID: name, start: now.addingTimeInterval(-600), stop: now.addingTimeInterval(1800), title: "\(name) show")
        return .init(channel: channel, programmes: [programme])
    }

    private func title(_ name: String) -> TopShelfSnapshot.TitleInput {
        let title = ShelfTitle(id: "xtream#h#vod#\(name)", kind: .movie, sourceID: source, name: name)
        let progress = WatchProgress(id: name, titleID: title.id, sourceID: source, position: 60, duration: 100, updatedAt: now)
        return .init(item: .init(title: title, progress: progress, isNextEpisode: false), detail: nil)
    }

    /// A store holding `snapshot` and a tile for each item except those in `missing`.
    private func store(_ snapshot: TopShelfSnapshot, missing: Set<String> = []) throws -> FakeTopShelfStore {
        let store = FakeTopShelfStore()
        var files = [TopShelfSnapshot.emptyTileFile: Data()]
        for file in snapshot.favorites.map(\.tileFile) + snapshot.titles.map(\.tileFile) where !missing.contains(file) {
            files[file] = Data()
        }
        try store.write(snapshot: try snapshot.encoded(), tiles: files)
        return store
    }

    @Test("top-shelf/favorites-show-what-is-on-now two rows of 16:9 tiles with titles, progress and links")
    func sections() throws {
        let snapshot = TopShelfSnapshot(favorites: [favorite("Arte")], titles: [title("Dune")], unresolvedFavorites: 0, now: now)
        let content = try #require(TopShelfItems.content(from: try store(snapshot), now: now))
        #expect(content.sections.map(\.title) == ["Favorites", "Continue watching"])
        let channel = try #require(content.sections.first?.items.first)
        let itemID = try #require(snapshot.favorites.first).itemID
        #expect(channel.identifier == "topShelf.item.\(itemID.uuidString.lowercased())")
        #expect(channel.title == "Arte · Arte show")
        #expect(channel.imageShape == .hdtv)
        #expect(channel.imageURL(for: .screenScale1x) != nil)
        #expect(channel.imageURL(for: .screenScale2x) != nil)
        #expect(abs(channel.playbackProgress - 0.25) < 0.001)
        #expect(channel.playAction?.url == TopShelfLink.item(itemID).url)
        #expect(channel.displayAction?.url == TopShelfLink.item(itemID).url)
        let movie = try #require(content.sections.last?.items.first)
        #expect(movie.title == "Dune")
        #expect(abs(movie.playbackProgress - 0.6) < 0.001)
    }

    @Test("top-shelf/a-row-with-nothing-in-it-is-left-out a missing tile drops its item and an emptied row is omitted")
    func missingTiles() throws {
        let snapshot = TopShelfSnapshot(
            favorites: [favorite("Arte"), favorite("BBC")], titles: [title("Dune")], unresolvedFavorites: 0, now: now)
        let missing: Set = [snapshot.favorites[0].tileFile, snapshot.titles[0].tileFile]
        let content = try #require(TopShelfItems.content(from: try store(snapshot, missing: missing), now: now))
        #expect(content.sections.map(\.title) == ["Favorites"])
        #expect(content.sections.first?.items.map(\.title) == ["BBC · BBC show"])
    }

    @Test("top-shelf/an-empty-shelf-says-how-to-fill-it nothing to show gives the add-favorites tile, which opens Antenna")
    func emptyShelf() throws {
        let content = try #require(TopShelfItems.content(from: try store(.cleared(now: now)), now: now))
        let tile = try #require(content.sections.first?.items.first)
        #expect(content.sections.count == 1)
        #expect(tile.identifier == "topShelf.emptyItem")
        #expect(tile.title == "Add favorites in Antenna to see them here")
        #expect(tile.displayAction?.url == TopShelfLink.empty.url)
        #expect(tile.playAction == nil)
    }

    @Test("top-shelf/the-shelf-keeps-up-with-the-app no summary, or nothing with a tile, gives a blank shelf")
    func blank() throws {
        #expect(TopShelfItems.content(from: FakeTopShelfStore(), now: now) == nil)
        let snapshot = TopShelfSnapshot(favorites: [favorite("Arte")], titles: [], unresolvedFavorites: 0, now: now)
        #expect(TopShelfItems.content(from: try store(snapshot, missing: [snapshot.favorites[0].tileFile]), now: now) == nil)
        let loading = TopShelfSnapshot(favorites: [], titles: [], unresolvedFavorites: 1, now: now)
        #expect(TopShelfItems.content(from: try store(loading), now: now) == nil)
    }
}
