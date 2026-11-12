import AntennaCore
import Foundation
import Security
import SwiftData
import Testing

@testable import Antenna

/// Stalker sources in the app: the Keychain item, the channel loader, Connect
/// and the tune-time address. Portals are served by `StubURLProtocol` per
/// action, so no test opens a network connection.
@MainActor
@Suite struct StalkerSourceTests {
    let container: ModelContainer
    let store = CredentialStore(service: "se.codecrave.antenna.tests.\(UUID().uuidString)")
    let held = HeldCredentialStore()
    let clients = StalkerClients(session: StubURLProtocol.session())

    init() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: Schema(AntennaSchema.models), configurations: configuration)
    }

    private var context: ModelContext { container.mainContext }

    /// Serves a portal at `host` with `count` channels.
    private func servePortal(host: String, count: Int) {
        StubURLProtocol.register(host: host, action: "handshake", body: #"{"js":{"token":"T1","random":"r"}}"#)
        StubURLProtocol.register(host: host, action: "get_profile", body: #"{"js":{"status":0}}"#)
        StubURLProtocol.register(host: host, action: "do_auth", body: #"{"js":true}"#)
        StubURLProtocol.register(host: host, action: "get_genres", body: #"{"js":[{"id":"*","title":"All"},{"id":"1","title":"News"}]}"#)
        let rows = (1...count).map {
            #"{"id":"\#($0)","name":"\#(host) \#($0)","number":"\#($0)","cmd":"ffrt http://localhost/ch/\#($0)_","tv_genre_id":"1"}"#
        }
        StubURLProtocol.register(host: host, action: "get_all_channels", body: #"{"js":{"data":["# + rows.joined(separator: ",") + "]}}")
        StubURLProtocol.register(host: host, action: "create_link", body: #"{"js":{"cmd":"ffmpeg http://stream.\#(host)/live/1?key=k"}}"#)
    }

    private func insert(_ kind: SourceKind, url: String, sortOrder: Int, credentialKey: String? = nil) throws {
        let descriptor = SourceDescriptor(name: url, kind: kind, url: try #require(URL(string: url)), credentialKey: credentialKey)
        context.insert(SourceRecord(descriptor: descriptor, sortOrder: sortOrder))
    }

    private func descriptors() throws -> [SourceDescriptor] {
        try context.fetch(FetchDescriptor<SourceRecord>(sortBy: SourceRecord.displayOrder)).compactMap(\.descriptor)
    }

    private func loader(_ credentials: any CredentialStoring) -> SourceLoader {
        SourceLoader(session: StubURLProtocol.session(), credentials: credentials, stalkerClients: clients)
    }

    @Test("source-management/stalker-channels-are-combined-with-other-sources Stalker beside M3U")
    func stalkerBesideM3U() async throws {
        let key = UUID().uuidString
        try held.save(.init(username: "00:1A:79:00:00:01", password: "p"), for: key)
        servePortal(host: "sm-stalker.portal", count: 3)
        StubURLProtocol.register(
            host: "sm-m3u.test", body: "#EXTM3U\n#EXTINF:-1,One\nhttp://sm-m3u.test/1.ts\n#EXTINF:-1,Two\nhttp://sm-m3u.test/2.ts\n")
        try insert(.stalker, url: "http://sm-stalker.portal/c/", sortOrder: 0, credentialKey: key)
        try insert(.m3u, url: "http://sm-m3u.test/list.m3u", sortOrder: 1)

        let model = LiveModel(.live(loader: loader(held), guide: nil))
        model.sourcesChanged(try descriptors())
        await model.settled()

        #expect(model.channels.map(\.name) == ["sm-stalker.portal 1", "sm-stalker.portal 2", "sm-stalker.portal 3", "One", "Two"])
        #expect(model.channels.prefix(3).allSatisfy { $0.group == "News" })
    }

    @Test("source-management/stalker-type-is-stored Stalker save with a login")
    func stalkerSaveWithLogin() throws {
        let form = NewSource(
            kind: .stalker, url: "http://Portal.test:8080/stalker_portal/c/", username: "00-1a-79-00-00-01", password: "secret",
            login: "alice")
        let saved = try form.save(into: context, credentials: store)
        defer { try? store.delete(for: saved.id.uuidString) }

        #expect(try store.load(for: saved.id.uuidString) == .init(username: "00:1A:79:00:00:01", password: "secret", login: "alice"))
        #expect(saved.url?.absoluteString == "http://portal.test:8080/stalker_portal")
        #expect(saved.name == "portal.test")
        let synced = [saved.name, saved.url?.absoluteString, saved.epgURL?.absoluteString, saved.credentialKey].compactMap { $0 }.joined()
        for secret in ["00:1A", "001A79", "00-1a", "secret", "alice"] {
            #expect(!synced.localizedCaseInsensitiveContains(secret))
        }
    }

    @Test("stalker-portal-source/your-mac-and-login-stay-in-the-keychain three kinds of Keychain item")
    func threeItemKinds() throws {
        let source = SourceDescriptor(
            name: "Portal", kind: .stalker, url: try #require(URL(string: "http://kc-portal.test")), credentialKey: "unused")
        let full = UUID().uuidString
        try store.save(.init(username: "00:1A:79:00:00:01", password: "p", login: "alice"), for: full)
        defer { try? store.delete(for: full) }
        let loaded = try #require(try store.load(for: full))
        #expect(loaded.login == "alice")
        #expect(clients.client(for: source, credential: loaded)?.credentials.login == "alice")

        let old = UUID().uuidString
        let add: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: store.service, kSecAttrAccount as String: old,
            kSecAttrSynchronizable as String: true, kSecValueData as String: Data(#"{"username":"00:1A:79:00:00:02","password":"p"}"#.utf8),
        ]
        #expect(SecItemAdd(add as CFDictionary, nil) == errSecSuccess)
        defer { try? store.delete(for: old) }
        let oldItem = try #require(try store.load(for: old))
        #expect(oldItem == .init(username: "00:1A:79:00:00:02", password: "p"))
        let oldSource = SourceDescriptor(name: "Old", kind: .stalker, url: source.url)
        #expect(clients.client(for: oldSource, credential: oldItem)?.credentials.login == nil)

        let notMAC = UUID().uuidString
        try store.save(.init(username: "alice", password: "p"), for: notMAC)
        defer { try? store.delete(for: notMAC) }
        var other = source
        other.credentialKey = notMAC
        other.id = UUID()
        #expect(!SourceLoader(credentials: store, stalkerClients: clients).hasLogin(other))
        #expect(clients.client(for: other, credential: try #require(try store.load(for: notMAC))) == nil)
    }

    @Test("stalker-portal-source/your-mac-and-login-stay-in-the-keychain channel ids hold no MAC")
    func channelIDs() async throws {
        let key = UUID().uuidString
        try held.save(.init(username: "00:1A:79:00:00:01", password: "p"), for: key)
        servePortal(host: "kc-ids.portal", count: 2)
        let source = SourceDescriptor(
            name: "Portal", kind: .stalker, url: try #require(URL(string: "http://kc-ids.portal")), credentialKey: key)
        let playlist = try await loader(held).load(source)
        #expect(playlist.channels.map(\.id) == ["stalker#kc-ids.portal#1", "stalker#kc-ids.portal#2"])
    }

    @Test("stalker-portal-source/tuning-gets-a-fresh-stream-address tune a portal channel")
    func tune() async throws {
        let key = UUID().uuidString
        try held.save(.init(username: "00:1A:79:00:00:01", password: "p"), for: key)
        servePortal(host: "tn-portal.portal", count: 1)
        let source = SourceDescriptor(
            name: "Portal", kind: .stalker, url: try #require(URL(string: "http://tn-portal.portal")), credentialKey: key)
        let channel = try #require(Channel.tagged(try await loader(held).load(source).channels, sourceID: source.id).first)

        let url = try await StreamResolver.address(for: channel, clients: clients)
        #expect(url.absoluteString == "http://stream.tn-portal.portal/live/1?key=k")
        let plain = Channel(id: "m3u#1", name: "Plain", streamURL: try #require(URL(string: "http://s.example/1.ts")))
        #expect(try await StreamResolver.address(for: plain, clients: clients) == plain.streamURL)

        var unknown = channel
        unknown.sourceID = UUID()
        await #expect(throws: PlaybackFailure.loginNotOnDevice) { try await StreamResolver.address(for: unknown, clients: clients) }
        StubURLProtocol.register(host: "tn-portal.portal", action: "create_link", body: #"{"js":[]}"#)
        await #expect(throws: PlaybackFailure.unreadable) { try await StreamResolver.address(for: channel, clients: clients) }
    }

    @Test("stalker-portal-source/connect-says-why-it-failed Connect maps each portal failure")
    func connectFailures() async throws {
        let connector = SourceConnector(session: StubURLProtocol.session(), credentials: held, portalSession: StubURLProtocol.session())
        let link = try #require(URL(string: "http://cn-refused.portal/c/"))
        await #expect(throws: ConnectFailure.invalidMAC) {
            _ = try await connector.probe(.stalker, link: link, username: "00:1A", password: "", host: "cn-refused.portal")
        }
        StubURLProtocol.register(host: "cn-refused.portal", action: "handshake", body: #"{"js":{"token":"T1"}}"#)
        StubURLProtocol.register(
            host: "cn-refused.portal", action: "get_profile", body: #"{"js":{"status":1,"msg":"MAC 00:1A:79:00:00:01 is not registered"}}"#)
        await #expect(throws: ConnectFailure.deviceRefused(message: "MAC … is not registered")) {
            _ = try await connector.probe(.stalker, link: link, username: "00:1A:79:00:00:01", password: "", host: "cn-refused.portal")
        }

        servePortal(host: "cn-ok.portal", count: 2)
        let reply = try await connector.probe(
            .stalker, link: try #require(URL(string: "http://cn-ok.portal")), username: "001A79000001", password: "", host: "cn-ok.portal")
        guard case .playlist(let playlist) = reply else {
            Issue.record("expected the channel list")
            return
        }
        #expect(playlist.channels.count == 2)
    }
}
