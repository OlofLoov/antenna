import AntennaCore
import Foundation
import Testing

@testable import Antenna

/// What selecting a poster does, where focus goes back to once a page or
/// playback started from a section ends, and the section's actions
/// comparing equal across redraws.
extension ShelfPlaybackTests {
    @Test("movies-and-series-browsing/a-poster-opens-its-page a movie poster in a row opens the movie's page and plays nothing")
    func aMoviePosterOpensItsPage() async {
        let library = await library()
        var follow: Task<Void, Never>?
        defer { follow?.cancel() }
        let activity = await activity(&follow)
        let playback = playback()
        let actions = ShelfActions.section(.movie, library: library, activity: activity, playback: playback)
        actions.select(movie, in: "drama")
        #expect(library.page?.title == movie)
        #expect(library.page?.origin == .poster(row: "drama"))
        await Task.yield()
        #expect(playback.playing == nil)
        #expect(engine.loads.isEmpty, "nothing started")
    }

    @Test("movies-and-series-browsing/a-poster-opens-its-page a series poster opens the series' page")
    func aSeriesPosterOpensItsPage() async {
        let library = await library()
        var follow: Task<Void, Never>?
        defer { follow?.cancel() }
        let activity = await activity(&follow)
        let playback = playback()
        let actions = ShelfActions.section(.series, library: library, activity: activity, playback: playback)
        actions.select(series(1), in: "drama")
        #expect(library.page?.title == series(1))
        await Task.yield()
        #expect(playback.playing == nil)
        #expect(engine.loads.isEmpty)
    }

    @Test("movies-and-series-browsing/a-poster-opens-its-page a movie in Recently watched plays, a series there opens its page")
    func recentlyWatchedPlaysAMovie() async {
        let library = await library()
        var follow: Task<Void, Never>?
        defer { follow?.cancel() }
        let activity = await activity(&follow)
        let playback = playback()
        #expect(ShelfActions.plays(movie, in: ShelfActions.recentlyWatched))
        #expect(!ShelfActions.plays(series(1), in: ShelfActions.recentlyWatched))
        #expect(!ShelfActions.plays(movie, in: "myList"))
        let actions = ShelfActions.section(.movie, library: library, activity: activity, playback: playback)
        actions.select(movie, in: ShelfActions.recentlyWatched)
        #expect(await eventually { playback.playing != nil })
        #expect(library.page == nil, "no page opens")
    }

    @Test("title-detail-and-episode-picker/back-to-where-you-were closing a movie's page opened from a poster gives that poster focus back")
    func backFromAMoviePage() async {
        let library = await library()
        var follow: Task<Void, Never>?
        defer { follow?.cancel() }
        let activity = await activity(&follow)
        let actions = ShelfActions.section(.movie, library: library, activity: activity, playback: playback())
        actions.select(movie, in: "drama")
        library.closePage()
        #expect(library.page == nil)
        #expect(library.returning == ShelfSpot(title: movie, origin: .poster(row: "drama")))
    }

    @Test("title-detail-and-episode-picker/back-to-where-you-were a movie resumed from Continue watching gives that card focus back")
    func backFromPlayingAPoster() async {
        let library = await library()
        var follow: Task<Void, Never>?
        defer { follow?.cancel() }
        let activity = await activity(&follow)
        let playback = playback()
        let actions = ShelfActions.section(.movie, library: library, activity: activity, playback: playback)
        // movies-and-series-browsing/a-poster-opens-its-page, Continue watching plays
        actions.resume(movie, in: "continueWatching")
        #expect(await eventually { playback.playing != nil })
        #expect(library.page == nil, "Continue watching plays straight away")
        #expect(library.returning == nil, "nothing takes focus while the movie plays")
        await playback.close()
        // ShelfSync calls this as playback ends.
        library.playbackEnded()
        #expect(library.returning == ShelfSpot(title: movie, origin: .poster(row: "continueWatching")))
        library.returned()
        library.playbackEnded()
        #expect(library.returning == nil, "the poster takes focus back once")
    }

    @Test("title-detail-and-episode-picker/back-to-where-you-were the banner's Play leaves focus to the banner")
    func backFromPlayingTheBanner() async {
        let library = await library()
        var follow: Task<Void, Never>?
        defer { follow?.cancel() }
        let activity = await activity(&follow)
        let playback = playback()
        let actions = ShelfActions.section(.movie, library: library, activity: activity, playback: playback)
        actions.play(movie, .banner)
        #expect(await eventually { playback.playing != nil })
        await playback.close()
        library.playbackEnded()
        #expect(library.returning == nil)
    }

    @Test("movies-and-series-browsing/browsing-stays-responsive the actions a screen makes again on each redraw compare equal")
    func actionsCompareEqual() async {
        let library = await library()
        var follow: Task<Void, Never>?
        defer { follow?.cancel() }
        let activity = await activity(&follow)
        let playback = playback()
        let movies = ShelfActions.section(.movie, library: library, activity: activity, playback: playback)
        #expect(movies == ShelfActions.section(.movie, library: library, activity: activity, playback: playback))
        #expect(movies != ShelfActions.section(.series, library: library, activity: activity, playback: playback))
        #expect(movies != ShelfActions.section(.movie, library: library, activity: ShelfActivity(), playback: playback))
    }
}
