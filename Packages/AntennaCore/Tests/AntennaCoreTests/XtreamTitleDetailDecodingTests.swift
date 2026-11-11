import Foundation
import Testing

@testable import AntennaCore

/// The fields the title page reads from `get_vod_info` and `get_series_info`.
@Suite struct XtreamTitleDetailDecodingTests {
    private let host = "H"

    private func vodInfo(_ info: String) throws -> VODInfo {
        try XtreamClient.decodeVODInfo(Data("{\"info\":{\(info)}}".utf8), host: host)
    }

    @Test("xtream-vod-client/vod-info cast, director and rating from a full body")
    func castDirectorRating() throws {
        let info = try vodInfo(#""cast":"Mira Holt, Jonas Reeve","director":"Sanna Weiss","rating":"7.4","youtube_trailer":"dQw4w9WgXcQ""#)
        #expect(info.cast == "Mira Holt, Jonas Reeve")
        #expect(info.director == "Sanna Weiss")
        #expect(info.rating == 7.4)
        #expect(info.trailerURL == URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ"))

        let series = try XtreamClient.decodeSeriesInfo(
            Data(#"{"info":{"cast":"A, B","director":"C","rating":8.1,"youtube_trailer":"https://t.example/x"}}"#.utf8), host: host)
        #expect(series.cast == "A, B")
        #expect(series.director == "C")
        #expect(series.rating == 8.1)
        #expect(series.trailerURL == URL(string: "https://t.example/x"))
    }

    @Test("xtream-vod-client/vod-info actors stand in for a missing cast")
    func actorsFallback() throws {
        #expect(try vodInfo(#""actors":"Mira Holt""#).cast == "Mira Holt")
        #expect(try vodInfo(#""cast":"  ","actors":"Mira Holt""#).cast == "Mira Holt")
    }

    @Test("xtream-vod-client/vod-info a rating of 0 is no rating", arguments: ["0", #""0""#, #""0.0""#, #""""#, #""N/A""#, "null"])
    func zeroRating(rating: String) throws {
        #expect(try vodInfo("\"rating\":\(rating)").rating == nil)
    }

    @Test(
        "xtream-vod-client/vod-info trailer link",
        arguments: [
            ("https://www.youtube.com/watch?v=abc", "https://www.youtube.com/watch?v=abc"),
            ("http://v.example/t.mp4", "http://v.example/t.mp4"),
            ("dQw4w9WgXcQ", "https://www.youtube.com/watch?v=dQw4w9WgXcQ"),
            ("a-b_c1234XY", "https://www.youtube.com/watch?v=a-b_c1234XY"),
            ("dQw4w9WgXc", nil), ("dQw4w9WgXcQQ", nil), ("dQw4w9 gXcQ", nil), ("ftp://h/t", nil), ("", nil), ("javascript:x", nil),
        ] as [(String, String?)])
    func trailer(value: String, expected: String?) throws {
        #expect(try vodInfo("\"youtube_trailer\":\"\(value)\"").trailerURL == expected.flatMap(URL.init(string:)))
    }

    @Test("xtream-vod-client/vod-info missing new fields stay empty")
    func missingFields() throws {
        let info = try XtreamClient.decodeVODInfo(try xtreamFixture("vod_info.json"), host: host)
        #expect(info.cast == nil && info.director == nil && info.rating == nil && info.trailerURL == nil)
    }

    @Test("xtream-vod-client/episode-description-and-picture episode with and without details")
    func episodeDetails() throws {
        let body = #"""
            {"episodes":{"1":[
              {"id":1,"episode_num":1,"title":"A","info":{"plot":"The weir.","movie_image":"http://h/e1.jpg"}},
              {"id":2,"episode_num":2,"title":"B","info":{}},
              {"id":3,"episode_num":3,"title":"C","info":{"overview":"Ice.","cover_big":"https://h/e3.jpg"}},
              {"id":4,"episode_num":4,"title":"D","info":{"plot":"  ","movie_image":"e4.jpg"}},
              {"id":5,"episode_num":5,"title":"E"}
            ]}}
            """#
        let info = try XtreamClient.decodeSeriesInfo(Data(body.utf8), host: host)
        #expect(info.episodes.map(\.plot) == ["The weir.", nil, "Ice.", nil, nil])
        #expect(
            info.episodes.map(\.thumbnailURL) == [URL(string: "http://h/e1.jpg"), nil, URL(string: "https://h/e3.jpg"), nil, nil])
    }
}
