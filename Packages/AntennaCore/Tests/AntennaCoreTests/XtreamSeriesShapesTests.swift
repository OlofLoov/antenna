import Foundation
import Testing

@testable import AntennaCore

/// Series bodies seen on real panels that the first decoder turned into
/// "Could not load episodes" or an empty list.
@Suite struct XtreamSeriesShapesTests {
    private let host = "H"

    @Test("xtream-vod-client/episodes-flatten an array of season arrays gives each season's episodes")
    func seasonArrays() throws {
        let info = try XtreamClient.decodeSeriesInfo(try xtreamFixture("series_info_season_arrays.json"), host: host)
        #expect(info.episodes.map(\.episodeID) == [900, 902, 901, 903])
        #expect(info.episodes.map(\.season) == [0, 1, 1, 2])
        #expect(info.episodes.map(\.number) == [1, 1, 2, 1])
        #expect(info.episodes.map(\.containerExtension) == ["mkv", "mkv", "mkv", nil])
        #expect(info.skippedEpisodes == 0)
        #expect(info.plot == nil)
    }

    @Test("xtream-vod-client/episodes-flatten a season keyed by episode number, or one episode object, gives its episodes")
    func episodesByNumber() throws {
        let info = try XtreamClient.decodeSeriesInfo(try xtreamFixture("series_info_episodes_by_number.json"), host: host)
        #expect(info.plot == "P")
        #expect(info.episodes.map(\.episodeID) == [10, 11, 20])
        #expect(info.episodes.map(\.season) == [1, 1, 2])
        #expect(info.skippedEpisodes == 1)
    }

    // xtream-vod-client/episodes-flatten
    @Test("an array mixing episodes and season arrays keeps both")
    func mixedArray() throws {
        let body = #"{"episodes":[{"id":1,"season":3,"title":"A"},[{"id":2,"title":"B"}]]}"#
        let info = try XtreamClient.decodeSeriesInfo(Data(body.utf8), host: host)
        #expect(info.episodes.map(\.episodeID) == [2, 1])
        #expect(info.episodes.map(\.season) == [1, 3])
    }

    @Test("xtream-vod-client/panel-bodies-that-are-almost-json a PHP notice, Latin-1 text, raw tabs and trailing text still decode")
    func phpNoticeBody() throws {
        let info = try XtreamClient.decodeSeriesInfo(try xtreamFixture("series_info_php_notice.txt"), host: host)
        #expect(info.plot == "Café owner\u{2019}s story\tline one\nline two")
        #expect(info.genre == "Drama")
        #expect(info.episodes.map(\.episodeID) == [41])
        #expect(info.episodes.first?.title == "År ett")
        #expect(info.episodes.first?.containerExtension == "mkv")
    }

    @Test("xtream-vod-client/panel-bodies-that-are-almost-json a byte-order mark before a list or info body is ignored")
    func byteOrderMark() throws {
        let mark = Data([0xEF, 0xBB, 0xBF])
        let list = try XtreamClient.decodeSeriesList(mark + Data(#"[{"name":"S","series_id":7}]"#.utf8), host: host)
        #expect(list.items.map(\.seriesID) == [7])
        let info = try XtreamClient.decodeSeriesInfo(mark + Data(#"{"episodes":{"1":[{"id":5}]}}"#.utf8), host: host)
        #expect(info.episodes.map(\.episodeID) == [5])
        #expect(throws: XtreamClient.XtreamError.unauthorized) {
            _ = try XtreamClient.decodeSeriesInfo(mark + Data(#"{"user_info":{"auth":0}}"#.utf8), host: host)
        }
    }

    @Test("xtream-vod-client/panel-bodies-that-are-almost-json a web page still fails", arguments: ["html", "doctype"])
    func webPageStillFails(kind: String) throws {
        let data =
            kind == "html"
            ? try xtreamFixture("html_login.html")
            : Data("<!DOCTYPE html><html><script>var a = {\"episodes\":[]};</script></html>".utf8)
        #expect(throws: XtreamClient.XtreamError.decoding(path: "")) { _ = try XtreamClient.decodeSeriesInfo(data, host: host) }
    }

    @Test("xtream-vod-client/panel-bodies-that-are-almost-json a clean body is passed through untouched")
    func cleanBodyUntouched() throws {
        let data = try xtreamFixture("series_info_dict.json")
        #expect(XtreamBody.readable(data) == data)
        #expect(XtreamBody.readable(Data("false".utf8)) == Data("false".utf8))
        #expect(XtreamBody.readable(Data()) == Data())
    }

    @Test("xtream-vod-client/panel-bodies-that-are-almost-json control characters are escaped only inside strings")
    func controlCharacters() throws {
        let fixed = XtreamBody.readable(Data("{\"a\":\"x\u{1}y\",\u{1}\"b\":\"\\\"\t\"}".utf8))
        #expect(String(decoding: fixed, as: UTF8.self) == #"{"a":"x\u0001y","b":"\"\u0009"}"#)
    }

    @Test("title-detail-and-episode-picker/when-details-or-episodes-do-not-load the logged reason names no address or login")
    func failureReasons() {
        #expect(LoadFailureReason.text(for: XtreamClient.XtreamError.badStatus(503)) == "status 503")
        #expect(LoadFailureReason.text(for: XtreamClient.XtreamError.transport(.timedOut)) == "transport -1001")
        #expect(LoadFailureReason.text(for: XtreamClient.XtreamError.decoding(path: "")) == "decoding body")
        #expect(LoadFailureReason.text(for: XtreamClient.XtreamError.decoding(path: "episodes")) == "decoding at episodes")
        #expect(LoadFailureReason.text(for: XtreamClient.XtreamError.unauthorized) == "unauthorized")
        let withAddress = URLError(.badServerResponse, userInfo: [NSURLErrorFailingURLStringErrorKey: "http://h/u/secret"])
        #expect(LoadFailureReason.text(for: withAddress) == "transport -1011")
        #expect(LoadFailureReason.isOffline(XtreamClient.XtreamError.transport(.notConnectedToInternet)))
        #expect(!LoadFailureReason.isOffline(XtreamClient.XtreamError.transport(.timedOut)))
    }
}
