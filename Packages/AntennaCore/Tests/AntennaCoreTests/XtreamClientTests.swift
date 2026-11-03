import Foundation
import Testing
@testable import AntennaCore

@Suite struct XtreamClientTests {
    let creds = XtreamCredentials(server: URL(string: "http://panel.example:8080")!, username: "u", password: "p")

    @Test func decodesLooseTypes() throws {
        let json = #"[{"num":"7","name":"BBC One","stream_id":"42","stream_icon":"","epg_channel_id":"bbc1.uk","category_id":3,"tv_archive":"1","tv_archive_duration":3}]"#
        let streams = try JSONDecoder().decode([XtreamLiveStream].self, from: Data(json.utf8))
        let s = try #require(streams.first)
        #expect(s.num == 7)
        #expect(s.streamID == 42)
        #expect(s.categoryID == "3")
        #expect(s.tvArchive == 1)
    }

    @Test func buildsStreamAndEPGURLs() throws {
        let json = #"{"name":"BBC One","stream_id":42}"#
        let s = try JSONDecoder().decode(XtreamLiveStream.self, from: Data(json.utf8))
        let client = XtreamClient(credentials: creds)
        #expect(client.streamURL(for: s).absoluteString == "http://panel.example:8080/live/u/p/42.ts")
        #expect(client.streamURL(for: s, container: .m3u8).absoluteString == "http://panel.example:8080/live/u/p/42.m3u8")
        #expect(client.xmltvURL().absoluteString == "http://panel.example:8080/xmltv.php?username=u&password=p")

        let ch = client.channel(from: s, categoryName: "UK")
        #expect(ch.group == "UK")
        #expect(ch.id == "xtream#panel.example#42")
    }

    @Test func routerSplitsHLSFromTS() {
        #expect(EngineRouter.route(for: URL(string: "http://x/a.m3u8")!) == .system)
        #expect(EngineRouter.route(for: URL(string: "http://x/a.ts")!) == .demuxer)
        #expect(EngineRouter.route(for: URL(string: "http://x/live/u/p/42")!) == .demuxer)
    }
}
