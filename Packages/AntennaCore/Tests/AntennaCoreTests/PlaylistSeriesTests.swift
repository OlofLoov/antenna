import Foundation
import Testing

@testable import AntennaCore

@Suite struct PlaylistSeriesTests {
    let source = UUID()

    private static let link = "http://tv.example/series/u/secret/1.mkv"

    private func entry(_ id: String, _ name: String, group: String? = nil) throws -> Channel {
        Channel(
            id: id, name: name, streamURL: try #require(URL(string: Self.link)), group: group,
            logoURL: URL(string: "http://img.example/\(id).jpg"))
    }

    @Test(
        "m3u-playlists/playlist-episodes-group-into-series reads show, season, number and title",
        arguments: [
            ("Show S01E02", "Show", 1, 2, nil as String?),
            ("Show - S01E02 - The Visit", "Show", 1, 2, "The Visit"),
            ("The.Show.S10E101.720p", "The Show", 10, 101, "720p"),
            ("Show | s1 e12: Part (1)", "Show", 1, 12, "Part (1)"),
            ("Show (2019) S02E03", "Show (2019)", 2, 3, nil),
            ("S01E04 Pilot", "", 1, 4, "Pilot"),
        ])
    func names(name: String, show: String, season: Int, number: Int, title: String?) throws {
        let parsed = try #require(EpisodeName(name))
        #expect(parsed.show == show)
        #expect(parsed.season == season)
        #expect(parsed.number == number)
        #expect(parsed.title == title)
    }

    @Test("m3u-playlists/playlist-episodes-group-into-series a name without a marker is not an episode name")
    func noMarker() {
        #expect(EpisodeName("News 24") == nil)
        #expect(EpisodeName("BS01E02X") == nil)
    }

    @Test(
        "m3u-playlists/season-and-episode-markers crossed numbers and spelled-out seasons read like S01E02",
        arguments: [
            ("Show 1x02", "Show", 1, 2, nil as String?),
            ("Show - 01x02 - The Visit", "Show", 1, 2, "The Visit"),
            ("The.Show.10X101.720p", "The Show", 10, 101, "720p"),
            ("Show 2×05", "Show", 2, 5, nil),
            ("Show Season 1 Episode 2 - The Visit", "Show", 1, 2, "The Visit"),
            ("Show - season 3, ep. 4", "Show", 3, 4, nil),
            ("Show Season 12 Ep 7: Finale", "Show", 12, 7, "Finale"),
        ])
    func otherMarkers(name: String, show: String, season: Int, number: Int, title: String?) throws {
        let parsed = try #require(EpisodeName(name))
        #expect(parsed.show == show)
        #expect(parsed.season == season)
        #expect(parsed.number == number)
        #expect(parsed.title == title)
    }

    @Test(
        "m3u-playlists/season-and-episode-markers sizes, counts and a lone episode number are not markers",
        arguments: [
            "4x4 Off-Road", "Comedy 24x7", "Test 1920x1080", "Show 1x2", "Show 1x02b", "Show 101x02", "Ep 2", "Episode 4",
            "Season 2",
        ])
    func notMarkers(name: String) {
        #expect(EpisodeName(name) == nil)
    }

    @Test("m3u-playlists/season-and-episode-markers one show written with different markers is one series")
    func mixedMarkers() throws {
        let series = PlaylistSeries(
            episodes: [
                try entry("m3u.a", "Show 1x02"), try entry("m3u.b", "Show S01E01"), try entry("m3u.c", "Show Season 2 Episode 1"),
            ], sourceID: source)
        #expect(series.catalogue.titles.map(\.name) == ["Show"])
        let show = try #require(series.catalogue.titles.first)
        let info = try #require(series.info(for: show.id))
        #expect(info.episodes.map(\.id) == ["m3u.b", "m3u.a", "m3u.c"])
    }

    @Test("m3u-playlists/playlist-episodes-group-into-series two seasons of one show, different shows, ordered episodes")
    func grouping() throws {
        let series = PlaylistSeries(
            episodes: [
                try entry("m3u.a", "Show S02E01", group: "Shows"),
                try entry("m3u.b", "Alpha S01E01", group: "Kids"),
                try entry("m3u.c", "Show - S01E02 - The Visit", group: "Shows"),
                try entry("m3u.d", "show s01e01", group: "Shows"),
                try entry("m3u.e", "The.Show.S01E01"),
            ], sourceID: source)
        let titles = series.catalogue.titles
        #expect(titles.map(\.name) == ["Show", "Alpha", "The Show"])
        #expect(series.catalogue.categories == ["Shows", "Kids"])
        let show = try #require(titles.first)
        #expect(show.kind == .series && show.sourceID == source && show.category == "Shows")
        #expect(show.posterURL?.absoluteString == "http://img.example/m3u.a.jpg")
        let info = try #require(series.info(for: show.id))
        #expect(info.episodes.map(\.id) == ["m3u.d", "m3u.c", "m3u.a"])
        #expect(info.episodes.map(\.title) == ["Episode 1", "The Visit", "Episode 1"])
        #expect(info.episodes.map(\.season) == [1, 1, 2])
        #expect(info.seasonCount == 2)
        #expect(info.episodes.first?.containerExtension == "mkv")
        #expect(series.info(for: "m3u.series.unknown") == nil)
    }

    @Test("m3u-playlists/playlist-episodes-group-into-series an episode without a title or marker")
    func withoutMarker() throws {
        let series = PlaylistSeries(
            episodes: [try entry("m3u.a", "Show S01E03"), try entry("m3u.b", "Pilot"), try entry("m3u.c", "S01E01", group: "Docs")],
            sourceID: source)
        #expect(series.catalogue.titles.map(\.name) == ["Show", "Pilot", "Docs"])
        let ids = series.catalogue.titles.map(\.id)
        #expect(series.info(for: ids[0])?.episodes.first?.title == "Episode 3")
        let pilot = try #require(series.info(for: ids[1])?.episodes.first)
        #expect(pilot.title == "Pilot" && pilot.season == nil && pilot.number == nil)
    }

    @Test("m3u-playlists/playlist-episodes-group-into-series ids hold no link and differ per source")
    func ids() throws {
        let episodes = [try entry("m3u.a", "Show S01E01")]
        let mine = PlaylistSeries(episodes: episodes, sourceID: source)
        let theirs = PlaylistSeries(episodes: episodes, sourceID: UUID())
        let id = try #require(mine.catalogue.titles.first?.id)
        #expect(id.hasPrefix("m3u.series.") && id.count == "m3u.series.".count + 16)
        #expect(!id.contains("secret") && !id.contains("://"))
        #expect(id != theirs.catalogue.titles.first?.id)
        #expect(PlaylistSeries(episodes: episodes, sourceID: source).catalogue.titles.first?.id == id)
        #expect(mine.info(for: id)?.episodes.allSatisfy { !$0.id.contains("://") } == true)
    }
}
