import AntennaCore
import Foundation
import Testing

@testable import Antenna

/// A playlist's movies: out of Live, into Movies, playable, against a stubbed server.
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

    @Test("m3u-playlists/playlist-movies-stay-out-of-live-channels: Live gets channels and episodes, not movies")
    func liveLeavesMoviesOut() async throws {
        StubURLProtocol.register(host: "movies-playlist.test", body: Self.playlist)
        let (source, _) = loaders("movies-live")
        let loaded = try await source.load(try descriptor())
        #expect(loaded.channels.map(\.name) == ["News One", "Show S01E01"])
        #expect(loaded.movies.map(\.name) == ["Film A"])
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
        #expect(try await shelf.load(source, kind: .series).titles.isEmpty)
        #expect(try await shelf.info(source, title: film) == .movie(VODInfo(containerExtension: "mkv")))
        #expect(StubURLProtocol.requestCount(tag: "movies-shelf") == 1)
    }
}
