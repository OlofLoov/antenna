import Foundation
import Testing

@testable import AntennaCore

/// Category rows panels send broken, and loads whose category call fails.
@Suite struct XtreamCategoryRowTests {
    private static let brokenRows =
        #"[{"category_id":1,"category_name":"A"},{"category_id":2,"category_name":null},{"category_id":null,"category_name":"X"},"#
        + #"{"category_id":3},{"category_name":"Y"},{"category_id":4,"category_name":2024},"x",{"category_id":"5","category_name":"E"}]"#

    @Test(
        "xtream-vod-client/broken-category-rows-are-skipped rows without an id or a name are dropped and a number name is kept",
        arguments: ["get_live_categories", "get_vod_categories", "get_series_categories"])
    // The live list also proves xtream-live-source/category-id-as-number-or-string.
    func brokenRowsDropped(action: String) async throws {
        let host = "cat-rows-\(action.replacingOccurrences(of: "_", with: "-")).panel"
        XtreamActionStub.register(host: host, action: action, body: Self.brokenRows)
        let client = try XtreamTimeZoneTests.client(host: host)
        let categories: [XtreamCategory] =
            switch action {
            case "get_live_categories": try await client.liveCategories()
            case "get_vod_categories": try await client.vodCategories()
            default: try await client.seriesCategories()
            }
        #expect(categories.map(\.categoryID) == ["1", "4", "5"])
        #expect(categories.map(\.categoryName) == ["A", "2024", "E"])
    }

    @Test("xtream-live-source/channels-load-without-categories a broken or failed category call leaves channels without groups")
    func liveWithoutCategories() async throws {
        for (name, status, body) in [("failed", 500, ""), ("html", 200, "<html>Error</html>")] {
            let host = "cat-live-\(name).panel"
            XtreamActionStub.register(host: host, action: "get_live_categories", status: status, body: body)
            XtreamActionStub.register(
                host: host, action: "get_live_streams", body: #"[{"stream_id":42,"name":"A","category_id":"1"}]"#)
            XtreamActionStub.register(host: host, action: nil, body: #"{"user_info":{"auth":1}}"#)
            let load = try await XtreamTimeZoneTests.client(host: host).liveLoad()
            #expect(load.channels.map(\.name) == ["A"])
            #expect(load.channels.first?.group == nil)
        }
    }

    @Test("xtream-live-source/channels-load-without-categories one bad row keeps the other groups")
    func liveWithOneBadRow() async throws {
        let host = "cat-live-row.panel"
        XtreamActionStub.register(
            host: host, action: "get_live_categories",
            body: #"[{"category_id":"1","category_name":"News"},{"category_id":"2","category_name":null}]"#)
        XtreamActionStub.register(
            host: host, action: "get_live_streams",
            body: #"[{"stream_id":42,"name":"A","category_id":"1"},{"stream_id":43,"name":"B","category_id":"2"}]"#)
        XtreamActionStub.register(host: host, action: nil, body: #"{"user_info":{"auth":1}}"#)
        let load = try await XtreamTimeZoneTests.client(host: host).liveLoad()
        #expect(load.channels.map(\.group) == ["News", nil])
    }

    @Test("xtream-vod-client/broken-category-rows-are-skipped movies and series load when the category call fails")
    func libraryWithoutCategories() async throws {
        let host = "cat-library.panel"
        XtreamActionStub.register(host: host, action: "get_vod_categories", status: 500, body: "")
        XtreamActionStub.register(host: host, action: "get_series_categories", status: 200, body: "<html></html>")
        XtreamActionStub.register(host: host, action: "get_vod_streams", body: #"[{"stream_id":7,"name":"Film","category_id":"1"}]"#)
        XtreamActionStub.register(host: host, action: "get_series", body: #"[{"series_id":9,"name":"Show","category_id":"1"}]"#)
        let client = try XtreamTimeZoneTests.client(host: host)
        let movies = try await client.vodLoad()
        #expect(movies.titles.items.map(\.name) == ["Film"])
        #expect(movies.categories.isEmpty)
        let series = try await client.seriesLoad()
        #expect(series.titles.items.map(\.name) == ["Show"])
        #expect(series.categories.isEmpty)
    }

    @Test("xtream-vod-client/broken-category-rows-are-skipped a failed title call still fails the load")
    func titlesFailing() async throws {
        let host = "cat-library-titles.panel"
        XtreamActionStub.register(host: host, action: "get_vod_categories", body: #"[{"category_id":1,"category_name":"A"}]"#)
        XtreamActionStub.register(host: host, action: "get_vod_streams", status: 500, body: "")
        await #expect(throws: XtreamClient.XtreamError.badStatus(500)) {
            _ = try await XtreamTimeZoneTests.client(host: host).vodLoad()
        }
    }

    @Test("guide-data/programmes-land-on-the-right-channels a guide id sent as a number is read as text")
    func numericGuideID() throws {
        let stream = try JSONDecoder().decode(
            XtreamLiveStream.self, from: Data(#"{"stream_id":42,"name":"A","epg_channel_id":1234}"#.utf8))
        #expect(stream.epgChannelID == "1234")
        let none = try JSONDecoder().decode(XtreamLiveStream.self, from: Data(#"{"stream_id":42,"name":"A","epg_channel_id":null}"#.utf8))
        #expect(none.epgChannelID == nil)
    }
}
