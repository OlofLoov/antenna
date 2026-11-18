import AntennaCore
import Foundation
import Testing

@testable import Antenna

/// A title page's info call: asked once per opening, canceled on leaving,
/// and closed when the source goes. A scripted library stands in for the
/// provider.
@MainActor
@Suite struct TitleModelTests {
    let source = UUID(uuidString: "00000000-0000-0000-0000-00000000AC01") ?? UUID()

    private var movie: ShelfTitle {
        ShelfTitle(id: "xtream#h#vod#7", kind: .movie, sourceID: source, name: "Salt Road", category: "Drama", containerExtension: "mp4")
    }

    private var descriptor: SourceDescriptor {
        SourceDescriptor(id: source, name: "Cabin", kind: .xtream, url: URL(fileURLWithPath: "/cabin"))
    }

    /// Answers after `gate` opens, counting each call.
    private func library(calls: Counter, gate: Gate? = nil, login: Bool = true, fails: Bool = false) async -> ShelfLibrary {
        let title = movie
        let dependencies = ShelfModel.Dependencies(
            load: { _, kind in ShelfCatalogue(titles: kind == .movie ? [title] : [], categories: ["Drama"]) },
            hasLogin: { _ in login },
            episodes: { _, _ in [] },
            info: { _, _ in
                calls.value += 1
                if let gate { await gate.wait() }
                if fails { throw URLError(.badServerResponse) }
                return .movie(VODInfo(year: 2024, duration: 5_520, containerExtension: "mkv", rating: 7.4))
            })
        let library = ShelfLibrary(movies: ShelfModel(kind: .movie, dependencies), series: ShelfModel(kind: .series, dependencies))
        library.sourcesChanged([descriptor])
        library.open()
        await library.movies.settled()
        return library
    }

    @Test("title-detail-and-episode-picker/open-a-movie-s-page the page shows the name at once and asks for the details once")
    func asksOnce() async throws {
        let calls = Counter()
        let library = await library(calls: calls)
        library.openPage(movie, from: .poster(row: "recentlyAdded"), in: .movie)
        let model = try #require(library.page?.model)
        #expect(model.metadata.name == "Salt Road")
        #expect(model.metadata.eyebrow == "Movie · Drama")
        #expect(model.phase == .loading)

        await model.load()
        #expect(calls.value == 1)
        #expect(model.phase == .loaded)
        #expect(model.metadata.detailsLine == "2024 · 1 h 32 min · ★ 7.4")
        #expect(model.playable.containerExtension == "mkv", "the info call's extension wins")
    }

    @Test("title-detail-and-episode-picker/open-a-movie-s-page leaving drops a late reply from the page, and opening again uses it")
    func leaveBeforeTheReply() async throws {
        let calls = Counter()
        let gate = Gate()
        let library = await library(calls: calls, gate: gate)
        library.openPage(movie, from: .poster(row: "recentlyAdded"), in: .movie)
        let model = try #require(library.page?.model)
        let load = Task { await model.load() }
        #expect(await eventually { calls.value == 1 })
        load.cancel()
        library.closePage()
        gate.open()
        await load.value
        #expect(model.phase == .loading, "the late reply is dropped")
        #expect(model.metadata.detailsLine == nil)

        library.openPage(movie, from: .poster(row: "recentlyAdded"), in: .movie)
        let again = try #require(library.page?.model)
        #expect(again !== model)
        #expect(again.phase == .loaded, "the kept answer shows without loading")
        await again.load()
        #expect(calls.value == 1)
        #expect(again.metadata.detailsLine == "2024 · 1 h 32 min · ★ 7.4")
    }

    @Test("movies-and-series-browsing/title-details-are-asked-once-per-title the banner's answer opens the page, Retry asks again")
    func bannerThenPage() async throws {
        let calls = Counter()
        let library = await library(calls: calls)
        await library.movies.loadDetails(movie)
        #expect(calls.value == 1)
        #expect(library.movies.details[movie.id]?.year == 2024)
        library.movies.preview(movie)
        await library.movies.previewsSettled()
        #expect(calls.value == 1, "the preview asks nothing for a title the banner asked about")
        library.openPage(movie, from: .poster(row: "recentlyAdded"), in: .movie)
        let model = try #require(library.page?.model)
        #expect(model.phase == .loaded)
        await model.load()
        #expect(calls.value == 1, "the page asks nothing either")
        await model.load(refresh: true)
        #expect(calls.value == 2, "Retry asks the provider again")
        #expect(model.phase == .loaded)
    }

    @Test("movies-and-series-browsing/title-details-are-asked-once-per-title a failed preview leaves the page to ask, and Retry asks again")
    func failedPreview() async throws {
        let calls = Counter()
        let library = await library(calls: calls, fails: true)
        library.movies.preview(movie)
        await library.movies.previewsSettled()
        #expect(calls.value == 1)
        #expect(library.movies.answered.contains(movie.id))
        library.movies.preview(movie)
        await library.movies.previewsSettled()
        #expect(calls.value == 1, "a failure is not asked again by the preview")
        library.openPage(movie, from: .poster(row: "recentlyAdded"), in: .movie)
        let model = try #require(library.page?.model)
        await model.load()
        #expect(model.phase == .failed(.failed))
        await model.load(refresh: true)
        #expect(calls.value == 3)
    }

    @Test("movies-and-series-browsing/title-details-are-asked-once-per-title resting on three posters asks the first, then the third")
    func oneAtATime() async throws {
        let calls = Counter()
        let gate = Gate()
        let titles = (1...3).map { ShelfTitle(id: "xtream#h#vod#\($0)", kind: .movie, sourceID: source, name: "Title \($0)") }
        var asked: [String] = []
        let dependencies = ShelfModel.Dependencies(
            load: { _, kind in ShelfCatalogue(titles: kind == .movie ? titles : [], categories: []) },
            hasLogin: { _ in true },
            episodes: { _, _ in [] },
            info: { _, title in
                calls.value += 1
                asked.append(title.id)
                await gate.wait()
                return .movie(VODInfo(year: 2024))
            })
        let shelf = ShelfModel(kind: .movie, dependencies)
        shelf.sourcesChanged([descriptor])
        shelf.open()
        await shelf.settled()
        for title in titles { shelf.preview(title) }
        #expect(await eventually { calls.value == 1 })
        gate.open()
        await shelf.previewsSettled()
        #expect(asked == ["xtream#h#vod#1", "xtream#h#vod#3"])
        #expect(shelf.details["xtream#h#vod#2"] == nil)
    }

    @Test("movies-and-series-browsing/title-details-are-asked-once-per-title at most 100 answers are kept, oldest dropped first")
    func keptLimit() async throws {
        let titles = (0...ShelfModel.keptLimit).map {
            ShelfTitle(id: "xtream#h#vod#\($0)", kind: .movie, sourceID: source, name: "Title \($0)")
        }
        let dependencies = ShelfModel.Dependencies(
            load: { _, kind in ShelfCatalogue(titles: kind == .movie ? titles : [], categories: []) },
            hasLogin: { _ in true },
            episodes: { _, _ in [] },
            info: { _, _ in .movie(VODInfo(year: 2024)) })
        let shelf = ShelfModel(kind: .movie, dependencies)
        shelf.sourcesChanged([descriptor])
        shelf.open()
        await shelf.settled()
        for title in titles { _ = try await shelf.info(title) }
        #expect(shelf.keptInfo(titles[0]) == nil)
        #expect(shelf.keptInfo(titles[1]) != nil)
        #expect(shelf.keptInfo(titles[ShelfModel.keptLimit]) != nil)
    }

    @Test("title-detail-and-episode-picker/open-a-movie-s-page the page knows when its source is deleted")
    func sourceDeleted() async throws {
        let library = await library(calls: Counter())
        library.openPage(movie, from: .poster(row: "recentlyAdded"), in: .movie)
        let model = try #require(library.page?.model)
        #expect(model.sourceExists)
        library.sourcesChanged([])
        #expect(!model.sourceExists)
    }

    @Test("title-detail-and-episode-picker/open-a-movie-s-page the same title on two sources opens two pages")
    func twoSources() async throws {
        let library = await library(calls: Counter())
        let other = ShelfTitle(id: movie.id, kind: .movie, sourceID: UUID(), name: "Salt Road")
        library.openPage(movie, from: .poster(row: "recentlyAdded"), in: .movie)
        let first = try #require(library.page)
        library.openPage(other, from: .poster(row: "recentlyAdded"), in: .movie)
        let second = try #require(library.page)
        #expect(first != second)
        #expect(first.title.activityKey != second.title.activityKey, "each keeps its own progress")
    }

    @Test("title-detail-and-episode-picker/when-details-or-episodes-do-not-load a failure and a missing login say so")
    func failures() async throws {
        let failing = await library(calls: Counter(), fails: true)
        failing.openPage(movie, from: .poster(row: "recentlyAdded"), in: .movie)
        let model = try #require(failing.page?.model)
        await model.load()
        #expect(model.phase == .failed(.failed))
        #expect(TitleProblem.failed.message(.movie) == "Could not load details")
        #expect(TitleProblem.failed.message(.series) == "Could not load episodes")

        let calls = Counter()
        let waiting = await library(calls: calls, login: false)
        waiting.openPage(movie, from: .poster(row: "recentlyAdded"), in: .movie)
        let page = try #require(waiting.page?.model)
        await page.load()
        #expect(page.phase == .failed(.waitingForLogin("Cabin")))
        #expect(calls.value == 0, "nothing is asked without the login")
        #expect(!page.checkLogin())
        #expect(TitleProblem.waitingForLogin("Cabin").message(.movie) == "Cabin: waiting for its login to sync from iCloud")
    }

    @Test("title-detail-and-episode-picker/what-each-episode-shows a series groups its episodes and counts the unreadable ones")
    func seriesEpisodes() async throws {
        let series = ShelfTitle(id: "xtream#h#series#3", kind: .series, sourceID: source, name: "Northern Lights", category: "Drama")
        let episodes = [
            Episode(id: "e1", episodeID: 1, season: 2, number: 1, title: "A"),
            Episode(id: "e2", episodeID: 2, season: 1, number: 1, title: "B"),
            Episode(id: "e3", episodeID: 3, season: 0, number: 1, title: "C"),
        ]
        for (list, skipped) in [(episodes, 2), ([], 0)] {
            let dependencies = ShelfModel.Dependencies(
                load: { _, kind in ShelfCatalogue(titles: kind == .series ? [series] : [], categories: ["Drama"]) },
                hasLogin: { _ in true }, episodes: { _, _ in [] },
                info: { _, _ in .series(SeriesInfo(episodes: list, skippedEpisodes: skipped)) })
            let library = ShelfLibrary(movies: ShelfModel(kind: .movie, dependencies), series: ShelfModel(kind: .series, dependencies))
            library.sourcesChanged([descriptor])
            library.openPage(series, from: .poster(row: "recentlyAdded"), in: .series)
            let model = try #require(library.page?.model)
            await model.load()
            #expect(model.phase == .loaded)
            #expect(model.skipped == skipped)
            if list.isEmpty {
                #expect(model.groups.isEmpty, "no episodes: the page says so and Play is disabled")
            } else {
                #expect(model.groups.map(\.title) == ["Season 1", "Season 2", "Specials"])
                #expect(model.metadata.detailsLine == "2 seasons")
                #expect(library.series.episodes[series.id]?.count == 3, "kept for Continue watching")
            }
        }
    }
}

/// Holds an answer back until the test opens it.
@MainActor
final class Gate {
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var opened = false

    func wait() async {
        guard !opened else { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
        opened = true
        waiters.forEach { $0.resume() }
        waiters = []
    }
}
