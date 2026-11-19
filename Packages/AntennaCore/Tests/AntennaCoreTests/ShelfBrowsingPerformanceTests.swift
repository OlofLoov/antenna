import Foundation
import Testing

@testable import AntennaCore

/// What Movies and Series ask of a provider-sized library: 50 000 movies in
/// 300 categories and 10 000 series, with 200 saved positions. The budgets
/// are for a debug build on a loaded CI runner and still fail a return to
/// sorting whole titles or to walking every title on each redraw. Each
/// budget is on the fastest of a few runs.
@Suite struct ShelfBrowsingPerformanceTests {
    static let source = UUID()
    static let base = Date(timeIntervalSince1970: 1_700_000_000)

    static let movies: ShelfCatalogue = ShelfCatalogue(
        titles: (0..<50_000).map { index in
            ShelfTitle(
                id: "xtream#h#vod#\(index)", kind: .movie, sourceID: source, name: "Movie \(index)",
                posterURL: URL(string: "http://h/p/\(index).jpg"),
                added: index.isMultiple(of: 50) ? nil : base.addingTimeInterval(Double((index * 7_919) % 50_000) * 60),
                category: "C\(index % 300)")
        },
        categories: (0..<300).map { "C\($0)" })

    static let series: ShelfCatalogue = ShelfCatalogue(
        titles: (0..<10_000).map { index in
            ShelfTitle(
                id: "xtream#h#series#\(index)", kind: .series, sourceID: source, name: "Series \(index)",
                added: base.addingTimeInterval(Double(index)), category: "S\(index % 100)")
        },
        categories: (0..<100).map { "S\($0)" })

    static let progress: [WatchProgress] = (0..<200).map { index in
        WatchProgress(
            id: "\(index)", titleID: "xtream#h#vod#\(index * 3)", sourceID: source, position: 100, duration: 1_000,
            updatedAt: base.addingTimeInterval(Double(index)))
    }

    private static func milliseconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) * 1_000 + Double(duration.components.attoseconds) / 1e15
    }

    @Test("movies-and-series-browsing/browsing-stays-responsive the rows and banner of 50 000 movies build in under 400 ms")
    func indexBuild() {
        var index = ShelfIndex.empty
        let elapsed = FastestRun.of { index = ShelfIndex(catalogues: [Self.movies], now: Self.base) }
        #expect(index.titles.count == 50_000)
        #expect(index.rows == Shelf.rows(Self.movies.titles, categoryOrder: Self.movies.categories, now: Self.base))
        #expect(index.banner == Shelf.banner(Self.movies.titles))
        #expect(index.newest == ShelfTitle.newestFirst(Self.movies.titles))
        #expect(Self.milliseconds(elapsed) < 400, "the index took \(Self.milliseconds(elapsed)) ms")
    }

    @Test("movies-and-series-browsing/browsing-stays-responsive newest first sorts 50 000 movies in under 300 ms")
    func newestFirst() {
        var sorted: [ShelfTitle] = []
        let elapsed = FastestRun.of { sorted = ShelfTitle.newestFirst(Self.movies.titles) }
        #expect(sorted.count == 50_000)
        #expect(sorted.last?.added == nil, "undated titles go last")
        #expect(zip(sorted, sorted.dropFirst()).allSatisfy { ($0.added ?? .distantPast) >= ($1.added ?? .distantPast) })
        #expect(Self.milliseconds(elapsed) < 300, "the sort took \(Self.milliseconds(elapsed)) ms")
    }

    @Test("movies-and-series-browsing/browsing-stays-responsive Continue watching and Recently watched read 200 positions in under 10 ms")
    func rowsFromSavedPositions() {
        let movies = ShelfIndex(catalogues: [Self.movies], now: Self.base)
        let series = ShelfIndex(catalogues: [Self.series], now: Self.base)
        let lookup: (ActivityKey) -> ShelfTitle? = { movies.title($0) ?? series.title($0) }
        var watching: [ContinueWatching.Item] = []
        var watched: [ShelfTitle] = []
        let continueTime = FastestRun.of { watching = ContinueWatching.items(progress: Self.progress, title: lookup) }
        let recentTime = FastestRun.of { watched = RecentlyWatched.list(progress: Self.progress, kind: .movie, title: movies.title) }
        #expect(watching == ContinueWatching.items(progress: Self.progress, titles: Self.movies.titles + Self.series.titles))
        #expect(watched == RecentlyWatched.list(progress: Self.progress, titles: Self.movies.titles, kind: .movie))
        #expect(watching.count == 200)
        #expect(Self.milliseconds(continueTime) < 10, "Continue watching took \(Self.milliseconds(continueTime)) ms")
        #expect(Self.milliseconds(recentTime) < 10, "Recently watched took \(Self.milliseconds(recentTime)) ms")
    }

    @Test("movies-and-series-browsing/browsing-stays-responsive two sources build one index in source order")
    func twoSources() {
        let other = UUID()
        let more = ShelfCatalogue(
            titles: [
                ShelfTitle(id: "xtream#o#vod#1", kind: .movie, sourceID: other, name: "Newest", added: Self.base.addingTimeInterval(1e8))
            ],
            categories: [])
        let index = ShelfIndex(catalogues: [Self.movies, more], now: Self.base)
        #expect(index.titles.count == 50_001)
        #expect(index.banner.first?.name == "Newest")
        #expect(index.title(ActivityKey(titleID: "xtream#o#vod#1", sourceID: other))?.name == "Newest")
        #expect(index.title(ActivityKey(titleID: "xtream#o#vod#1", sourceID: Self.source)) == nil)
    }

    @Test("movies-and-series-browsing/browsing-stays-responsive a playlist is fetched again at most once in five minutes per source")
    func retryWindow() {
        var window = RetryWindow<UUID>(length: 300)
        let other = UUID()
        let answers = [
            window.allows(Self.source, now: Self.base),
            window.allows(Self.source, now: Self.base.addingTimeInterval(10)),
            window.allows(Self.source, now: Self.base.addingTimeInterval(299)),
            window.allows(other, now: Self.base.addingTimeInterval(10)),
            window.allows(Self.source, now: Self.base.addingTimeInterval(300)),
        ]
        #expect(answers == [true, false, false, true, true])
    }
}
