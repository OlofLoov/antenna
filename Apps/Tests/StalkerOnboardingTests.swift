import AntennaCore
import Foundation
import SwiftData
import Testing

@testable import Antenna

/// Adding, signing in and editing a Stalker portal from onboarding and
/// Settings. Portals are served by `StubURLProtocol` per action, so no test
/// opens a network connection.
@MainActor
@Suite struct StalkerOnboardingTests {
    let container: ModelContainer
    let held = HeldCredentialStore()

    init() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: Schema(AntennaSchema.models), configurations: configuration)
    }

    private var context: ModelContext { container.mainContext }

    private func connector(_ tag: String) -> SourceConnector {
        SourceConnector(
            session: StubURLProtocol.session(tag: tag), credentials: held, portalSession: StubURLProtocol.session(tag: tag))
    }

    /// Serves a portal at `host` with two channels. `authorized` false turns
    /// the profile down, as a portal does for a MAC it does not know.
    private func servePortal(_ host: String, authorized: Bool = true) {
        StubURLProtocol.register(host: host, action: "handshake", body: #"{"js":{"token":"T1","random":"r"}}"#)
        StubURLProtocol.register(host: host, action: "do_auth", body: #"{"js":true}"#)
        StubURLProtocol.register(
            host: host, action: "get_profile", status: authorized ? 200 : 403, body: authorized ? #"{"js":{"status":0}}"# : "")
        StubURLProtocol.register(host: host, action: "get_genres", body: #"{"js":[{"id":"1","title":"News"}]}"#)
        let rows = (1...2).map {
            #"{"id":"\#($0)","name":"Channel \#($0)","number":"\#($0)","cmd":"ffrt http://localhost/ch/\#($0)","tv_genre_id":"1"}"#
        }
        StubURLProtocol.register(host: host, action: "get_all_channels", body: #"{"js":{"data":["# + rows.joined(separator: ",") + "]}}")
    }

    private func actions(_ host: String) -> [String] {
        StubURLProtocol.requests(host: host).compactMap { request in
            request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }?.queryItems?.first { $0.name == "action" }?.value
        }
    }

    private func records() throws -> [SourceRecord] {
        try context.fetch(FetchDescriptor<SourceRecord>())
    }

    @Test("first-run-onboarding/add-a-stalker-portal: a portal connects with only its address and MAC")
    func portalWithOnlyMAC() async throws {
        let host = "ob-mac-only.portal"
        servePortal(host)
        let model = OnboardingModel(connector: connector(host), clipboard: nil)
        model.choose(.stalker)
        #expect(model.fields.kind == .stalker)
        model.fields.url = "http://\(host)/c/"
        model.fields.mac = "00-1a-79-00-00-07"
        await model.connect(into: context)

        #expect(model.error == nil)
        let connection = try #require(model.connection)
        guard case .playlist(let playlist) = connection.reply else {
            Issue.record("expected the portal's channels")
            return
        }
        #expect(playlist.channels.map(\.name) == ["Channel 1", "Channel 2"])
        #expect(!actions(host).contains("do_auth"), "no login step without a login")
        let record = try #require(try records().first)
        #expect(record.kind == .stalker)
        #expect(record.url?.absoluteString == "http://\(host)")
        let key = try #require(record.credentialKey)
        #expect(try held.load(for: key) == .init(username: "00:1A:79:00:00:07", password: "", login: nil))
    }

    @Test("first-run-onboarding/add-a-stalker-portal: a login the user typed is sent and kept")
    func portalWithLogin() async throws {
        let host = "ob-login.portal"
        servePortal(host)
        let model = OnboardingModel(connector: connector(host), clipboard: nil)
        model.choose(.stalker)
        model.fields.url = "http://\(host)"
        model.fields.mac = "001A79000008"
        model.fields.username = "alice"
        model.fields.password = "pw"
        await model.connect(into: context)

        #expect(model.error == nil)
        #expect(actions(host).contains("do_auth"))
        let record = try #require(try records().first)
        #expect(
            try held.load(for: try #require(record.credentialKey)) == .init(username: "00:1A:79:00:00:08", password: "pw", login: "alice"))
    }

    @Test("first-run-onboarding/mistakes-in-the-form-are-caught-before-connecting: a portal with a mistyped MAC asks nothing")
    func mistypedMAC() async throws {
        let host = "ob-mistyped.portal"
        servePortal(host)
        let model = OnboardingModel(connector: connector(host), clipboard: nil)
        model.choose(.stalker)
        model.fields.url = "http://\(host)"
        await model.connect(into: context)
        #expect(model.error == "Enter the MAC address.")
        model.fields.mac = "00:1A:79"
        await model.connect(into: context)
        #expect(model.error == "Enter a valid MAC address, like 00:1A:79:12:34:56.")
        #expect(StubURLProtocol.requests(host: host).isEmpty)
        #expect(try records().isEmpty)
    }

    @Test("first-run-onboarding/a-failed-connection-says-why-and-saves-nothing: a portal that does not know the MAC")
    func portalRefusesMAC() async throws {
        let host = "ob-refused.portal"
        servePortal(host, authorized: false)
        let model = OnboardingModel(connector: connector(host), clipboard: nil)
        model.choose(.stalker)
        model.fields.url = "http://\(host)"
        model.fields.mac = "00:1A:79:00:00:09"
        await model.connect(into: context)
        #expect(model.error == "Could not sign in. Check the MAC address, and the login if you have one.")
        #expect(model.fields.mac == "00:1A:79:00:00:09")
        #expect(try records().isEmpty)
        #expect(model.connection == nil)
    }

    @Test("first-run-onboarding/sign-in-again-on-an-apple-tv: a portal asks for its MAC with the portal filled in")
    func signInPortal() async throws {
        let host = "ob-sign-in.portal"
        servePortal(host)
        let portal = SourceDescriptor(name: "Portal", kind: .stalker, url: try #require(URL(string: "http://\(host)")))
        let playlist = SourceDescriptor(name: "List", kind: .m3u, url: try #require(URL(string: "http://\(host)/list.m3u")))
        context.insert(SourceRecord(descriptor: portal, sortOrder: 0))
        try context.save()
        let model = OnboardingModel(connector: connector(host), clipboard: nil)
        model.startSignIn([portal, playlist])
        #expect(model.signIns.map(\.id) == [portal.id])
        #expect(model.fields.kind == .stalker)
        #expect(model.fields.url == "http://\(host)")

        await model.signIn(into: context)
        #expect(model.error == "Enter the MAC address.")
        #expect(StubURLProtocol.requests(host: host).isEmpty)
        model.fields.mac = "00:1a:79:00:00:0a"
        await model.signIn(into: context)
        #expect(model.error == nil)
        #expect(model.signIns.isEmpty)
        #expect(try held.load(for: portal.id.uuidString) == .init(username: "00:1A:79:00:00:0A", password: "", login: nil))
        #expect(try records().count == 1)
        #expect(try records().first?.credentialKey == portal.id.uuidString)
    }

    @Test("sources-and-settings/your-password-stays-hidden: a portal's details show its MAC and login, not its password")
    func portalDetailsHidePassword() throws {
        let host = "st-hidden.portal"
        let descriptor = SourceDescriptor(
            name: "Portal", kind: .stalker, url: try #require(URL(string: "http://\(host)")), credentialKey: "st-hidden")
        try held.save(.init(username: "00:1A:79:00:00:0B", password: "s3cret", login: "alice"), for: "st-hidden")
        context.insert(SourceRecord(descriptor: descriptor, sortOrder: 0))
        let editor = SourceEditor(descriptor, connector: connector(host))
        #expect(editor.mac == "00:1A:79:00:00:0B")
        #expect(editor.username == "alice")
        #expect(editor.password.isEmpty)
        #expect(editor.hasPassword)
        #expect(!editor.needsCheck)
        #expect(!Mirror(reflecting: editor).children.contains { ($0.value as? String) == "s3cret" })
    }

    @Test("sources-and-settings/fix-a-source-s-link-or-login: a changed MAC is checked with the portal before it saves")
    func changePortalMAC() async throws {
        let host = "st-change.portal"
        servePortal(host)
        let descriptor = SourceDescriptor(
            name: "Portal", kind: .stalker, url: try #require(URL(string: "http://\(host)")), credentialKey: "st-change")
        try held.save(.init(username: "00:1A:79:00:00:0C", password: "s3cret"), for: "st-change")
        context.insert(SourceRecord(descriptor: descriptor, sortOrder: 0))
        try context.save()
        let editor = SourceEditor(descriptor, connector: connector(host))

        editor.mac = "00:1A:79"
        #expect(editor.needsCheck)
        #expect(await !editor.save(in: context))
        #expect(editor.error == "Enter a valid MAC address, like 00:1A:79:12:34:56.")
        #expect(StubURLProtocol.requests(host: host).isEmpty)

        editor.mac = "00-1a-79-00-00-0d"
        #expect(await editor.save(in: context))
        #expect(editor.error == nil)
        #expect(actions(host).contains("handshake"))
        #expect(try held.load(for: "st-change") == .init(username: "00:1A:79:00:00:0D", password: "s3cret", login: nil))
        #expect(editor.mac == "00:1A:79:00:00:0D")
    }

    @Test("sources-and-settings/sign-in-on-this-apple-tv: a portal signs in here with its MAC")
    func settingsSignInPortal() async throws {
        let host = "st-sign-in.portal"
        servePortal(host)
        let descriptor = SourceDescriptor(
            name: "Portal", kind: .stalker, url: try #require(URL(string: "http://\(host)")), credentialKey: "st-missing")
        context.insert(SourceRecord(descriptor: descriptor, sortOrder: 0))
        try context.save()
        let editor = SourceEditor(descriptor, connector: connector(host))
        #expect(!editor.hasLogin)
        editor.mac = "00:1A:79:00:00:0E"
        #expect(await editor.save(in: context))
        #expect(editor.hasLogin)
        #expect(try held.load(for: "st-missing")?.username == "00:1A:79:00:00:0E")
    }

    @Test("sources-and-settings/see-how-each-source-is-doing: a portal shows its load status, not a placeholder")
    func portalRowStatus() throws {
        let record = SourceRecord(
            descriptor: SourceDescriptor(name: "Portal", kind: .stalker, url: try #require(URL(string: "http://st-row.portal"))),
            sortOrder: 0)
        #expect(SettingsView.status(of: record, refresher: nil) == SourceStatus())
    }
}
