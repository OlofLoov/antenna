import Foundation
import Testing

@testable import AntennaCore

@Suite struct LastWatchedTests {
    private let movie = ShelfTitle(id: "xtream#cabin#vod#2", kind: .movie, sourceID: sourceA, name: "Second Act")
    private let series = ShelfTitle(id: "xtream#cabin#series#2", kind: .series, sourceID: sourceA, name: "Harbor Watch")
    private let episode = Episode(id: "xtream#cabin#episode#21", episodeID: 21, season: 1, number: 1, title: "Episode 1")

    @Test("session-restore-and-recently-watched/what-was-watched-last a movie, an episode and a channel round trip")
    func roundTrip() throws {
        let watchedMovie = LastWatched(title: try #require(LastWatched.Title(movie: movie)))
        let watchedEpisode = LastWatched(title: try #require(LastWatched.Title(episode: episode, of: series)))
        for value in [watchedMovie, watchedEpisode, .live] {
            #expect(LastWatched(data: value.data) == value)
        }
        let title = try #require(watchedEpisode.title)
        #expect(title.kind == .series)
        #expect(title.shelfKind == .series)
        #expect(title.episodeID == episode.id)
        #expect(title.activityKey == series.activityKey)
        #expect(watchedMovie.title?.episodeID == nil)
    }

    @Test("session-restore-and-recently-watched/what-was-watched-last nothing kept or a damaged value reads as nothing")
    func damaged() {
        #expect(LastWatched(data: nil) == nil)
        #expect(LastWatched(data: Data("not json".utf8)) == nil)
        #expect(LastWatched(data: Data(#"{"title": {"kind": "movie"}}"#.utf8)) == nil)
    }

    @Test("session-restore-and-recently-watched/what-was-watched-last no link is kept")
    func noLinks() {
        var linked = movie
        linked.id = "http://host/movie/u/p/2.mp4"
        #expect(LastWatched.Title(movie: linked) == nil)
        let linkedEpisode = Episode(id: "http://host/series/u/p/21.mp4", episodeID: 21, title: "Episode 1")
        #expect(LastWatched.Title(episode: linkedEpisode, of: series) == nil)
        let stored = LastWatched(title: LastWatched.Title(sourceID: sourceA, titleID: "http://host/x", kind: .movie))
        #expect(LastWatched(data: stored.data) == nil, "a link written by hand is not read back")
        let data = String(decoding: LastWatched(title: LastWatched.Title(episode: episode, of: series)).data ?? Data(), as: UTF8.self)
        #expect(!data.contains("://"))
    }

    @Test("session-restore-and-recently-watched/what-was-watched-last a movie is not taken for an episode or the other way round")
    func kinds() {
        #expect(LastWatched.Title(movie: series) == nil)
        #expect(LastWatched.Title(episode: episode, of: movie) == nil)
    }
}
