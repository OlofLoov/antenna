import Foundation
import Testing

@testable import AntennaCore

@Suite struct XtreamPanelLinkTests {
    @Test(
        "source-management/xtream-panel-playlist-links-are-recognized server, username and password",
        arguments: [
            (
                "http://tv.example.net:8080/get.php?username=anna&password=s3cret&type=m3u_plus&output=ts",
                "http://tv.example.net:8080", "anna", "s3cret"
            ),
            ("https://example.net/panel/get.php?username=anna&password=s3cret", "https://example.net/panel", "anna", "s3cret"),
            ("  HTTP://Example.net/GET.PHP?password=p%26q&username=a%20b  ", "http://Example.net", "a b", "p&q"),
        ])
    func recognized(link: String, server: String, username: String, password: String) throws {
        let panel = try #require(XtreamPanelLink(link))
        #expect(panel.credentials.server.absoluteString == server)
        #expect(panel.credentials.username == username)
        #expect(panel.credentials.password == password)
    }

    @Test(
        "source-management/xtream-panel-playlist-links-are-recognized other links are not panels",
        arguments: [
            "http://tv.example.net/playlist.m3u",
            "http://tv.example.net/get.php?username=anna",
            "http://tv.example.net/get.php?username=&password=p",
            "http://tv.example.net/xmltv.php?username=anna&password=p",
            "ftp://tv.example.net/get.php?username=anna&password=p",
            "get.php?username=anna&password=p",
            "not a link",
        ])
    func notPanels(link: String) {
        #expect(XtreamPanelLink(link) == nil)
    }

    @Test("source-management/xtream-panel-playlist-links-are-recognized logs show the host only")
    func hostOnly() throws {
        let panel = try #require(XtreamPanelLink("http://tv.example.net/get.php?username=anna&password=s3cret"))
        let shown = ["\(panel)", String(reflecting: panel), String(describing: Mirror(reflecting: panel).children.map(\.value))]
        for text in shown {
            #expect(!text.contains("s3cret"))
            #expect(!text.contains("anna"))
        }
    }

    @Test("source-management/xtream-panel-playlist-links-are-recognized the guide link is the panel's xmltv.php")
    func guide() throws {
        let panel = try #require(XtreamPanelLink("https://example.net/panel/get.php?username=anna&password=s3cret"))
        #expect(panel.guideURL.absoluteString == "https://example.net/panel/xmltv.php?username=anna&password=s3cret")
    }

    @Test("source-management/a-playlist-source-switches-to-xtream-in-place live channels map to their Xtream ids")
    func liveIDs() throws {
        let panel = try #require(XtreamPanelLink("http://tv.example.net:8080/get.php?username=anna&password=s3cret"))
        func channel(_ id: String, _ link: String) throws -> Channel {
            Channel(id: id, name: id, streamURL: try #require(URL(string: link)))
        }
        let channels = [
            try channel("a", "http://tv.example.net:8080/live/anna/s3cret/101.ts"),
            try channel("b", "http://tv.example.net:8080/anna/s3cret/102"),
            try channel("c", "http://tv.example.net:8080/anna/newpass/103.m3u8"),
            try channel("movie", "http://tv.example.net:8080/movie/anna/s3cret/900.mkv"),
            try channel("series", "http://tv.example.net:8080/series/anna/s3cret/901.mp4"),
            try channel("other", "http://cdn.example.org/live/anna/s3cret/104.ts"),
            try channel("named", "http://tv.example.net:8080/live/anna/s3cret/news.ts"),
        ]
        let map = panel.liveChannelIDs(for: channels)
        #expect(
            map == [
                "a": "xtream#tv.example.net#101",
                "b": "xtream#tv.example.net#102",
                "c": "xtream#tv.example.net#103",
            ])
    }

    @Test("source-management/a-playlist-source-switches-to-xtream-in-place a panel under a path maps links under it")
    func liveIDsUnderPath() throws {
        let panel = try #require(XtreamPanelLink("https://example.net/panel/get.php?username=anna&password=s3cret"))
        let inside = Channel(id: "a", name: "A", streamURL: try #require(URL(string: "https://example.net/panel/live/anna/s3cret/7.ts")))
        let outside = Channel(id: "b", name: "B", streamURL: try #require(URL(string: "https://example.net/live/anna/s3cret/8.ts")))
        #expect(panel.liveChannelIDs(for: [inside, outside]) == ["a": "xtream#example.net#7"])
    }

    @Test("source-management/the-add-form-offers-xtream-for-a-panel-link Use Xtream fills the login and keeps the name")
    func useXtream() {
        var fields = SourceFields(
            kind: .m3u, name: "Home", url: "http://tv.example.net:8080/get.php?username=anna&password=s3cret&type=m3u_plus")
        #expect(fields.xtreamPanel != nil)
        fields.useXtream()
        #expect(
            fields == SourceFields(kind: .xtream, name: "Home", url: "http://tv.example.net:8080", username: "anna", password: "s3cret"))
        #expect(fields.xtreamPanel == nil)
    }

    @Test("source-management/the-add-form-offers-xtream-for-a-panel-link no offer for an ordinary link or another type")
    func noOffer() {
        #expect(SourceFields(kind: .m3u, url: "http://tv.example.net/list.m3u").xtreamPanel == nil)
        #expect(SourceFields(kind: .xtream, url: "http://tv.example.net/get.php?username=a&password=b").xtreamPanel == nil)
        var fields = SourceFields(kind: .m3u, url: "http://tv.example.net/list.m3u")
        fields.useXtream()
        #expect(fields.kind == .m3u)
    }
}

@Suite struct PanelGuideTests {
    private let panelLink = URL(string: "http://tv.example.net:8080/get.php?username=anna&password=s3cret")

    @Test("guide-data/a-panel-playlist-falls-back-to-the-panel-s-guide resolved without a link of its own")
    func resolver() throws {
        let link = try #require(panelLink)
        let header = try #require(URL(string: "http://epg.example/head.xml"))
        let entered = try #require(URL(string: "http://epg.example/mine.xml"))
        func resolve(_ kind: SourceKind, epg: URL?, header: [URL]) -> String? {
            GuideURLResolver.resolve(kind: kind, url: link, epgURL: epg, playlistEPGURLs: header, credential: nil)?.absoluteString
        }
        #expect(resolve(.m3u, epg: nil, header: []) == "http://tv.example.net:8080/xmltv.php?username=anna&password=s3cret")
        #expect(resolve(.m3u, epg: entered, header: []) == entered.absoluteString)
        #expect(resolve(.m3u, epg: nil, header: [header]) == header.absoluteString)
        #expect(resolve(.m3uFile, epg: nil, header: []) == nil)
        let plain = try #require(URL(string: "http://tv.example.net/list.m3u"))
        #expect(GuideURLResolver.resolve(kind: .m3u, url: plain, epgURL: nil, playlistEPGURLs: [], credential: nil) == nil)
    }

    @Test("guide-data/a-panel-playlist-falls-back-to-the-panel-s-guide listed as the provider guide, off behind other links")
    func list() throws {
        let link = try #require(panelLink)
        let guide = try #require(XtreamPanelLink(link)?.guideURL)
        let header = try #require(URL(string: "http://epg.example/head.xml"))
        let saved = try #require(URL(string: "http://epg.example/mine.xml"))

        let alone = GuideList.resolve(kind: .m3u, savedURL: nil, playlistLinks: [], settings: .empty, panelGuide: guide)
        #expect(alone == [GuideListEntry(reference: .provider, enabled: true, url: guide)])

        let withSaved = GuideList.resolve(kind: .m3u, savedURL: saved, playlistLinks: [], settings: .empty, panelGuide: guide)
        #expect(withSaved.map(\.reference) == [.saved, .provider])
        #expect(withSaved.map(\.enabled) == [true, false])

        let withHeader = GuideList.resolve(kind: .m3u, savedURL: nil, playlistLinks: [header], settings: .empty, panelGuide: guide)
        #expect(withHeader.map(\.reference) == [.playlist(0), .provider])
        #expect(withHeader.map(\.enabled) == [true, false])
    }

    @Test("guide-data/a-panel-playlist-falls-back-to-the-panel-s-guide downloads the panel's guide with the login redacted in logs")
    func engineLoads() async throws {
        let world = GuideWorld()
        let host = "panel-guide.example"
        let link = try #require(URL(string: "http://\(host)/get.php?username=anna&password=s3cret&type=m3u_plus"))
        let source = GuideSourceDescriptor(sourceID: UUID(), kind: .m3u, url: link, epgURL: nil, credentialKey: nil, sortOrder: 0)
        world.sources = [source]
        GuideStubProtocol.register(host: host, body: try guideFixture("guide.xmltv"))
        let engine = world.engine()
        await engine.register(epgURLs: [], for: source.sourceID)
        await engine.refreshIfStale(now: world.now)
        await engine.idle()

        let requests = GuideStubProtocol.requests(host: host)
        #expect(requests.count == 1)
        #expect(requests.first?.url?.absoluteString == "http://\(host)/xmltv.php?username=anna&password=s3cret")
        #expect(await engine.index.loadingState(for: GuideKey(sourceID: source.sourceID, epgID: "news.se")) == .loaded)
        #expect(!world.log.all.contains { $0.contains("s3cret") || $0.contains("anna") })
    }
}
