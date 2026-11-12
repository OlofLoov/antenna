import Foundation
import Testing

@testable import AntennaCore

@Suite(.timeLimit(.minutes(1))) struct JellyfinGuideEngineTests {
    private struct Setup {
        var engine: GuideEngine
        var source: GuideSourceDescriptor
        var channels: [Channel]
    }

    private static let now = Date(timeIntervalSince1970: 1_794_484_800)  // 2026-11-12 12:00 UTC

    /// A Jellyfin source with no guide link and `count` channels served by
    /// `server`, matched by the server's channel ids.
    private func setup(host: String, server: FakeJellyfin, count: Int = 120, client hasClient: Bool = true) throws -> Setup {
        let client = try server.client(host: host)
        let source = GuideSourceDescriptor(
            sourceID: UUID(), kind: .jellyfin, url: client.credentials.server, credentialKey: "key-\(host)", sortOrder: 0)
        let engine = GuideEngine(
            GuideEngine.Configuration(
                session: GuideStubProtocol.session(), directory: temporaryGuideDirectory(), sources: { [source] },
                credential: { _ in .missing }, log: { _ in }, now: { Self.now },
                jellyfinClient: { id in hasClient && id == source.sourceID ? client : nil }))
        let channels = (0..<count).map {
            Channel(
                id: "jellyfin#\(host)#ch-\($0)", name: "\($0)", streamURL: URL(filePath: "/\($0)"), epgID: "ch-\($0)",
                sourceID: source.sourceID)
        }
        return Setup(engine: engine, source: source, channels: channels)
    }

    private func key(_ setup: Setup, _ id: String) -> GuideKey {
        GuideKey(sourceID: setup.source.sourceID, epgID: id)
    }

    @Test("guide-data/guide-from-a-source-that-serves-programmes-directly takes the guide from the server in batches")
    func batches() async throws {
        let host = "ge-jf-batches.local"
        let server = FakeJellyfin()
        let setup = try setup(host: host, server: server)
        let tap = ProgressTap(setup.engine.progressStream())
        setup.engine.update(channels: setup.channels)
        await setup.engine.refresh(sourceID: setup.source.sourceID)
        try await tap.wait { events in events.contains { if case .loaded = $0 { true } else { false } } }

        let fetching = tap.events.all.compactMap { event -> String? in
            if case .fetching(_, let done, let total) = event { return "\(done)/\(total)" }
            return nil
        }
        #expect(fetching == ["1/3", "2/3", "3/3"])
        let window = DateInterval(start: Self.now, duration: 3600)
        let found = await setup.engine.index.programmes(for: [key(setup, "ch-0"), key(setup, "ch-119")], in: window)
        #expect(found[key(setup, "ch-0")]?.map(\.title) == ["On ch-0"])
        #expect(found[key(setup, "ch-119")]?.map(\.title) == ["On ch-119"])
        let paths = Set(JellyfinStubProtocol.requests(host: host).map(\.path))
        #expect(paths == ["/Users/AuthenticateByName", "/LiveTv/Programs"])
        #expect(GuideStubProtocol.requests(host: host).isEmpty)
        let body = try #require(JellyfinStubProtocol.requests(host: host).last?.json)
        #expect(body["MinEndDate"] as? String == "2026-11-12T12:00:00Z")
        #expect(body["MaxStartDate"] as? String == "2026-11-19T12:00:00Z")
    }

    @Test("guide-data/guide-from-a-source-that-serves-programmes-directly waits for the channel list")
    func waitsForChannels() async throws {
        let host = "ge-jf-wait.local"
        let server = FakeJellyfin()
        let setup = try setup(host: host, server: server, count: 2)
        await setup.engine.refresh(sourceID: setup.source.sourceID)
        await setup.engine.idle()
        #expect(server.count("LiveTv/Programs") == 0)
        #expect(await setup.engine.index.loadingState(for: key(setup, "ch-0")) == .loading)

        let tap = ProgressTap(setup.engine.progressStream())
        setup.engine.update(channels: setup.channels)
        try await tap.wait { events in events.contains { if case .loaded = $0 { true } else { false } } }
        #expect(server.count("LiveTv/Programs") == 1)
        #expect(await setup.engine.index.loadingState(for: key(setup, "ch-1")) == .loaded)
    }

    @Test("guide-data/guide-from-a-source-that-serves-programmes-directly an offline refresh keeps the previous guide")
    func offlineKeepsGuide() async throws {
        let host = "ge-jf-offline.local"
        let server = FakeJellyfin()
        server.on("LiveTv/Programs") { index, _ in index == 0 ? nil : .failure(.notConnectedToInternet) }
        let setup = try setup(host: host, server: server, count: 2)
        let tap = ProgressTap(setup.engine.progressStream())
        setup.engine.update(channels: setup.channels)
        await setup.engine.refresh(sourceID: setup.source.sourceID)
        try await tap.wait { events in events.contains { if case .loaded = $0 { true } else { false } } }

        await setup.engine.refresh(sourceID: setup.source.sourceID)
        try await tap.wait { events in events.contains { if case .failed(_, .offline) = $0 { true } else { false } } }
        #expect(server.count("LiveTv/Programs") == 2)
        #expect(await setup.engine.index.loadingState(for: key(setup, "ch-0")) == .loaded)
    }

    @Test("guide-data/guide-from-a-source-that-serves-programmes-directly a server without its login on this device waits")
    func noClient() async throws {
        let host = "ge-jf-no-client.local"
        let setup = try setup(host: host, server: FakeJellyfin(), count: 2, client: false)
        setup.engine.update(channels: setup.channels)
        await setup.engine.refresh(sourceID: setup.source.sourceID)
        await setup.engine.idle()
        #expect(JellyfinStubProtocol.requests(host: host).isEmpty)
        #expect(await setup.engine.index.loadingState(for: key(setup, "ch-0")) == .unavailable)
    }
}
