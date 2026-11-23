import AntennaCore
import Foundation
import Testing

@testable import Antenna

/// What `ShelfPlayback` writes as watched last, with the scripted engine and
/// library of `ShelfPlaybackTests`.
extension ShelfPlaybackTests {
    @Test("session-restore-and-recently-watched/what-was-watched-last a movie or an episode that starts is watched last; a trailer is not")
    func watchedLast() async throws {
        let defaults = try #require(UserDefaults(suiteName: "shelf-watched-\(UUID().uuidString)"))
        let recents = RecentsStore(defaults: defaults)
        let library = await library()
        var follow: Task<Void, Never>?
        defer { follow?.cancel() }
        let activity = await activity(&follow)
        let playback = playback()
        playback.recordsWatched(in: recents)

        let link = try #require(URL(string: "https://cdn.example/salt-road.m3u8"))
        playback.playTrailer(link, of: movie)
        #expect(await eventually { engine.state == .playing })
        #expect(recents.readLastWatched() == nil, "a trailer does not count")

        playback.play(movie, library: library, activity: activity)
        #expect(await eventually { recents.readLastWatched()?.title?.titleID == movie.id })
        #expect(recents.readLastWatched()?.title?.kind == .movie)

        playback.play(episode(1, 3), of: series(1), from: 0, library: library, activity: activity)
        #expect(await eventually { recents.readLastWatched()?.title?.episodeID == episode(1, 3).id })
        #expect(recents.readLastWatched()?.title?.titleID == series(1).id)
        #expect(recents.readLastWatched()?.title?.kind == .series)
    }
}
