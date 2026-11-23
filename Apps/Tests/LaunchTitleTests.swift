import AntennaCore
import Foundation
import Testing

@testable import Antenna

/// The title watched last reopening at launch on iPhone, iPad and Mac, with
/// a scripted library and a clock moved by hand.
@MainActor
@Suite struct LaunchTitleTests {
    let defaults: UserDefaults
    let source = UUID(uuidString: "00000000-0000-0000-0000-00000000AD01") ?? UUID()
    let other = UUID(uuidString: "00000000-0000-0000-0000-00000000AD02") ?? UUID()
    let clock = SleepClock()

    init() throws {
        defaults = try #require(UserDefaults(suiteName: "launch-title-tests-\(UUID().uuidString)"))
    }

    private var store: RecentsStore { RecentsStore(defaults: defaults) }

    private var series: ShelfTitle {
        ShelfTitle(id: "xtream#h#series#2", kind: .series, sourceID: source, name: "Harbor Watch", category: "Crime")
    }

    private var movie: ShelfTitle {
        ShelfTitle(id: "xtream#h#vod#7", kind: .movie, sourceID: source, name: "Salt Road", category: "Drama")
    }

    /// Two episodes of season 1 and one of season 2.
    private var episodes: [Episode] {
        [
            Episode(id: "xtream#h#episode#21", episodeID: 21, season: 1, number: 1, title: "E1"),
            Episode(id: "xtream#h#episode#22", episodeID: 22, season: 1, number: 2, title: "E2"),
            Episode(id: "xtream#h#episode#31", episodeID: 31, season: 2, number: 1, title: "E1"),
        ]
    }

    private var descriptor: SourceDescriptor {
        SourceDescriptor(id: source, name: "Cabin", kind: .xtream, url: URL(fileURLWithPath: "/cabin"))
    }

    private enum Answer { case titles, nothing, fails, never }

    /// The source answers as `answer` says; `.never` never finishes.
    private func library(_ answer: Answer = .titles) -> ShelfLibrary {
        let titles = (movies: [movie], series: [series])
        let episodes = episodes
        let dependencies = ShelfModel.Dependencies(
            load: { _, kind in
                switch answer {
                case .titles: return ShelfCatalogue(titles: kind == .movie ? titles.movies : titles.series, categories: [])
                case .nothing: return ShelfCatalogue(titles: [], categories: [])
                case .fails: throw URLError(.badServerResponse)
                case .never:
                    try await Task.sleep(for: .seconds(3600))
                    return ShelfCatalogue(titles: [], categories: [])
                }
            },
            hasLogin: { _ in true },
            info: { _, title in title.kind == .movie ? .movie(VODInfo()) : .series(SeriesInfo(episodes: episodes)) })
        let library = ShelfLibrary(movies: ShelfModel(kind: .movie, dependencies), series: ShelfModel(kind: .series, dependencies))
        library.sourcesChanged([descriptor])
        return library
    }

    private func live() -> LiveModel {
        let clock = clock
        return LiveModel(
            .init(
                engine: PlayerTestEngine(), load: { _ in Playlist(channels: []) }, hasLogin: { _ in true },
                programmes: UITestingLive.guide, recents: store, sleep: { try await clock.sleep($0) },
                launchSleep: { try await clock.sleep($0) }))
    }

    private func watched(_ episode: Episode) throws {
        store.write(LastWatched(title: try #require(LastWatched.Title(episode: episode, of: series))))
    }

    /// Opens both sections and waits for their loads to finish.
    private func loaded(_ library: ShelfLibrary) async {
        library.open()
        await library.movies.settled()
        await library.series.settled()
    }

    // MARK: session-restore-and-recently-watched/reopen-on-the-title-watched-last

    @Test("session-restore-and-recently-watched/reopen-on-the-title-watched-last an episode opens its series page on its season")
    func episodePage() async throws {
        try watched(episodes[2])
        let live = live()
        #expect(live.restoredTab == .series, "Series opens")
        live.screenRestored(.series)
        let library = library()
        #expect(live.launchTitle.resolve(in: library) == nil, "nothing listed yet")
        #expect(live.launchTitle.holds)
        await loaded(library)
        let key = try #require(live.launchTitle.waiting)
        let found = try #require(live.launchTitle.resolve(in: library))
        #expect(found == series)
        library.reopen(found, episode: key.episodeID)
        live.launchTitle.opened()
        #expect(!live.launchTitle.holds)
        let route = try #require(library.page)
        #expect(route.section == .series)
        #expect(route.origin == .banner, "Back shows the section's rows, as from the banner")
        await route.model.load()
        let season = route.model.groups.first { $0.episodes.contains(episodes[2]) }?.id
        #expect(route.model.pickedSeason == season)
        #expect(route.model.lastPlayed == nil, "Resume stays in view")
    }

    @Test("session-restore-and-recently-watched/reopen-on-the-title-watched-last a movie opens Movies, and nothing waits after a channel")
    func movieOrChannel() throws {
        store.write(LastWatched(title: try #require(LastWatched.Title(movie: movie))))
        #expect(live().restoredTab == .movies)
        store.write(LastWatched.live)
        store.write(LiveSession(tab: .guide))
        let afterChannel = live()
        #expect(afterChannel.restoredTab == .guide, "the stored tab, as before")
        #expect(!afterChannel.launchTitle.holds)
    }

    // MARK: session-restore-and-recently-watched/a-title-that-cannot-open-gives-way

    @Test("session-restore-and-recently-watched/a-title-that-cannot-open-gives-way a source without the title, or failing, gives way")
    func gone() async throws {
        for answer in [Answer.nothing, .fails] {
            try watched(episodes[0])
            let live = live()
            live.screenRestored(.series)
            let library = library(answer)
            await loaded(library)
            #expect(live.launchTitle.resolve(in: library) == nil)
            #expect(!live.launchTitle.holds, "\(answer) gives way")
            #expect(library.page == nil)
        }
    }

    @Test("session-restore-and-recently-watched/a-title-that-cannot-open-gives-way a title not listed within 10 seconds gives way")
    func slow() async throws {
        try watched(episodes[0])
        let live = live()
        live.screenRestored(.series)
        let library = library(.never)
        library.open()
        await clock.advance(by: .seconds(9))
        #expect(live.launchTitle.resolve(in: library) == nil)
        #expect(live.launchTitle.holds, "still waiting at 9 seconds")
        await clock.advance(by: .seconds(1))
        #expect(!live.launchTitle.holds)
        #expect(live.launchTitle.waiting == nil)
    }

    @Test("session-restore-and-recently-watched/a-title-that-cannot-open-gives-way another tab first, or another launch screen, gives way")
    func movedOn() throws {
        try watched(episodes[0])
        let first = live()
        first.screenRestored(.series)
        first.opened(.live)
        #expect(!first.launchTitle.holds, "the user opened Live first")
        let second = live()
        second.screenRestored(.guide)
        #expect(!second.launchTitle.holds, "the launch screen opened the Guide")
    }

    // MARK: session-restore-and-recently-watched/what-was-watched-last

    @Test("session-restore-and-recently-watched/what-was-watched-last a channel counts after ten seconds, not before")
    func channelAfterTenSeconds() async throws {
        try watched(episodes[0])
        let live = live()
        let channel = Channel.tagged([Channel(id: "news", name: "News", streamURL: URL(fileURLWithPath: "/news.ts"))], sourceID: other)[0]
        live.pick(channel)
        await clock.settle()
        live.session.stateChanged(.playing)
        await clock.advance(by: .seconds(9))
        #expect(store.readLastWatched()?.title?.titleID == series.id, "nine seconds leave the title")
        await clock.advance(by: .seconds(1))
        #expect(store.readLastWatched() == .live)
    }

    @Test("session-restore-and-recently-watched/what-was-watched-last deleting the title's source forgets it")
    func sourceDeleted() throws {
        try watched(episodes[0])
        let kids = RecentsStore(defaults: defaults, profile: UUID())
        kids.write(LastWatched(title: LastWatched.Title(sourceID: other, titleID: "xtream#o#vod#1", kind: .movie)))
        RecentsStore.remove(source: source, from: defaults)
        #expect(store.readLastWatched() == nil)
        #expect(kids.readLastWatched()?.title?.sourceID == other, "another source's title stays")
    }

    @Test("session-restore-and-recently-watched/what-was-watched-last a damaged value launches as after a channel")
    func damaged() {
        defaults.set(Data("{".utf8), forKey: RecentsStore.lastWatchedKey)
        #expect(store.readLastWatched() == nil)
        #expect(!live().launchTitle.holds)
    }
}
