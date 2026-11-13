import Foundation
import Testing

@testable import AntennaCore

@Suite struct PlaylistEntryKindTests {
    private func entry(_ name: String, _ link: String, group: String? = nil) throws -> Channel {
        Channel(id: name, name: name, streamURL: try #require(URL(string: link)), group: group)
    }

    @Test(
        "m3u-playlists/movies-and-episodes-in-a-playlist-are-recognized each rule",
        arguments: [
            ("News 24", "http://tv.example/live/u/p/1.ts", nil, PlaylistEntryKind.live),
            ("News 24", "http://tv.example/u/p/1", "News", .live),
            ("Sports HD", "http://tv.example/hls/sports.m3u8", "Sports", .live),
            ("The Film", "http://tv.example/movie/u/p/9.mkv", nil, .movie),
            ("The Film", "http://tv.example/movies/the-film", nil, .movie),
            ("The Film", "http://cdn.example/files/the-film.MP4", nil, .movie),
            ("The Film", "http://cdn.example/files/the-film", "VOD | Action", .movie),
            ("The Film", "http://cdn.example/files/the-film", "Movies: Comedy", .movie),
            ("The Film", "http://cdn.example/files/the-film", "films", .movie),
            ("Videos", "http://cdn.example/files/stream", "Vodafone TV", .live),
            ("Show S01E02", "http://tv.example/series/u/p/77.mp4", nil, .episode),
            ("Show", "http://tv.example/series/u/p/77", nil, .episode),
            ("Show s1 e12", "http://cdn.example/show/e12.mp4", "VOD", .episode),
            ("BS01E02X", "http://tv.example/live/u/p/2.ts", nil, .live),
        ])
    func rules(name: String, link: String, group: String?, expected: PlaylistEntryKind) throws {
        #expect(PlaylistEntryKind(try entry(name, link, group: group)) == expected)
    }

    @Test("m3u-playlists/playlist-movies-stay-out-of-live-channels movies move out, episodes and live stay, order kept")
    func separating() throws {
        let playlist = Playlist(channels: [
            try entry("One", "http://tv.example/live/u/p/1.ts"),
            try entry("Film A", "http://tv.example/movie/u/p/9.mkv", group: "VOD | Action"),
            try entry("Show S01E01", "http://tv.example/series/u/p/7.mp4"),
            try entry("Two", "http://tv.example/live/u/p/2.ts"),
            try entry("Film B", "http://cdn.example/b.mp4"),
        ])
        let separated = playlist.separatingMovies()
        #expect(separated.channels.map(\.name) == ["One", "Show S01E01", "Two"])
        #expect(separated.movies.map(\.name) == ["Film A", "Film B"])
        #expect(separated.separatingMovies() == separated)
    }

    @Test("m3u-playlists/playlist-movies-show-in-movies titles from entries, groups as categories, no link in the id")
    func catalogue() throws {
        let source = UUID()
        let movies = [
            Channel(
                id: "m3u.aaa", name: "Film A", streamURL: try #require(URL(string: "http://tv.example/movie/u/secret/9.mkv")),
                group: "Action", logoURL: URL(string: "http://img.example/a.jpg")),
            Channel(id: "m3u.bbb", name: "Film B", streamURL: try #require(URL(string: "http://cdn.example/b")), group: "Drama"),
            Channel(id: "m3u.ccc", name: "Film C", streamURL: try #require(URL(string: "http://cdn.example/c.mp4")), group: "Action"),
        ]
        let catalogue = ShelfCatalogue(playlistMovies: movies, sourceID: source)
        #expect(catalogue.categories == ["Action", "Drama"])
        #expect(catalogue.titles.map(\.id) == ["m3u.aaa", "m3u.bbb", "m3u.ccc"])
        #expect(catalogue.titles.allSatisfy { $0.kind == .movie && $0.sourceID == source })
        #expect(catalogue.titles.map(\.containerExtension) == ["mkv", nil, "mp4"])
        #expect(catalogue.titles.first?.posterURL?.absoluteString == "http://img.example/a.jpg")
        #expect(!catalogue.titles.contains { $0.id.contains("secret") || $0.id.contains("://") })
    }
}
