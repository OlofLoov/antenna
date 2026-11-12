import AntennaCore
import Foundation
import SwiftData
import Testing

@testable import Antenna

/// Jellyfin servers in the app: Connect, the Apple TV sign-in, Settings, the
/// channel loader and deletion. Servers are served by `StubURLProtocol` per
/// path, so no test opens a network connection.
@MainActor
@Suite struct JellyfinSourceTests {
    let container: ModelContainer
    let held = HeldCredentialStore()
    let device = JellyfinDevice(id: "test-device", name: "iPhone", appVersion: "1.0")

    init() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: Schema(AntennaSchema.models), configurations: configuration)
    }

    private var context: ModelContext { container.mainContext }

    private func clients(_ tag: String) -> JellyfinClients {
        JellyfinClients(session: StubURLProtocol.session(tag: tag), device: device)
    }

    private func connector(_ tag: String, clients: JellyfinClients? = nil) -> SourceConnector {
        SourceConnector(
            session: StubURLProtocol.session(tag: tag), credentials: held, portalSession: StubURLProtocol.session(tag: tag),
            jellyfinClients: clients ?? self.clients(tag))
    }

    /// Serves a Jellyfin server at `host` with two Live TV channels.
    private func serve(_ host: String, info: String? = nil, authStatus: Int = 200) {
        let infoBody = info ?? #"{"Id":"srv-1","ServerName":"Home","Version":"10.10.3"}"#
        StubURLProtocol.register(host: host, action: "path:/System/Info/Public", body: infoBody)
        StubURLProtocol.register(
            host: host, action: "path:/Users/AuthenticateByName", status: authStatus,
            body: authStatus == 200 ? #"{"User":{"Id":"u1"},"AccessToken":"K1","ServerId":"srv-1"}"# : "")
        let rows = (1...2).map { #"{"Name":"Channel \#($0)","Id":"c\#($0)","ChannelNumber":"\#($0)"}"# }
        StubURLProtocol.register(
            host: host, action: "path:/LiveTv/Channels", body: #"{"Items":["# + rows.joined(separator: ",") + #"],"TotalRecordCount":2}"#)
    }

    private func paths(_ host: String) -> [String] {
        StubURLProtocol.requests(host: host).compactMap { $0.url?.path() }
    }

    private func records() throws -> [SourceRecord] {
        try context.fetch(FetchDescriptor<SourceRecord>())
    }

    @Test("first-run-onboarding/add-a-jellyfin-server: Connect checks the server, signs in and saves the login")
    func connect() async throws {
        let host = "ob-jf-connect.local"
        serve(host)
        let model = OnboardingModel(connector: connector(host), clipboard: nil)
        model.choose(.jellyfin)
        #expect(model.fields.kind == .jellyfin)
        model.fields.url = "http://\(host):8096"
        model.fields.username = "anna"
        model.fields.password = "s3cret"
        await model.connect(into: context)

        #expect(model.error == nil)
        guard case .playlist(let playlist) = try #require(model.connection).reply else {
            Issue.record("expected the server's channels")
            return
        }
        #expect(playlist.channels.map(\.name) == ["Channel 1", "Channel 2"])
        #expect(playlist.channels.first?.id == "jellyfin#\(host)#c1")
        #expect(paths(host) == ["/System/Info/Public", "/Users/AuthenticateByName", "/LiveTv/Channels"])
        let check = try #require(StubURLProtocol.requests(host: host).first)
        #expect(check.httpBody == nil)
        let record = try #require(try records().first)
        #expect(record.kind == .jellyfin)
        #expect(try held.load(for: try #require(record.credentialKey)) == .init(username: "anna", password: "s3cret"))
    }

    @Test("first-run-onboarding/add-a-jellyfin-server: an address that is not a Jellyfin server gets no password")
    func notJellyfin() async throws {
        let host = "ob-jf-not.local"
        serve(host, info: "<!doctype html><html><body>Router login</body></html>")
        let model = OnboardingModel(connector: connector(host), clipboard: nil)
        model.choose(.jellyfin)
        model.fields.url = "http://\(host)"
        model.fields.username = "anna"
        model.fields.password = "s3cret"
        await model.connect(into: context)
        #expect(model.error == "No Jellyfin server answered at \(host). Check the address and try again.")
        #expect(paths(host) == ["/System/Info/Public"])
        #expect(try records().isEmpty)
    }

    @Test("first-run-onboarding/add-a-jellyfin-server: a blocked account and an untrusted certificate have their sentences")
    func failures() async throws {
        let blocked = "ob-jf-blocked.local"
        serve(blocked, authStatus: 403)
        let model = OnboardingModel(connector: connector(blocked), clipboard: nil)
        model.choose(.jellyfin)
        model.fields.url = "http://\(blocked)"
        model.fields.username = "anna"
        model.fields.password = "s3cret"
        await model.connect(into: context)
        #expect(model.error == "This account is not allowed to sign in from this device.")

        let untrusted = "ob-jf-cert.local"
        StubURLProtocol.fail(host: untrusted, with: .serverCertificateUntrusted)
        let second = OnboardingModel(connector: connector(untrusted), clipboard: nil)
        second.choose(.jellyfin)
        second.fields.url = "https://\(untrusted)"
        second.fields.username = "anna"
        second.fields.password = "s3cret"
        await second.connect(into: context)
        #expect(second.error == "Antenna can't verify this server's certificate. Use http on your network or a trusted certificate.")

        let wrong = "ob-jf-wrong.local"
        serve(wrong, authStatus: 401)
        let third = OnboardingModel(connector: connector(wrong), clipboard: nil)
        third.choose(.jellyfin)
        third.fields.url = "http://\(wrong)"
        third.fields.username = "anna"
        third.fields.password = "nope"
        await third.connect(into: context)
        #expect(third.error == "Could not sign in. Check the username and password.")
        #expect(try records().isEmpty)
    }

    @Test("first-run-onboarding/add-a-jellyfin-server: the Apple TV sign-in asks a Jellyfin server for its login")
    func signInOnAppleTV() async throws {
        let host = "ob-jf-sign-in.local"
        serve(host)
        let server = SourceDescriptor(name: "Home", kind: .jellyfin, url: try #require(URL(string: "http://\(host):8096")))
        context.insert(SourceRecord(descriptor: server, sortOrder: 0))
        try context.save()
        let model = OnboardingModel(connector: connector(host), clipboard: nil)
        model.startSignIn([server])
        #expect(model.signIns.map(\.id) == [server.id])
        #expect(model.fields.kind == .jellyfin)
        #expect(model.fields.url == "http://\(host):8096")

        await model.signIn(into: context)
        #expect(model.error == "Enter the username.")
        #expect(StubURLProtocol.requests(host: host).isEmpty)
        model.fields.username = "anna"
        model.fields.password = "s3cret"
        await model.signIn(into: context)
        #expect(model.error == nil)
        #expect(model.signIns.isEmpty)
        #expect(try held.load(for: server.id.uuidString) == .init(username: "anna", password: "s3cret"))
        #expect(try records().count == 1)
    }

    @Test("sources-and-settings/look-after-a-jellyfin-server: details hide the password and check a changed login")
    func details() async throws {
        let host = "st-jf-details.local"
        serve(host)
        let descriptor = SourceDescriptor(
            name: "Home", kind: .jellyfin, url: try #require(URL(string: "http://\(host):8096")), credentialKey: "st-jf-details")
        try held.save(.init(username: "anna", password: "s3cret"), for: "st-jf-details")
        context.insert(SourceRecord(descriptor: descriptor, sortOrder: 0))
        try context.save()
        let editor = SourceEditor(descriptor, connector: connector(host))
        #expect(editor.username == "anna")
        #expect(editor.password.isEmpty)
        #expect(!editor.needsCheck)
        #expect(!Mirror(reflecting: editor).children.contains { ($0.value as? String) == "s3cret" })

        editor.link = "ftp://\(host)"
        #expect(await !editor.save(in: context))
        #expect(editor.error == "Enter a valid URL.")
        #expect(StubURLProtocol.requests(host: host).isEmpty)

        editor.link = "http://\(host):8096"
        editor.username = "bo"
        #expect(editor.needsCheck)
        #expect(await editor.save(in: context))
        #expect(editor.error == nil)
        #expect(paths(host).contains("/Users/AuthenticateByName"))
        #expect(try held.load(for: "st-jf-details") == .init(username: "bo", password: "s3cret"))
        #expect(SourceRowLabel.badge(.jellyfin) == "JELLYFIN")
    }

    @Test("sources-and-settings/look-after-a-jellyfin-server: Sign in on this Apple TV keeps the login")
    func settingsSignIn() async throws {
        let host = "st-jf-sign-in.local"
        serve(host)
        let descriptor = SourceDescriptor(
            name: "Home", kind: .jellyfin, url: try #require(URL(string: "http://\(host)")), credentialKey: "st-jf-missing")
        context.insert(SourceRecord(descriptor: descriptor, sortOrder: 0))
        try context.save()
        let editor = SourceEditor(descriptor, connector: connector(host))
        #expect(!editor.hasLogin)
        editor.username = "anna"
        editor.password = "s3cret"
        #expect(await editor.save(in: context))
        #expect(editor.hasLogin)
        #expect(try held.load(for: "st-jf-missing")?.username == "anna")
    }

    @Test("jellyfin-live-tv-source/signing-in-remembers-this-device the loader signs in once and deleting clears the key")
    func loadAndDelete() async throws {
        let host = "ld-jf.local"
        serve(host)
        let clients = clients(host)
        let descriptor = SourceDescriptor(
            name: "Home", kind: .jellyfin, url: try #require(URL(string: "http://\(host)")), credentialKey: "ld-jf")
        try held.save(.init(username: "anna", password: "s3cret"), for: "ld-jf")
        let record = SourceRecord(descriptor: descriptor, sortOrder: 0)
        context.insert(record)
        let loader = SourceLoader(session: StubURLProtocol.session(tag: host), credentials: held, jellyfinClients: clients)
        #expect(loader.hasLogin(descriptor))
        #expect(try await loader.load(descriptor).channels.count == 2)
        #expect(try await loader.load(descriptor).channels.count == 2)
        #expect(paths(host).filter { $0 == "/Users/AuthenticateByName" }.count == 1)
        #expect(await clients.hasSession(storeKey: "ld-jf"))
        #expect(clients.client(sourceID: descriptor.id) != nil)

        SourceRecord.delete(record, from: context, credentials: held, jellyfinClients: clients)
        #expect(await !clients.hasSession(storeKey: "ld-jf"))
        #expect(clients.client(sourceID: descriptor.id) == nil)
    }

    @Test("jellyfin-live-tv-source/signing-in-remembers-this-device a source whose password has not synced shows no channels")
    func noPassword() async throws {
        let host = "ld-jf-missing.local"
        serve(host)
        let descriptor = SourceDescriptor(
            name: "Home", kind: .jellyfin, url: try #require(URL(string: "http://\(host)")), credentialKey: "ld-jf-missing")
        let loader = SourceLoader(session: StubURLProtocol.session(tag: host), credentials: held, jellyfinClients: clients(host))
        #expect(!loader.hasLogin(descriptor))
        #expect(try await loader.load(descriptor).channels.isEmpty)
        #expect(StubURLProtocol.requests(host: host).isEmpty)
    }

    @Test("jellyfin-live-tv-source/signing-in-remembers-this-device the device names the platform and keeps one id")
    func thisDevice() throws {
        let defaults = try #require(UserDefaults(suiteName: "jellyfin-device-\(UUID().uuidString)"))
        let first = JellyfinClients.thisDevice(defaults: defaults)
        let second = JellyfinClients.thisDevice(defaults: defaults)
        #expect(first.id == second.id)
        #expect(defaults.string(forKey: JellyfinClients.deviceIDKey) == first.id)
        #expect(["iPhone", "iPad", "Mac", "Apple TV"].contains(first.name))
        #if os(tvOS)
            #expect(first.name == "Apple TV")
        #endif
    }
}
