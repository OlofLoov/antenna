import AntennaCore
import Foundation
import SwiftData
import Testing

@testable import Antenna

/// Connect in the add-source form: checks, the one request, the messages
/// and the save, against stubbed servers and an in-memory store.
@MainActor
@Suite struct OnboardingConnectTests {
    let container: ModelContainer
    let held = HeldCredentialStore()

    init() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: Schema(AntennaSchema.models), configurations: configuration)
    }

    private var context: ModelContext { container.mainContext }

    private func model(tag: String, credentials: (any CredentialStoring)? = nil, clipboard: Clipboard? = nil) -> OnboardingModel {
        let connector = SourceConnector(session: StubURLProtocol.session(tag: tag), credentials: credentials ?? held)
        return OnboardingModel(connector: connector, clipboard: clipboard)
    }

    private func sources() throws -> [SourceRecord] {
        try context.fetch(FetchDescriptor<SourceRecord>(sortBy: SourceRecord.displayOrder))
    }

    private static let account =
        #"{"user_info":{"username":"anna","status":"Active","exp_date":"1767225600","max_connections":"2","auth":1}}"#

    @Test("first-run-onboarding/mistakes-in-the-form-are-caught-before-connecting: an empty field or a bad link sends nothing")
    func formMistakes() async throws {
        let tag = "onboarding-mistakes-\(UUID().uuidString)"
        let model = model(tag: tag)
        model.fields = SourceFields(kind: .xtream, url: "http://mistakes.test", username: "anna")
        await model.connect(into: context)
        #expect(model.error == "Enter the password.")
        model.fields = SourceFields(kind: .m3u, url: "mistakes.test/list.m3u")
        await model.connect(into: context)
        #expect(model.error == "Enter a valid URL.")
        #expect(StubURLProtocol.requestCount(tag: tag) == 0)
        #expect(try sources().isEmpty)
    }

    @Test(
        "first-run-onboarding/a-failed-connection-says-why-and-saves-nothing: rejected, inactive, server error, unreadable",
        arguments: [
            (401, #"{}"#, "Could not sign in. Check the username and password."),
            (200, #"{"user_info":{"status":"Expired","auth":1}}"#, "This account is expired."),
            (500, "", "The server answered with an error (500). Check the address and try again."),
            (200, "<html>", "The server replied with something Antenna could not read."),
        ])
    func refused(status: Int, body: String, message: String) async throws {
        let host = "refused-\(status)-\(body.count).test"
        StubURLProtocol.register(host: host, status: status, body: body)
        let model = model(tag: host)
        let typed = SourceFields(kind: .xtream, name: "Home", url: "http://\(host):8080", username: "anna", password: "pw")
        model.fields = typed
        await model.connect(into: context)
        #expect(model.error == message)
        #expect(model.fields == typed)
        #expect(model.connection == nil)
        #expect(try sources().isEmpty)
        #expect(StubURLProtocol.requests(host: host).count == 1)
    }

    @Test("first-run-onboarding/a-failed-connection-says-why-and-saves-nothing: offline or unreachable")
    func offlineOrUnreachable() async throws {
        StubURLProtocol.fail(host: "offline.test", with: .notConnectedToInternet)
        let model = model(tag: "offline")
        model.fields = SourceFields(kind: .m3u, url: "http://offline.test/list.m3u")
        await model.connect(into: context)
        #expect(model.error == "You're offline. Connect to the internet and try again.")

        model.fields = SourceFields(kind: .xtream, url: "http://nowhere.test", username: "anna", password: "pw")
        await model.connect(into: context)
        #expect(model.error == "Could not reach nowhere.test. Check the address and try again.")

        StubURLProtocol.register(host: "playlist-404.test", status: 404, body: "")
        model.fields = SourceFields(kind: .m3u, url: "http://playlist-404.test/list.m3u")
        await model.connect(into: context)
        #expect(model.error == "The server answered with an error (404). Check the address and try again.")
        #expect(try sources().isEmpty)
    }

    @Test("first-run-onboarding/a-working-provider-is-saved-once: an Xtream login is saved with its password in the Keychain")
    func xtreamSaved() async throws {
        let host = "saved-xtream.test"
        StubURLProtocol.register(host: host, body: Self.account)
        let model = model(tag: host)
        model.fields = SourceFields(kind: .xtream, url: "http://\(host):8080", username: "anna", password: "s3cret")
        await model.connect(into: context)
        #expect(model.error == nil)
        let connection = try #require(model.connection)
        let record = try #require(try sources().first)
        #expect(try sources().count == 1)
        #expect(record.name == host)
        #expect(record.kind == .xtream)
        let key = try #require(record.credentialKey)
        #expect(try held.load(for: key) == .init(username: "anna", password: "s3cret"))
        #expect(connection.inserted)
        if case .account(let info) = connection.reply {
            #expect(info.maxConnections == "2")
        } else {
            Issue.record("expected the account reply")
        }
        #expect(StubURLProtocol.requests(host: host).count == 1)
    }

    @Test("first-run-onboarding/a-working-provider-is-saved-once: a playlist downloads once and is saved")
    func playlistSaved() async throws {
        let host = "saved-playlist.test"
        StubURLProtocol.register(host: host, body: "#EXTM3U\n#EXTINF:-1 group-title=\"News\",One\nhttp://\(host)/1.ts\n")
        let model = model(tag: host)
        model.fields = SourceFields(kind: .m3u, name: "Lists", url: "http://\(host)/tv.m3u", epgURL: "http://\(host)/guide.xml")
        await model.connect(into: context)
        let connection = try #require(model.connection)
        if case .playlist(let playlist) = connection.reply {
            #expect(playlist.channels.map(\.name) == ["One"])
        } else {
            Issue.record("expected the playlist reply")
        }
        let record = try #require(try sources().first)
        #expect(record.name == "Lists")
        #expect(record.epgURL?.absoluteString == "http://\(host)/guide.xml")
        #expect(record.credentialKey == nil)
    }

    @Test("first-run-onboarding/a-working-provider-is-saved-once: the same provider from another device is reused")
    func reused() async throws {
        let host = "reused.test"
        StubURLProtocol.register(host: host, body: Self.account)
        let existing = SourceDescriptor(name: "From iPhone", kind: .xtream, url: try #require(URL(string: "http://REUSED.test:8080/")))
        context.insert(SourceRecord(descriptor: existing, sortOrder: 0))
        try context.save()

        let model = model(tag: host)
        model.fields = SourceFields(kind: .xtream, url: "http://reused.test:8080", username: "anna", password: "pw")
        await model.connect(into: context)
        let connection = try #require(model.connection)
        #expect(!connection.inserted)
        #expect(connection.descriptor.id == existing.id)
        #expect(try sources().count == 1)
        let key = try #require(try sources().first?.credentialKey)
        #expect(try held.load(for: key)?.username == "anna")
    }

    @Test("first-run-onboarding/a-working-provider-is-saved-once: the Keychain refuses the password")
    func keychainRefuses() async throws {
        let host = "keychain-refuses.test"
        StubURLProtocol.register(host: host, body: Self.account)
        let model = model(tag: host, credentials: FailingCredentialStore())
        model.fields = SourceFields(kind: .xtream, url: "http://\(host)", username: "anna", password: "pw")
        await model.connect(into: context)
        #expect(model.error?.hasPrefix("Could not store credentials") == true)
        #expect(try sources().isEmpty)
    }

    @Test("first-run-onboarding/fill-the-form-from-a-copied-link: the clipboard is read only on Fill in")
    func fillIn() async throws {
        let reads = Counter()
        var text = "http://tv.example.test:8080/get.php?username=anna&password=pw"
        let clipboard = Clipboard(
            hasLink: { true },
            read: {
                reads.value += 1; return text
            })
        let model = model(tag: "clipboard", clipboard: clipboard)
        await model.lookForLink()
        #expect(model.clipboardOffer == .link)
        #expect(reads.value == 0)
        model.fillIn()
        #expect(reads.value == 1)
        #expect(model.fields.kind == .xtream)
        #expect(model.fields.url == "http://tv.example.test:8080")
        #expect(model.fields.username == "anna")
        #expect(model.fields.password == "pw")

        text = "not a link"
        let second = self.model(tag: "clipboard-2", clipboard: Clipboard(hasLink: { true }, read: { text }))
        await second.lookForLink()
        second.fillIn()
        #expect(second.clipboardOffer == .noLink)
        #expect(second.fields == SourceFields())
    }

    @Test("first-run-onboarding/fill-the-form-from-a-copied-link: no banner without a clipboard, as on Mac")
    func noBannerOnMac() async {
        let model = model(tag: "mac")
        await model.lookForLink()
        #expect(model.clipboardOffer == .hidden)
    }
}
