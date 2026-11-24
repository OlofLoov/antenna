import AntennaCore
import Foundation
import Testing

@testable import Antenna

/// Where focus goes back to once playback started from a section ends, and
/// the section's actions comparing equal across redraws.
extension ShelfPlaybackTests {
    @Test("title-detail-and-episode-picker/back-to-where-you-were a movie played from a poster gives that poster focus back")
    func backFromPlayingAPoster() async {
        let library = await library()
        var follow: Task<Void, Never>?
        defer { follow?.cancel() }
        let activity = await activity(&follow)
        let playback = playback()
        let actions = ShelfActions.section(.movie, library: library, activity: activity, playback: playback)
        actions.select(movie, in: "drama")
        #expect(await eventually { playback.playing != nil })
        #expect(library.returning == nil, "nothing takes focus while the movie plays")
        await playback.close()
        // ShelfSync calls this as playback ends.
        library.playbackEnded()
        #expect(library.returning == ShelfSpot(title: movie, origin: .poster(row: "drama")))
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
