import Foundation
import Testing

@testable import AntennaCore

@Suite struct XtreamSeriesDecodingTests {
    private let host = "H"

    private func seriesInfo(episodes: String) throws -> SeriesInfo {
        try XtreamClient.decodeSeriesInfo(Data("{\"episodes\":\(episodes)}".utf8), host: host)
    }

    @Test("0016/AC-6 series row fields")
    func seriesRowFields() throws {
        let list = try XtreamClient.decodeSeriesList(try xtreamFixture("series.json"), host: host)
        let series = try #require(list.items.first)
        #expect(series.seriesID == 7)
        #expect(series.id == "xtream#H#series#7")
        #expect(series.name == "Dark")
        #expect(series.posterURL == URL(string: "http://h/c.jpg"))
        #expect(series.lastModified == Date(timeIntervalSince1970: 1_730_600_000))
        #expect(series.categoryID == "3")

        let second = list.items[1]
        #expect(second.seriesID == 8)
        #expect(second.categoryID == "3")
        #expect(second.posterURL == nil)
        #expect(second.lastModified == nil)
    }

    @Test("0016/AC-6 last_modified follows the added rules", arguments: [#""0""#, #""abc""#, #""1e400""#, "1e400", "null"])
    func lastModifiedRule(value: String) throws {
        let list = try XtreamClient.decodeSeriesList(
            Data("[{\"name\":\"Dark\",\"series_id\":7,\"last_modified\":\(value)}]".utf8), host: host)
        #expect(try #require(list.items.first).lastModified == nil)
    }

    @Test("0016/AC-6a episodes keyed by season flatten")
    func episodesFlattenFromDictionary() throws {
        let info = try XtreamClient.decodeSeriesInfo(try xtreamFixture("series_info_dict.json"), host: host)
        #expect(info.plot == "A town")
        #expect(info.year == 2017)
        #expect(info.genre == "Drama")
        #expect(info.ageRating == "16")
        #expect(info.backdropURLs == [try #require(URL(string: "http://h/b.jpg"))])

        #expect(info.episodes.map(\.episodeID) == [101, 200, 201, 1001])
        #expect(
            info.episodes.map(\.id) == ["xtream#H#episode#101", "xtream#H#episode#200", "xtream#H#episode#201", "xtream#H#episode#1001"])
        #expect(info.episodes.map(\.season) == [1, 2, 2, 10])
        #expect(info.episodes.map(\.number) == [1, 1, 2, 1])
        #expect(info.episodes.map(\.title) == ["One one", "Two one", "Two two", "Ten one"])
        #expect(info.episodes.map(\.containerExtension) == ["mkv", "mp4", "mp4", "mkv"])
        #expect(info.episodes.map(\.duration) == [nil, 3100, 3000, 3000])
        #expect(info.seasonCount == 3)
    }

    @Test("0016/AC-6a episodes as an array")
    func episodesFlattenFromArray() throws {
        let info = try XtreamClient.decodeSeriesInfo(try xtreamFixture("series_info_array.json"), host: host)
        #expect(info.plot == nil)
        #expect(info.episodes.map(\.episodeID) == [300, 301])
        #expect(info.episodes.map(\.season) == [1, 1])
        #expect(info.episodes.map(\.number) == [1, 2])
    }

    @Test("0016/AC-6a season falls back to the key, then nil; number nil when not numeric")
    func seasonAndNumberFallback() throws {
        let info = try seriesInfo(episodes: #"{"x":[{"id":1,"episode_num":"one","title":"A"}],"4":[{"id":2,"title":"B"}]}"#)
        let byID = Dictionary(uniqueKeysWithValues: info.episodes.map { ($0.episodeID, $0) })
        #expect(byID[1]?.season == nil)
        #expect(byID[1]?.number == nil)
        #expect(byID[2]?.season == 4)
    }

    @Test("0016/AC-6b episodes sort by season then number, nil first, stable")
    func episodeOrder() throws {
        let body = #"""
            [{"id":1,"season":10,"episode_num":1,"title":"s10e1"},
             {"id":2,"season":2,"episode_num":10,"title":"s2e10"},
             {"id":3,"episode_num":1,"title":"nil e1"},
             {"id":4,"season":2,"episode_num":2,"title":"s2e2 first"},
             {"id":5,"season":1,"title":"s1 nil"},
             {"id":6,"season":2,"episode_num":1,"title":"s2e1"},
             {"id":7,"season":2,"episode_num":2,"title":"s2e2 second"},
             {"id":8,"season":1,"episode_num":1,"title":"s1e1"}]
            """#
        let info = try seriesInfo(episodes: body)
        #expect(info.episodes.map(\.title) == ["nil e1", "s1 nil", "s1e1", "s2e1", "s2e2 first", "s2e2 second", "s2e10", "s10e1"])
    }

    @Test("0016/AC-6b 0016/AC-6d season keys are visited in numeric order, then by name")
    func seasonKeyOrder() throws {
        let body = #"""
            {"b":[{"id":9,"season":3,"episode_num":1,"title":"from b"}],
             "10":[{"id":1,"season":3,"episode_num":1,"title":"from 10"},{"id":2,"title":"dup from 10"}],
             "a":[{"id":8,"season":3,"episode_num":1,"title":"from a"}],
             "2":[{"id":3,"season":3,"episode_num":1,"title":"from 2"},{"id":2,"title":"dup from 2"}]}
            """#
        let info = try seriesInfo(episodes: body)
        #expect(info.episodes.map(\.title) == ["dup from 2", "from 2", "from 10", "from a", "from b"])
        #expect(info.skippedEpisodes == 1)
    }

    @Test("0016/AC-6c season count uses resolved seasons, not keys")
    func seasonCount() throws {
        let info = try seriesInfo(episodes: #"{"2":[{"id":1,"season":3,"title":"A"},{"id":2,"title":"B"},{"id":3,"title":"C"}]}"#)
        #expect(info.seasonCount == 2)
    }

    @Test("0016/AC-6d broken and duplicate episodes are skipped; empty titles fall back")
    func episodeSkipping() throws {
        let info = try XtreamClient.decodeSeriesInfo(try xtreamFixture("series_info_broken_episodes.json"), host: host)
        #expect(info.skippedEpisodes == 4)
        #expect(info.episodes.map(\.episodeID) == [5, 1, 4])
        #expect(info.episodes.map(\.title) == ["Episode", "Keep", "Episode 4"])
    }

    @Test("0016/AC-6e empty episodes shapes", arguments: [nil, "{}", "[]", "false"])
    func emptyEpisodes(episodes: String?) throws {
        let body = episodes.map { "{\"info\":{\"plot\":\"P\"},\"episodes\":\($0)}" } ?? #"{"info":{"plot":"P"}}"#
        let info = try XtreamClient.decodeSeriesInfo(Data(body.utf8), host: host)
        #expect(info.plot == "P")
        #expect(info.episodes.isEmpty)
        #expect(info.seasonCount == 0)
        #expect(info.skippedEpisodes == 0)
    }

    @Test("0016/AC-13 ids are stable across responses and distinct per kind")
    func stableIDs() throws {
        let first = try XtreamClient.decodeVODList(Data(#"[{"name":"A","stream_id":55}]"#.utf8), host: "h")
        let again = try XtreamClient.decodeVODList(Data(#"[{"name":"A","stream_id":"55","rating":"9"}]"#.utf8), host: "h")
        #expect(first.items.map(\.id) == again.items.map(\.id))

        let series = try XtreamClient.decodeSeriesList(Data(#"[{"name":"S","series_id":55}]"#.utf8), host: "h")
        let episodes = try XtreamClient.decodeSeriesInfo(Data(#"{"episodes":[{"id":55}]}"#.utf8), host: "h")
        let live = try JSONDecoder().decode(XtreamLiveStream.self, from: Data(#"{"name":"L","stream_id":55}"#.utf8))
        let http = XtreamClient(credentials: .init(server: try #require(URL(string: "http://h:8080")), username: "u", password: "p"))
        let https = XtreamClient(credentials: .init(server: try #require(URL(string: "https://h:8443")), username: "u", password: "p"))

        #expect(http.channel(from: live, categoryName: nil).id == "xtream#h#55")
        #expect(https.channel(from: live, categoryName: nil).id == "xtream#h#55")
        #expect(first.items.first?.id == "xtream#h#vod#55")
        #expect(series.items.first?.id == "xtream#h#series#55")
        #expect(episodes.episodes.first?.id == "xtream#h#episode#55")
    }

    @Test(
        "0016/AC-13a title id round trip",
        arguments: [
            ("xtream#h#55", XtreamTitleID.Kind.live), ("xtream#h#vod#55", .vod), ("xtream#h#series#55", .series),
            ("xtream#h#episode#55", .episode),
        ])
    func titleIDParses(string: String, kind: XtreamTitleID.Kind) throws {
        let id = try #require(XtreamTitleID(parsing: string))
        #expect(id.host == "h")
        #expect(id.kind == kind)
        #expect(id.rawID == 55)
        #expect(id.description == string)
    }

    @Test(
        "0016/AC-13a malformed title ids are nil",
        arguments: ["xtream#h#vod#abc", "xtream#h#movie#55", "xtream##55", "m3u#x", "xtream#h#vod#055", "xtream#h#+55"])
    func titleIDRejects(string: String) {
        #expect(XtreamTitleID(parsing: string) == nil)
    }
}
