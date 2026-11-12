import Foundation
import Testing

@testable import AntennaCore

/// A guide with one 20:00–21:00 programme titled `title` per id, and a
/// channel element named after each id unless `names` says otherwise.
func guideXML(_ ids: [String], title: String, names: [String: String] = [:]) -> Data {
    var body = "<tv>"
    for id in ids {
        body += "<channel id=\"\(id)\"><display-name>\(names[id] ?? id)</display-name></channel>"
    }
    for id in ids {
        body +=
            "<programme start=\"20261103200000 +0000\" stop=\"20261103210000 +0000\" channel=\"\(id)\"><title>\(title)</title></programme>"
    }
    return Data((body + "</tv>").utf8)
}

@Suite(.timeLimit(.minutes(1))) struct GuideSourcesEngineTests {
    private func link(_ host: String) -> URL {
        URL(filePath: "/").settingHTTP(host: host).appending(path: "guide.xml")
    }

    private func title(_ index: GuideIndex, _ source: GuideSourceDescriptor, _ id: String) -> String? {
        index.current(for: GuideKey(sourceID: source.sourceID, epgID: id), at: guideTime(20, 30))?.title
    }

    /// An M3U source with no saved link whose header names `hosts`.
    private func playlist(_ world: GuideWorld, _ engine: GuideEngine, hosts: [String]) async -> GuideSourceDescriptor {
        let source = world.add(.m3u, host: "\(hosts[0]).playlist", link: false)
        await engine.register(epgURLs: hosts.map(link), for: source.sourceID)
        return source
    }

    private func setSettings(_ world: GuideWorld, _ source: GuideSourceDescriptor, _ settings: GuideSettings) {
        world.sources = world.sources.map { item in
            var item = item
            if item.sourceID == source.sourceID { item.settings = settings }
            return item
        }
    }

    @Test("guide-sources-and-channel-mapping/every-guide-a-playlist-names-is-used each header link and the saved link load once")
    func everyGuide() async throws {
        let world = GuideWorld()
        let engine = world.engine()
        GuideStubProtocol.register(host: "gs-every-a.epg", body: guideXML(["a"], title: "From A"))
        GuideStubProtocol.register(host: "gs-every-b.epg", body: guideXML(["b"], title: "From B"))
        GuideStubProtocol.register(host: "gs-every-saved.epg", body: guideXML(["c"], title: "From saved"))
        var source = await playlist(world, engine, hosts: ["gs-every-a.epg", "gs-every-b.epg", "gs-every-a.epg"])
        source.epgURL = link("gs-every-saved.epg")
        world.sources = [source]

        await engine.refreshIfStale(now: world.now)
        await engine.idle()

        #expect(GuideStubProtocol.requests(host: "gs-every-a.epg").count == 1)
        #expect(GuideStubProtocol.requests(host: "gs-every-b.epg").count == 1)
        #expect(GuideStubProtocol.requests(host: "gs-every-saved.epg").count == 1)
        let index = await engine.index
        #expect(title(index, source, "a") == "From A")
        #expect(title(index, source, "b") == "From B")
        #expect(title(index, source, "c") == "From saved")
        let rows = await engine.sourceStatuses[source.sourceID]?.rows.map(\.reference)
        #expect(rows == [.playlist(0), .playlist(1), .saved])
    }

    @Test("guide-sources-and-channel-mapping/every-guide-a-playlist-names-is-used the guide at each position follows the header")
    func headerReorder() async throws {
        let world = GuideWorld()
        let engine = world.engine()
        GuideStubProtocol.register(host: "gs-reorder-a.epg", body: guideXML(["x"], title: "From A"))
        GuideStubProtocol.register(host: "gs-reorder-b.epg", body: guideXML(["x"], title: "From B"))
        let source = await playlist(world, engine, hosts: ["gs-reorder-a.epg", "gs-reorder-b.epg"])
        await engine.refreshIfStale(now: world.now)
        await engine.idle()
        #expect(title(await engine.index, source, "x") == "From A")

        await engine.register(epgURLs: [link("gs-reorder-b.epg"), link("gs-reorder-a.epg")], for: source.sourceID)
        await engine.refreshIfStale(now: world.now)
        await engine.idle()
        #expect(title(await engine.index, source, "x") == "From B")
    }

    @Test("guide-sources-and-channel-mapping/choose-which-guide-wins moving a guide up needs no download")
    func reorder() async throws {
        let world = GuideWorld()
        let engine = world.engine()
        GuideStubProtocol.register(host: "gs-win-a.epg", body: guideXML(["x", "empty"], title: "From A"))
        GuideStubProtocol.register(
            host: "gs-win-b.epg",
            body: Data(
                """
                <tv><channel id="empty"><display-name>Empty</display-name></channel>
                <programme start="20261103200000 +0000" stop="20261103210000 +0000" channel="x"><title>From B</title></programme></tv>
                """.utf8))
        let source = await playlist(world, engine, hosts: ["gs-win-b.epg", "gs-win-a.epg"])
        await engine.refreshIfStale(now: world.now)
        await engine.idle()
        #expect(title(await engine.index, source, "x") == "From B")
        #expect(title(await engine.index, source, "empty") == "From A")

        setSettings(world, source, GuideSettings(order: ["playlist.1", "playlist.0"], orderModifiedAt: world.now))
        await engine.settingsChanged()
        await engine.idle()
        #expect(title(await engine.index, source, "x") == "From A")
        #expect(GuideStubProtocol.requests(host: "gs-win-a.epg").count == 1)
        #expect(GuideStubProtocol.requests(host: "gs-win-b.epg").count == 1)
    }

    @Test("guide-sources-and-channel-mapping/turn-off-or-remove-a-guide a turned-off guide leaves and is not downloaded")
    func turnOff() async throws {
        let world = GuideWorld()
        let engine = world.engine()
        GuideStubProtocol.register(host: "gs-off-a.epg", body: guideXML(["x", "only-a"], title: "From A"))
        GuideStubProtocol.register(host: "gs-off-b.epg", body: guideXML(["x"], title: "From B"))
        let source = await playlist(world, engine, hosts: ["gs-off-a.epg", "gs-off-b.epg"])
        await engine.refreshIfStale(now: world.now)
        await engine.idle()

        let off = GuideSettings(flags: ["playlist.0": GuideSettings.Flag(enabled: false, modifiedAt: world.now)])
        setSettings(world, source, off)
        await engine.settingsChanged()
        let index = await engine.index
        #expect(title(index, source, "x") == "From B")
        #expect(title(index, source, "only-a") == nil)
        #expect(await engine.sourceStatuses[source.sourceID]?.rows.first?.status == .off)

        await engine.refresh(sourceID: source.sourceID)
        await engine.idle()
        #expect(GuideStubProtocol.requests(host: "gs-off-a.epg").count == 1)
        #expect(GuideStubProtocol.requests(host: "gs-off-b.epg").count == 2)
    }

    @Test("guide-sources-and-channel-mapping/one-broken-guide-does-not-break-the-others a failing guide shows on its row only")
    func oneBroken() async throws {
        let world = GuideWorld()
        let engine = world.engine()
        let tap = ProgressTap(engine.progressStream())
        GuideStubProtocol.register(host: "gs-broken-a.epg", .http(status: 404, chunks: []))
        GuideStubProtocol.register(host: "gs-broken-b.epg", body: guideXML(["x"], title: "From B"))
        let source = await playlist(world, engine, hosts: ["gs-broken-a.epg", "gs-broken-b.epg"])
        await engine.refreshIfStale(now: world.now)
        await engine.idle()

        #expect(title(await engine.index, source, "x") == "From B")
        let rows = try #require(await engine.sourceStatuses[source.sourceID]?.rows)
        #expect(rows.first?.status == .failed(.httpStatus(404)))
        if case .loaded = rows.last?.status {} else { Issue.record("second guide not loaded: \(rows)") }
        try await tap.wait { $0.contains(where: isLoaded) }
        #expect(!tap.of(source).contains(where: isFailed))
    }

    @Test("guide-data/programmes-land-on-the-right-channels a hand-picked entry and a match by name")
    func matches() async throws {
        let world = GuideWorld()
        let engine = world.engine()
        GuideStubProtocol.register(
            host: "gs-match.epg",
            body: guideXML(["sport1.se", "news"], title: "On air", names: ["sport1.se": "Sport One", "news": "News"]))
        var source = world.add(.m3u, host: "gs-match.epg")
        let picked = Channel(id: "m3u.picked", name: "Something", streamURL: URL(filePath: "/p"), sourceID: source.sourceID)
        let named = Channel(id: "m3u.named", name: "Sport One HD", streamURL: URL(filePath: "/n"), sourceID: source.sourceID)
        source.settings = GuideSettings(matches: ["m3u.picked": GuideSettings.Match(entryID: "news", modifiedAt: world.now)])
        world.sources = [source]
        engine.update(channels: [picked, named])
        await engine.register(epgURLs: [], for: source.sourceID)
        await engine.refreshIfStale(now: world.now)
        await engine.idle()

        var index = await engine.index
        #expect(index.key(for: picked) == GuideKey(sourceID: source.sourceID, epgID: "news"))
        #expect(index.match(for: picked)?.origin == .user)
        #expect(index.key(for: named) == GuideKey(sourceID: source.sourceID, epgID: "sport1.se"))
        #expect(index.match(for: named)?.origin == .name)
        #expect(index.loadingState(for: named) == .loaded)

        // guide-sources-and-channel-mapping/channels-matched-by-name an undo keeps the channel unmatched
        source.settings.matches["m3u.named"] = GuideSettings.Match(entryID: nil, modifiedAt: world.now)
        world.sources = [source]
        await engine.settingsChanged()
        index = await engine.index
        #expect(index.key(for: named) == nil)
        #expect(index.loadingState(for: named) == .noData)
    }
}
