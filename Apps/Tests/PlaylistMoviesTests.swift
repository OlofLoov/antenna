import AntennaCore
import Foundation
import Testing

@testable import Antenna

/// A playlist's movies and series: out of Live, into Movies and Series,
/// playable, against a stubbed server.
@MainActor
@Suite struct PlaylistMoviesTests {
    private static let playlist = """
        #EXTM3U
        #EXTINF:-1 group-title="News",News One
        http://movies-playlist.test/live/u/p/1.ts
        #EXTINF:-1 tvg-logo="http://img.test/a.jpg" group-title="VOD | Action",Film A
        http://movies-playlist.test/movie/u/p/9.mkv
        #EXTINF:-1 group-title="Shows",Show S01E01
        http://movies-playlist.test/series/u/p/7.mp4
        #EXTINF:-1 tvg-logo="http://img.test/s.jpg" group-title="Shows",Show - S01E02 - The Visit
        http://movies-playlist.test/series/u/p/8.mkv
        """

    private func loaders(_ tag: String) -> (SourceLoader, ShelfLoader) {
        var source = SourceLoader(session: StubURLProtocol.session(tag: tag), credentials: HeldCredentialStore())
        source.playlistMovies = PlaylistMovies()
        let shelf = ShelfLoader(session: source.session, credentials: source.credentials, playlists: source)
        return (source, shelf)
    }

    private func descriptor() throws -> SourceDescriptor {
        SourceDescriptor(id: UUID(), name: "Home", kind: .m3u, url: try #require(URL(string: "http://movies-playlist.test/list.m3u")))
    }

    @Test("m3u-playlists/playlist-movies-stay-out-of-live-channels: Live gets channels, not movies or episodes")
    func liveLeavesMoviesOut() async throws {
        StubURLProtocol.register(host: "movies-playlist.test", body: Self.playlist)
        let (source, _) = loaders("movies-live")
        let loaded = try await source.load(try descriptor())
        #expect(loaded.channels.map(\.name) == ["News One"])
        #expect(loaded.movies.map(\.name) == ["Film A"])
        #expect(loaded.episodes.map(\.name) == ["Show S01E01", "Show - S01E02 - The Visit"])
    }

    @Test("m3u-playlists/playlist-movies-show-in-movies: Movies lists the playlist's movies and plays them from their link")
    func moviesShelf() async throws {
        StubURLProtocol.register(host: "movies-playlist.test", body: Self.playlist)
        let (_, shelf) = loaders("movies-shelf")
        let source = try descriptor()
        let catalogue = try await shelf.load(source, kind: .movie)
        #expect(catalogue.titles.map(\.name) == ["Film A"])
        #expect(catalogue.categories == ["VOD | Action"])
        let film = try #require(catalogue.titles.first)
        #expect(try shelf.movieURL(source, movie: film).absoluteString == "http://movies-playlist.test/movie/u/p/9.mkv")
        #expect(try await shelf.info(source, title: film) == .movie(VODInfo(containerExtension: "mkv")))
        #expect(StubURLProtocol.requestCount(tag: "movies-shelf") == 1)
    }

    @Test("m3u-playlists/playlist-series-show-in-series: Series lists the playlist's shows and plays episodes from their link")
    func seriesShelf() async throws {
        StubURLProtocol.register(host: "movies-playlist.test", body: Self.playlist)
        let (_, shelf) = loaders("series-shelf")
        let source = try descriptor()
        let catalogue = try await shelf.load(source, kind: .series)
        #expect(catalogue.titles.map(\.name) == ["Show"])
        #expect(catalogue.categories == ["Shows"])
        let show = try #require(catalogue.titles.first)
        #expect(!show.id.contains("://"))
        guard case .series(let info) = try await shelf.info(source, title: show) else {
            Issue.record("a playlist series answers series info")
            return
        }
        #expect(info.episodes.map(\.title) == ["Episode 1", "The Visit"])
        #expect(try await shelf.details(source, title: show).seasons == 1)
        let visit = try #require(try await shelf.episodes(source, series: show).last)
        #expect(try shelf.episodeURL(source, episode: visit).absoluteString == "http://movies-playlist.test/series/u/p/8.mkv")
        #expect(StubURLProtocol.requestCount(tag: "series-shelf") == 1)
    }

    @Test("m3u-playlists/playlist-series-show-in-series: a series the kept load lacks loads the playlist once more")
    func staleSeriesReloads() async throws {
        let source = SourceDescriptor(
            id: UUID(), name: "Home", kind: .m3u, url: try #require(URL(string: "http://stale-playlist.test/list.m3u")))
        StubURLProtocol.register(host: "stale-playlist.test", body: "#EXTM3U\n#EXTINF:-1,News One\nhttp://stale-playlist.test/1.ts\n")
        let (_, shelf) = loaders("stale-series")
        #expect(try await shelf.load(source, kind: .series).titles.isEmpty)
        let episodes = M3UParser().parse(Self.playlist).separatingOnDemand().episodes
        let show = try #require(PlaylistSeries(episodes: episodes, sourceID: source.id).catalogue.titles.first)

        StubURLProtocol.register(host: "stale-playlist.test", body: Self.playlist)
        guard case .series(let info) = try await shelf.info(source, title: show) else {
            Issue.record("the reloaded playlist answers series info")
            return
        }
        #expect(info.episodes.map(\.title) == ["Episode 1", "The Visit"])
        #expect(StubURLProtocol.requestCount(tag: "stale-series") == 2)
    }
}
