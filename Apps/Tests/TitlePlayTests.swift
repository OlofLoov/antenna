import AntennaCore
import Foundation
import SwiftData
import Testing

@testable import Antenna

/// Playing from a title page and coming back to it, and My list on the
/// page. A scripted engine stands in for the player, an in-memory store
/// for iCloud.
@MainActor
@Suite struct TitlePlayTests {
    let container: ModelContainer
    let source = UUID(uuidString: "00000000-0000-0000-0000-00000000AD01") ?? UUID()
    let engine = ScriptedEngine()
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    init() throws {
        let schema = Schema(AntennaSchema.models)
        container = try ModelContainer(
            for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none))
    }

    private var store: ActivityStore { ActivityStore(context: container.mainContext) }

    private var movie: ShelfTitle {
        ShelfTitle(id: "xtream#h#vod#7", kind: .movie, sourceID: source, name: "Salt Road", category: "Drama")
    }

    private var series: ShelfTitle {
        ShelfTitle(id: "xtream#h#series#1", kind: .series, sourceID: source, name: "Northern Lights", category: "Drama")
    }

    private func episode(_ season: Int, _ number: Int) -> Episode {
        let id = season * 10 + number
        return Episode(id: "xtream#h#episode#\(id)", episodeID: id, season: season, number: number, title: "E\(id)", duration: 5400)
    }

    private var episodes: [Episode] { [episode(1, 1), episode(1, 2), episode(2, 1), episode(2, 2)] }

    private func library() async -> ShelfLibrary {
        let titles = (movies: [movie], series: [series])
        let list = episodes
        let dependencies = ShelfModel.Dependencies(
            load: { _, kind in ShelfCatalogue(titles: kind == .movie ? titles.movies : titles.series, categories: ["Drama"]) },
            hasLogin: { _ in true }, details: { _, _ in ShelfDetails() }, episodes: { _, _ in list },
            info: { _, title in title.kind == .movie ? .movie(VODInfo()) : .series(SeriesInfo(episodes: list)) })
        let library = ShelfLibrary(movies: ShelfModel(kind: .movie, dependencies), series: ShelfModel(kind: .series, dependencies))
        library.sourcesChanged([SourceDescriptor(id: source, name: "Cabin", kind: .xtream, url: URL(fileURLWithPath: "/cabin"))])
        library.open()
        await library.movies.settled()
        await library.series.settled()
        return library
    }

    private func activity(_ follow: inout Task<Void, Never>?) async -> ShelfActivity {
        let activity = ShelfActivity()
        let store = store
        follow = Task { [container] in
            await activity.follow(store)
            withExtendedLifetime(container) {}
        }
        await Task.yield()
        return activity
    }

    private func playback() -> ShelfPlayback {
        ShelfPlayback(
            .init(
                engine: engine,
                address: { _, target in
                    switch target {
                    case .movie(let movie): URL(fileURLWithPath: "/\(movie.id).mp4")
                    case .episode(let episode, _): URL(fileURLWithPath: "/\(episode.id).mp4")
                    }
                },
                willPlay: {}))
    }

    @Test("title-detail-and-episode-picker/play-or-resume-a-movie Resume plays from the place, and the button follows on the way back")
    func resumeAMovie() async {
        let library = await library()
        var follow: Task<Void, Never>?
        defer { follow?.cancel() }
        let activity = await activity(&follow)
        #expect(TitlePageContext.PlayState.movie(activity.progress(of: movie)).label == "Play")

        store.saveProgress(titleID: movie.id, source: source, position: 2400, duration: 5400, now: now)
        #expect(await eventually { activity.progress(of: movie) != nil }, "a change from another device reaches the page")
        let resume = TitlePageContext.PlayState.movie(activity.progress(of: movie))
        #expect(resume.label == "Resume")
        #expect(resume.remaining == "50 min left")
        #expect(resume.fraction.map { abs($0 - 2400.0 / 5400) < 0.001 } == true)

        let playback = playback()
        playback.play(movie, library: library, activity: activity)
        #expect(await eventually { engine.state == .playing })
        #expect(engine.loads.last?.options.startPosition == .seconds(2400))
        engine.send(position: 4200)
        try? await Task.sleep(for: .milliseconds(50))
        await playback.close()
        #expect(playback.playing == nil, "back on the page")
        #expect(TitlePageContext.PlayState.movie(activity.progress(of: movie)).remaining == "20 min left")

        playback.play(movie, library: library, activity: activity)
        #expect(await eventually { engine.state == .playing })
        engine.finish()
        #expect(await eventually { activity.progress(of: movie)?.state == .watched })
        await playback.close()
        let finished = TitlePageContext.PlayState.movie(activity.progress(of: movie))
        #expect(finished.label == "Play", "a finished movie plays from the start")
        #expect(finished.fraction == nil)
    }

    @Test("title-detail-and-episode-picker/play-an-episode-and-come-back the episode plays from its place and the page follows")
    func playAnEpisode() async throws {
        let library = await library()
        var follow: Task<Void, Never>?
        defer { follow?.cancel() }
        let activity = await activity(&follow)
        library.openPage(series, from: .poster, in: .series)
        let model = try #require(library.page?.model)
        await model.load()
        let progress = { ContinueWatching.episodeProgress(activity.progress, seriesID: series.id, sourceID: source) }
        #expect(SeriesPlayTarget.resolve(episodes: model.episodes, progress: progress())?.label == "Play S1 E1")

        store.saveProgress(titleID: episode(2, 1).id, seriesID: series.id, source: source, position: 600, duration: 5400, now: now)
        #expect(await eventually { !progress().isEmpty })
        let picked = episode(2, 1)
        let from = model.willPlay(picked, progress: progress())
        #expect(from == 600)
        #expect(model.pickedSeason == "season-2")
        #expect(model.lastPlayed == picked.id)

        let playback = playback()
        playback.play(picked, of: series, from: from, library: library, activity: activity)
        #expect(await eventually { engine.state == .playing })
        #expect(engine.loads.last?.options.startPosition == .seconds(600))
        engine.send(position: 700)
        try? await Task.sleep(for: .milliseconds(50))
        engine.finish()
        #expect(await eventually { progress()[picked.id]?.state == .watched }, "its progress is saved as it plays")
        await playback.close()

        let target = SeriesPlayTarget.resolve(episodes: model.episodes, progress: progress())
        #expect(target?.episode == episode(2, 2), "UP NEXT moves to the next episode")
        #expect(TitlePageContext.PlayState.series(target, progress: progress()).label == "Play S2 E2")
        #expect(EpisodeText.status(picked, progress: progress()[picked.id]) == "Watched")
    }

    @Test("title-detail-and-episode-picker/my-list-from-the-page fast repeated presses leave the list matching the button")
    func myListPresses() async {
        _ = await library()
        var follow: Task<Void, Never>?
        defer { follow?.cancel() }
        let activity = await activity(&follow)
        for presses in 1...7 {
            activity.toggleMyList(movie)
            #expect(activity.isOnMyList(movie) == !presses.isMultiple(of: 2))
        }
        #expect(activity.isOnMyList(movie), "seven presses leave it on the list")
        #expect(store.myList(.movie).map(\.titleID) == [movie.id], "one entry, matching the button")
        activity.toggleMyList(movie)
        #expect(store.myList(.movie).isEmpty)
        #expect(!activity.isOnMyList(movie), "the page and the banner read the same answer")
    }
}
