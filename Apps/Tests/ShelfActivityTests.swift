import AntennaCore
import Foundation
import SwiftData
import Testing

@testable import Antenna

/// My list and Continue watching as the Movies and Series sections read
/// them, against an in-memory store and a scripted library.
@MainActor
@Suite struct ShelfActivityTests {
    let container: ModelContainer
    let source = UUID(uuidString: "00000000-0000-0000-0000-00000000AA01") ?? UUID()
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    init() throws {
        let schema = Schema(AntennaSchema.models)
        container = try ModelContainer(
            for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none))
    }

    private var store: ActivityStore { ActivityStore(context: container.mainContext) }

    private func movie(_ number: Int) -> ShelfTitle {
        ShelfTitle(id: "xtream#h#vod#\(number)", kind: .movie, sourceID: source, name: "Movie \(number)", category: "Drama")
    }

    private func series(_ number: Int) -> ShelfTitle {
        ShelfTitle(id: "xtream#h#series#\(number)", kind: .series, sourceID: source, name: "Series \(number)", category: "Drama")
    }

    /// A library whose one source answers with movies 1 to 3, series 1, and
    /// two episodes for every series.
    private func library() async -> ShelfLibrary {
        let titles = (movies: (1...3).map(movie), series: [series(1)])
        let dependencies = ShelfModel.Dependencies(
            load: { _, kind in
                ShelfCatalogue(titles: kind == .movie ? titles.movies : titles.series, categories: ["Drama"])
            },
            hasLogin: { _ in true },
            details: { _, _ in ShelfDetails() },
            episodes: { _, series in
                (1...2).map { Episode(id: "\(series.id)-e\($0)", episodeID: $0, season: 1, number: $0, title: "E\($0)") }
            })
        let library = ShelfLibrary(movies: ShelfModel(kind: .movie, dependencies), series: ShelfModel(kind: .series, dependencies))
        library.sourcesChanged([SourceDescriptor(id: source, name: "Cabin", kind: .xtream, url: URL(fileURLWithPath: "/cabin"))])
        library.open()
        await library.movies.settled()
        await library.series.settled()
        return library
    }

    /// Follows `store` in the background and waits for the first read.
    private func following() async -> (ShelfActivity, Task<Void, Never>) {
        let activity = ShelfActivity()
        let store = store
        let task = Task { [container] in
            // The container outlives the follow loop.
            await activity.follow(store)
            withExtendedLifetime(container) {}
        }
        await Task.yield()
        return (activity, task)
    }

    @Test("movies-and-series-browsing/keep-a-list-for-later adding and removing turns the button and fills the row, latest first")
    func myList() async {
        let library = await library()
        let (activity, task) = await following()
        defer { task.cancel() }
        activity.toggleMyList(movie(1))
        #expect(activity.isOnMyList(movie(1)))
        // The test host's clock stands still, so the order is set by hand.
        store.addToMyList(movie(2).id, source: source, now: .distantFuture)
        activity.reload()
        #expect(activity.myList(library.movies).map(\.id) == ["xtream#h#vod#2", "xtream#h#vod#1"])
        activity.toggleMyList(movie(1))
        #expect(!activity.isOnMyList(movie(1)))
        #expect(activity.myList(library.movies).map(\.id) == ["xtream#h#vod#2"])
        #expect(activity.myList(library.series).isEmpty, "the current kind only")
    }

    @Test("movies-and-series-browsing/keep-a-list-for-later a change on another device shows without reopening")
    func otherDevice() async throws {
        let library = await library()
        let (activity, task) = await following()
        defer { task.cancel() }
        let elsewhere = ModelContext(container)
        elsewhere.insert(ListEntryRecord(titleID: movie(3).id, sourceID: source, addedAt: now, profileID: nil))
        try elsewhere.save()
        for _ in 0..<50 where activity.myList(library.movies).isEmpty {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(activity.myList(library.movies).map(\.id) == [movie(3).id])
    }

    @Test("movies-and-series-browsing/keep-a-list-for-later an entry for a title not loaded is not shown and kept")
    func notLoaded() async {
        let library = await library()
        store.addToMyList("xtream#h#vod#99", source: source, now: now)
        let (activity, task) = await following()
        defer { task.cancel() }
        #expect(activity.myList(library.movies).isEmpty)
        #expect(store.isOnMyList("xtream#h#vod#99", source: source))
    }

    @Test("movies-and-series-browsing/continue-watching saved positions fill the row; a finished series leaves once its episodes are known")
    func continueWatching() async throws {
        let library = await library()
        store.saveProgress(titleID: movie(1).id, source: source, position: 40, duration: 100, now: now)
        store.saveProgress(titleID: movie(2).id, source: source, position: 99, duration: 100, now: now.addingTimeInterval(1))
        store.saveProgress(
            titleID: "\(series(1).id)-e1", seriesID: series(1).id, source: source, position: 99, duration: 100,
            now: now.addingTimeInterval(2))
        let (activity, task) = await following()
        defer { task.cancel() }
        let items = activity.continueWatching(library)
        #expect(items.map(\.id) == [series(1).id, movie(1).id], "most recent first, the finished movie gone")
        #expect(items.first?.isNextEpisode == true)

        store.saveProgress(
            titleID: "\(series(1).id)-e2", seriesID: series(1).id, source: source, position: 98, duration: 100,
            now: now.addingTimeInterval(3))
        activity.reload()
        #expect(activity.continueWatching(library).map(\.id) == [series(1).id, movie(1).id], "Next episode until the list is known")
        _ = try await library.series.loadEpisodes(series(1))
        #expect(activity.continueWatching(library).map(\.id) == [movie(1).id])
    }
}
