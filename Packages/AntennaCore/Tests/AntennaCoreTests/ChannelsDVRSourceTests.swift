import Foundation
import Testing

@testable import AntennaCore

@Suite(.timeLimit(.minutes(1))) struct ChannelsDVRGuideEngineTests {
    private struct Setup {
        var engine: GuideEngine
        var source: GuideSourceDescriptor
        var channels: [Channel]
    }

    /// A Channels DVR source at `host` with the fixture lineup, its guide
    /// served by `guide`.
    private func setup(
        host: String, epgURL: URL? = nil, credentialKey: String? = nil, lookup: GuideCredentialLookup = .missing,
        limits: GuideLimits = .platform, guide: @escaping @Sendable (URLRequest) -> StalkerStubProtocol.Reply
    ) throws -> Setup {
        StalkerStubProtocol.register(host: host, handler: guide)
        let server = try #require(ChannelsDVRClient.serverURL(from: host))
        let source = GuideSourceDescriptor(sourceID: UUID(), kind: .channelsDVR, url: server, epgURL: epgURL, credentialKey: credentialKey)
        let configuration = URLSessionConfiguration.guide
        configuration.protocolClasses = [StalkerStubProtocol.self]
        let engine = GuideEngine(
            GuideEngine.Configuration(
                session: URLSession(configuration: configuration), directory: temporaryGuideDirectory(), limits: limits,
                sources: { [source] }, credential: { _ in lookup }, log: { _ in }))
        let channels = try ChannelsDVRClient.channels(fromPlaylist: FakeChannelsDVR.fixture("channels.m3u")).map {
            var tagged = $0
            tagged.sourceID = source.sourceID
            return tagged
        }
        engine.update(channels: channels)
        return Setup(engine: engine, source: source, channels: channels)
    }

    private static let window = DateInterval(start: Date(timeIntervalSince1970: 1_794_500_000), duration: 86_400)

    private func state(_ setup: Setup) async -> GuideLoadingState {
        await setup.engine.index.loadingState(for: GuideKey(sourceID: setup.source.sourceID, epgID: "nbc"))
    }

    @Test("guide-data/guide-address-worked-out-from-the-source a Channels DVR source with a proxy password")
    func serverGuideWithPassword() async throws {
        let host = "ge-dvr-proxy.dvr.test"
        let xml = String(decoding: try FakeChannelsDVR.fixture("xmltv.xml"), as: UTF8.self)
        let setup = try setup(host: host, credentialKey: "k", lookup: .found(username: "alice", password: "pa:ss")) { _ in
            .http(200, xml)
        }
        await setup.engine.refresh(sourceID: setup.source.sourceID)
        await setup.engine.idle()

        let request = try #require(StalkerStubProtocol.requests(host: host).first)
        #expect(request.url?.absoluteString == "http://ge-dvr-proxy.dvr.test:8089/devices/ANY/guide/xmltv.xml?duration=604800")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Basic " + Data("alice:pa:ss".utf8).base64EncodedString())
        #expect(await state(setup) == .loaded)
    }

    @Test("channels-dvr-source/the-guide-lines-up-without-manual-matching every programme lands on a channel")
    func everyProgrammeLands() async throws {
        let host = "ge-dvr-match.dvr.test"
        let xml = String(decoding: try FakeChannelsDVR.fixture("xmltv.xml"), as: UTF8.self)
        let setup = try setup(host: host) { _ in .http(200, xml) }
        await setup.engine.refresh(sourceID: setup.source.sourceID)
        await setup.engine.idle()

        let keys = setup.channels.compactMap { $0.epgID.map { GuideKey(sourceID: setup.source.sourceID, epgID: $0) } }
        let found = await setup.engine.index.programmes(for: keys, in: Self.window)
        #expect(found.values.reduce(0) { $0 + $1.count } == 6)
        #expect(keys.allSatisfy { found[$0]?.isEmpty == false })
        let request = try #require(StalkerStubProtocol.requests(host: host).first)
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test("channels-dvr-source/the-guide-lines-up-without-manual-matching a guide link set by hand wins")
    func handSetLinkWins() async throws {
        let host = "ge-dvr-hand.dvr.test"
        let own = "ge-dvr-own.guide.test"
        let xml = String(decoding: try FakeChannelsDVR.fixture("xmltv.xml"), as: UTF8.self)
        StalkerStubProtocol.register(host: own) { _ in .http(200, xml) }
        let setup = try setup(host: host, epgURL: URL(string: "http://\(own)/guide.xml")) { _ in .http(500, "") }
        await setup.engine.refresh(sourceID: setup.source.sourceID)
        await setup.engine.idle()
        #expect(StalkerStubProtocol.requests(host: host).isEmpty)
        #expect(StalkerStubProtocol.requests(host: own).count == 1)
        #expect(await state(setup) == .loaded)
    }

    @Test("channels-dvr-source/the-guide-lines-up-without-manual-matching a guide too large fails on its own")
    func tooLarge() async throws {
        let host = "ge-dvr-large.dvr.test"
        let xml = String(decoding: try FakeChannelsDVR.fixture("xmltv.xml"), as: UTF8.self)
        let setup = try setup(host: host, limits: GuideLimits(compressedBytes: 200, unpackedBytes: 400)) { _ in .http(200, xml) }
        await setup.engine.refresh(sourceID: setup.source.sourceID)
        await setup.engine.idle()
        #expect(await state(setup) == .failed(.tooLarge))
    }

    @Test("guide-data/guide-address-worked-out-from-the-source a missing or unreadable password sends nothing")
    func credentialStates() async throws {
        let missing = try setup(host: "ge-dvr-missing.dvr.test", credentialKey: "k", lookup: .missing) { _ in .http(200, "") }
        await missing.engine.refresh(sourceID: missing.source.sourceID)
        await missing.engine.idle()
        #expect(await state(missing) == .unavailable)
        #expect(StalkerStubProtocol.requests(host: "ge-dvr-missing.dvr.test").isEmpty)

        let unreadable = try setup(host: "ge-dvr-unreadable.dvr.test", credentialKey: "k", lookup: .unreadable) { _ in .http(200, "") }
        await unreadable.engine.refresh(sourceID: unreadable.source.sourceID)
        await unreadable.engine.idle()
        #expect(await state(unreadable) == .failed(.credentialUnreadable))
        #expect(StalkerStubProtocol.requests(host: "ge-dvr-unreadable.dvr.test").isEmpty)
    }

    @Test("guide-data/guide-address-worked-out-from-the-source a refused guide fails as unauthorized")
    func refused() async throws {
        let setup = try setup(host: "ge-dvr-401.dvr.test") { _ in .http(401, "") }
        await setup.engine.refresh(sourceID: setup.source.sourceID)
        await setup.engine.idle()
        #expect(await state(setup) == .failed(.unauthorized))
    }

    @Test("guide-data/guide-address-worked-out-from-the-source the resolver builds the server's guide address")
    func resolver() throws {
        let server = try #require(ChannelsDVRClient.serverURL(from: "nas.local"))
        let resolved = GuideURLResolver.resolve(kind: .channelsDVR, url: server, epgURL: nil, playlistEPGURLs: [], credential: nil)
        #expect(resolved?.absoluteString == "http://nas.local:8089/devices/ANY/guide/xmltv.xml?duration=604800")
    }
}

@Suite struct ChannelsDVRLoadTests {
    private let lineup: String

    init() throws {
        lineup = String(decoding: try FakeChannelsDVR.fixture("channels.m3u"), as: UTF8.self)
    }

    private func serve(_ host: String) -> URLSession {
        let body = lineup
        StalkerStubProtocol.register(host: host) { request in
            request.url?.path() == "/status" ? .http(200, FakeChannelsDVR.status) : .http(200, body)
        }
        let configuration = URLSessionConfiguration.channelsDVR
        configuration.protocolClasses = [StalkerStubProtocol.self]
        return URLSession(configuration: configuration)
    }

    @Test("channels-dvr-source/a-source-waits-for-its-password-to-sync three kinds of credential state")
    func credentialStates() async throws {
        let read = Recorder<String>()
        let waitingHost = "load-waiting.dvr.test"
        let waiting = try await ChannelsDVRClient.load(
            server: try #require(ChannelsDVRClient.serverURL(from: waitingHost)), credentialKey: "remote",
            credential: { key in
                read.append(key)
                return .missing
            }, session: serve(waitingHost))
        #expect(waiting == .waitingForCredential)
        #expect(StalkerStubProtocol.requests(host: waitingHost).isEmpty)

        let brokenHost = "load-broken.dvr.test"
        await #expect(throws: ChannelsDVRError.credentialUnreadable) {
            try await ChannelsDVRClient.load(
                server: try #require(ChannelsDVRClient.serverURL(from: brokenHost)), credentialKey: "broken",
                credential: { _ in .unreadable }, session: serve(brokenHost))
        }
        #expect(StalkerStubProtocol.requests(host: brokenHost).isEmpty)

        let homeHost = "load-home.dvr.test"
        let home = try await ChannelsDVRClient.load(
            server: try #require(ChannelsDVRClient.serverURL(from: homeHost)), credentialKey: nil,
            credential: { key in
                read.append(key)
                return .missing
            }, session: serve(homeHost))
        guard case .loaded(let channels) = home else {
            Issue.record("expected channels")
            return
        }
        #expect(channels.count == 5)
        #expect(read.all == ["remote"], "the home source never touches the Keychain")
        #expect(StalkerStubProtocol.requests(host: homeHost).map { $0.url?.path() } == ["/status", "/devices/ANY/channels.m3u"])
    }

    @Test("source-management/a-source-can-wait-for-its-credential password not synced yet")
    func passwordNotSynced() async throws {
        let host = "load-not-synced.dvr.test"
        let result = try await ChannelsDVRClient.load(
            server: try #require(ChannelsDVRClient.serverURL(from: host)), credentialKey: "k", credential: { _ in .missing },
            session: serve(host))
        #expect(result == .waitingForCredential)
        #expect(StalkerStubProtocol.requests(host: host).isEmpty)
    }

    @Test("channels-dvr-source/one-unreachable-server-does-not-hold-up-the-rest a failed status asks for no lineup")
    func failedStatusStops() async throws {
        let host = "load-down.dvr.test"
        StalkerStubProtocol.register(host: host) { _ in .failure(.cannotConnectToHost) }
        let configuration = URLSessionConfiguration.channelsDVR
        configuration.protocolClasses = [StalkerStubProtocol.self]
        await #expect(throws: ChannelsDVRError.unreachable(.cannotConnectToHost)) {
            try await ChannelsDVRClient.load(
                server: try #require(ChannelsDVRClient.serverURL(from: host)), credentialKey: nil, credential: { _ in .missing },
                session: URLSession(configuration: configuration))
        }
        #expect(StalkerStubProtocol.requests(host: host).map { $0.url?.path() } == ["/status"])
    }
}
