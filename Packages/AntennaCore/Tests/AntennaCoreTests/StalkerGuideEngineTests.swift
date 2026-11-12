import Foundation
import Testing

@testable import AntennaCore

@Suite(.timeLimit(.minutes(1))) struct StalkerGuideEngineTests {
    private struct Setup {
        var engine: GuideEngine
        var source: GuideSourceDescriptor
        var portal: FakePortal
        var log: Recorder<String>
    }

    /// A Stalker source with no guide link, served by `portal`, with two
    /// channels matched by the portal's channel ids 101 and 102.
    private func setup(host: String, portal: FakePortal, client hasClient: Bool = true) throws -> Setup {
        let client = try portal.client(host: host)
        let source = GuideSourceDescriptor(
            sourceID: UUID(), kind: .stalker, url: client.credentials.portal.url, credentialKey: "key-\(host)", sortOrder: 0)
        let log = Recorder<String>()
        let engine = GuideEngine(
            GuideEngine.Configuration(
                session: StalkerStubProtocol.session(), directory: temporaryGuideDirectory(), sources: { [source] },
                credential: { _ in .missing }, log: { log.append($0) }, now: { Date(timeIntervalSince1970: 1_794_470_000) },
                stalkerClient: { id in hasClient && id == source.sourceID ? client : nil }))
        let channels = ["101", "102"].map {
            Channel(id: "stalker#\(host)#\($0)", name: $0, streamURL: URL(filePath: "/\($0)"), epgID: $0, sourceID: source.sourceID)
        }
        engine.update(channels: channels)
        return Setup(engine: engine, source: source, portal: portal, log: log)
    }

    private static let window = DateInterval(start: Date(timeIntervalSince1970: 1_794_400_000), duration: 200_000)

    @Test("stalker-portal-source/the-portal-s-guide-fills-the-programme-grid programmes land on the right channels")
    func portalGuide() async throws {
        let host = "ge-portal.portal"
        let portal = FakePortal()
        let body = try stalkerFixture("epg_info.json")
        portal.on("get_epg_info") { _, _ in .http(200, body) }
        let setup = try setup(host: host, portal: portal)
        let tap = ProgressTap(setup.engine.progressStream())
        await setup.engine.refresh(sourceID: setup.source.sourceID)
        await setup.engine.idle()

        let keys = ["101", "102"].map { GuideKey(sourceID: setup.source.sourceID, epgID: $0) }
        let found = await setup.engine.index.programmes(for: keys, in: Self.window)
        #expect(found[keys[0]]?.map(\.title) == ["Morning News", "Noon News"])
        #expect(found[keys[1]]?.map(\.title) == ["Match"])
        let request = try #require(StalkerStubProtocol.requests(host: host).first { $0.action == "get_epg_info" })
        #expect(request.queryPairs.contains("period=168"))
        try await tap.wait { events in
            events.contains {
                if case .loaded(_, let withGuide, let total, _, let unmatched) = $0 {
                    return withGuide == 2 && total == 2 && unmatched == 1
                }
                return false
            }
        }
        #expect(setup.log.all.contains { $0.contains("skipped 3 portal rows") })
        #expect(!setup.log.all.joined().contains("load.php"))
    }

    @Test("guide-data/find-the-guide-for-each-source Stalker session turned down while loading the guide")
    func renewOnce() async throws {
        let host = "ge-renew.portal"
        let portal = FakePortal()
        let body = try stalkerFixture("epg_info.json")
        portal.on("get_epg_info") { _, request in request.bearer == "Bearer T1" ? .http(401, "") : .http(200, body) }
        let setup = try setup(host: host, portal: portal)
        await setup.engine.refresh(sourceID: setup.source.sourceID)
        await setup.engine.idle()
        #expect(portal.count("get_epg_info") == 2)
        #expect(portal.count("handshake") == 2)
        #expect(await setup.engine.index.loadingState(for: GuideKey(sourceID: setup.source.sourceID, epgID: "101")) == .loaded)
    }

    @Test("guide-data/find-the-guide-for-each-source a guide turned down twice fails as unauthorized")
    func turnedDownTwice() async throws {
        let host = "ge-refused.portal"
        let portal = FakePortal()
        portal.on("get_epg_info") { _, _ in .http(200, "Authorization failed.") }
        let setup = try setup(host: host, portal: portal)
        await setup.engine.refresh(sourceID: setup.source.sourceID)
        await setup.engine.idle()
        #expect(portal.count("get_epg_info") == 2)
        #expect(
            await setup.engine.index.loadingState(for: GuideKey(sourceID: setup.source.sourceID, epgID: "101")) == .failed(.unauthorized))
    }

    @Test("guide-data/find-the-guide-for-each-source a portal without its login on this device waits")
    func noClient() async throws {
        let host = "ge-no-client.portal"
        let setup = try setup(host: host, portal: FakePortal(), client: false)
        await setup.engine.refresh(sourceID: setup.source.sourceID)
        await setup.engine.idle()
        #expect(StalkerStubProtocol.requests(host: host).isEmpty)
        #expect(await setup.engine.index.loadingState(for: GuideKey(sourceID: setup.source.sourceID, epgID: "101")) == .unavailable)
    }

    @Test("guide-data/find-the-guide-for-each-source a portal source without a guide link uses the portal's guide")
    func resolver() throws {
        #expect(GuideURLResolver.usesPortalGuide(kind: .stalker, epgURL: nil))
        #expect(!GuideURLResolver.usesPortalGuide(kind: .stalker, epgURL: URL(string: "http://e.example/guide.xml")))
        #expect(!GuideURLResolver.usesPortalGuide(kind: .xtream, epgURL: nil))
    }
}
