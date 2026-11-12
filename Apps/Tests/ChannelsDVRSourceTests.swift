import AntennaCore
import Foundation
import SwiftData
import Testing

@testable import Antenna

/// Channels DVR servers in the app: loading beside other sources, Connect
/// from onboarding and Settings, and the details form. Servers are served
/// by `StubURLProtocol` per path, so no test opens a network connection.
@MainActor
@Suite struct ChannelsDVRSourceTests {
    let container: ModelContainer
    let held = HeldCredentialStore()

    init() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: Schema(AntennaSchema.models), configurations: configuration)
    }

    private var context: ModelContext { container.mainContext }

    static let status = #"{"version":"2025.03.01.0012","booted":true,"subscription":"active"}"#

    /// Serves a Channels DVR server at `host` with `count` channels.
    private func serveServer(_ host: String, count: Int = 2, status: String = Self.status) {
        StubURLProtocol.register(host: host, path: "/status", body: status)
        let entries = (1...count).map {
            "#EXTINF:-1 tvg-id=\"c\($0)\" tvg-chno=\"\($0).1\" tvg-name=\"CALL\($0)\" group-title=\"HD\",\(host) \($0)\n"
                + "http://\(host):8089/devices/ANY/channels/\($0).1/hls/master.m3u8?codec=copy"
        }
        StubURLProtocol.register(
            host: host, path: "/devices/ANY/channels.m3u", body: "#EXTM3U\n" + entries.joined(separator: "\n") + "\n")
    }

    private func paths(_ host: String) -> [String] {
        StubURLProtocol.requests(host: host).compactMap { $0.url?.path() }
    }

    private func loader(_ tag: String) -> SourceLoader {
        var loader = SourceLoader(session: StubURLProtocol.session(tag: tag), credentials: held)
        loader.channelsDVRSession = StubURLProtocol.session(tag: tag)
        return loader
    }

    private func connector(_ tag: String) -> SourceConnector {
        var connector = SourceConnector(session: StubURLProtocol.session(tag: tag), credentials: held)
        connector.channelsDVRSession = StubURLProtocol.session(tag: tag)
        return connector
    }

    private func insert(_ kind: SourceKind, url: String, sortOrder: Int, credentialKey: String? = nil) throws {
        let descriptor = SourceDescriptor(name: url, kind: kind, url: try #require(URL(string: url)), credentialKey: credentialKey)
        context.insert(SourceRecord(descriptor: descriptor, sortOrder: sortOrder))
    }

    private func descriptors() throws -> [SourceDescriptor] {
        try context.fetch(FetchDescriptor<SourceRecord>(sortBy: SourceRecord.displayOrder)).compactMap(\.descriptor)
    }

    @Test("channels-dvr-source/one-unreachable-server-does-not-hold-up-the-rest mixed sources")
    func mixedSources() async throws {
        StubURLProtocol.register(host: "dvr-mixed-m3u.test", body: "#EXTM3U\n#EXTINF:-1,One\nhttp://dvr-mixed-m3u.test/1.ts\n")
        StubURLProtocol.fail(host: "dvr-mixed-down.test", with: .cannotConnectToHost)
        serveServer("dvr-mixed-up.test")
        try insert(.m3u, url: "http://dvr-mixed-m3u.test/list.m3u", sortOrder: 0)
        try insert(.channelsDVR, url: "http://dvr-mixed-down.test:8089", sortOrder: 1)
        try insert(.channelsDVR, url: "http://dvr-mixed-up.test:8089", sortOrder: 2)

        let model = LiveModel(.live(loader: loader("dvr-mixed"), guide: nil))
        model.sourcesChanged(try descriptors())
        await model.settled()

        #expect(model.channels.map(\.name) == ["One", "dvr-mixed-up.test 1", "dvr-mixed-up.test 2"])
        #expect(model.sources.map(\.state) == [.loaded(channels: 1), .failed, .loaded(channels: 2)])
        #expect(paths("dvr-mixed-down.test") == ["/status"], "no lineup or guide request after a failed status")
        #expect(paths("dvr-mixed-up.test") == ["/status", "/devices/ANY/channels.m3u"])
    }

    @Test("channels-dvr-source/a-source-waits-for-its-password-to-sync three kinds of credential state")
    func credentialStates() async throws {
        serveServer("dvr-cred-home.test")
        serveServer("dvr-cred-remote.test")
        serveServer("dvr-cred-broken.test")
        let unreadable = UnreadableItemStore(unreadable: "broken")
        let loader = SourceLoader(
            session: StubURLProtocol.session(), credentials: unreadable, channelsDVRSession: StubURLProtocol.session())
        let remote = try SourceDescriptor(
            name: "Remote", kind: .channelsDVR, url: #require(URL(string: "http://dvr-cred-remote.test:8089")), credentialKey: "remote")
        let broken = try SourceDescriptor(
            name: "Broken", kind: .channelsDVR, url: #require(URL(string: "http://dvr-cred-broken.test:8089")), credentialKey: "broken")
        let home = try SourceDescriptor(name: "Home", kind: .channelsDVR, url: #require(URL(string: "http://dvr-cred-home.test:8089")))

        #expect(!loader.hasLogin(remote))
        #expect(loader.hasLogin(broken))
        #expect(loader.hasLogin(home))
        await #expect(throws: SourceLoader.LoadError.self) { try await loader.load(broken) }
        #expect(try await loader.load(home).channels.count == 2)
        #expect(paths("dvr-cred-remote.test").isEmpty && paths("dvr-cred-broken.test").isEmpty)
        #expect(unreadable.reads == ["remote", "broken", "broken"], "the home source never touches the Keychain")
    }

    @Test("first-run-onboarding/add-a-channels-dvr-server: one address connects and saves no password")
    func connectFromOnboarding() async throws {
        let host = "dvr-ob.test"
        serveServer(host)
        let model = OnboardingModel(connector: connector(host), clipboard: nil)
        model.choose(.channelsDVR)
        model.fields.url = " \(host) "
        await model.connect(into: context)

        #expect(model.error == nil)
        let connection = try #require(model.connection)
        #expect(connection.descriptor.url.absoluteString == "http://dvr-ob.test:8089")
        #expect(connection.descriptor.credentialKey == nil)
        #expect(connection.serverVersion == "2025.03.01.0012")
        guard case .playlist(let playlist) = connection.reply else {
            Issue.record("expected the lineup")
            return
        }
        #expect(playlist.channels.map(\.id) == ["channelsdvr#id#c1", "channelsdvr#id#c2"])
        #expect(paths(host) == ["/status", "/devices/ANY/channels.m3u"])
        let record = try #require(try context.fetch(FetchDescriptor<SourceRecord>()).first)
        #expect(record.kind == .channelsDVR && record.name == host && record.epgURL == nil && record.credentialKey == nil)

        let setup = SourceSetup(
            connection,
            dependencies: .init(
                channels: { _ in Playlist(channels: []) }, library: { _ in SourceSetup.Library(movies: 0, series: 0) }, guide: nil))
        let lines = OnboardingProgress(setups: [setup]).lines(for: setup, .phone)
        #expect(lines.first?.title == "Server" && lines.first?.detail == "Channels DVR 2025.03.01.0012")
    }

    @Test("first-run-onboarding/a-failed-connection-says-why-and-saves-nothing: Channels DVR failures save nothing")
    func failuresSaveNothing() async throws {
        let starting = "dvr-ob-starting.test"
        serveServer(starting, status: #"{"version":"2025.03.01.0012","booted":false}"#)
        let notServer = "dvr-ob-router.test"
        StubURLProtocol.register(host: notServer, path: "/status", status: 404, body: "<html></html>")
        let locked = "dvr-ob-locked.local"
        StubURLProtocol.register(host: locked, path: "/status", status: 401, body: "")
        let away = "192.168.1.250"
        StubURLProtocol.fail(host: away, with: .notConnectedToInternet)

        let cases: [(String, String)] = [
            (starting, "Channels DVR is starting. Try again in a moment."),
            (notServer, "No Channels DVR server at dvr-ob-router.test."),
            (locked, "This server asks for a username and password, which Antenna cannot send yet."),
            (away, "You're offline. Connect to the internet and try again. Allow local network access for Antenna in Settings."),
            ("ftp://\(starting)", "Enter a valid server address."),
            ("http://alice:secret@\(starting)", "Remove the username and password from the address."),
        ]
        for (address, sentence) in cases {
            let model = OnboardingModel(connector: connector("dvr-ob-fail"), clipboard: nil)
            model.choose(.channelsDVR)
            model.fields.url = address
            await model.connect(into: context)
            #expect(model.error == sentence, "\(address)")
            #expect(model.connection == nil)
        }
        #expect(try context.fetch(FetchDescriptor<SourceRecord>()).isEmpty)
        #expect(paths(starting) == ["/status"])
    }

    @Test("sources-and-settings/fix-a-source-s-link-or-login: a Channels DVR address change is checked first")
    func editAddress() async throws {
        let old = "dvr-edit-old.test"
        let new = "dvr-edit-new.test"
        serveServer(new)
        try insert(.channelsDVR, url: "http://\(old):8089", sortOrder: 0)
        let descriptor = try #require(try descriptors().first)
        let editor = SourceEditor(descriptor, connector: connector("dvr-edit"))

        editor.link = "ftp://\(new)"
        #expect(await editor.save(in: context) == false)
        #expect(editor.error == "Enter a valid server address.")

        editor.link = "\(new)/"
        #expect(await editor.save(in: context))
        let record = try #require(try context.fetch(FetchDescriptor<SourceRecord>()).first)
        #expect(record.url?.absoluteString == "http://dvr-edit-new.test:8089")
        #expect(record.credentialKey == nil)
        #expect(paths(new) == ["/status", "/devices/ANY/channels.m3u"])
    }

    @Test("source-management/a-source-can-wait-for-its-credential: a Channels DVR server is saved without a Keychain item")
    func saveWithoutLogin() throws {
        let saved = try NewSource(kind: .channelsDVR, url: "NAS.local").save(into: context, credentials: held)
        #expect(saved.url?.absoluteString == "http://nas.local:8089")
        #expect(saved.credentialKey == nil)
        #expect(throws: NewSource.SaveError.invalidURL) {
            try NewSource(kind: .channelsDVR, url: "ftp://nas.local").save(into: context, credentials: held)
        }
    }
}

/// Holds no items: `unreadable` throws, every other key is missing. Records each key read.
final class UnreadableItemStore: CredentialStoring, @unchecked Sendable {
    enum Failure: Error { case unreadable }
    let unreadable: String
    private let lock = NSLock()
    private var read: [String] = []

    init(unreadable: String) {
        self.unreadable = unreadable
    }

    var reads: [String] { lock.withLock { read } }

    func save(_ credential: CredentialStore.Credential, for key: String) throws {}
    func load(for key: String) throws -> CredentialStore.Credential? {
        lock.withLock { read.append(key) }
        if key == unreadable { throw Failure.unreadable }
        return nil
    }
    func delete(for key: String) throws {}
}
