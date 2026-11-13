import AntennaCore
import Foundation
import SwiftData
import Testing

@testable import Antenna

/// A playlist added from an Xtream panel link: the add form's offer and the
/// switch to Xtream from the source's details, against an in-memory store,
/// stubbed panels and an in-memory Keychain.
@MainActor
@Suite struct XtreamPanelSwitchTests {
    let container: ModelContainer
    let held = HeldCredentialStore()

    init() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: Schema(AntennaSchema.models), configurations: configuration)
    }

    private var context: ModelContext { container.mainContext }

    private static let account = #"{"user_info":{"status":"Active","auth":1}}"#

    private func panelLink(_ host: String) -> String {
        "http://\(host):8080/get.php?username=anna&password=s3cret&type=m3u_plus&output=ts"
    }

    @discardableResult
    private func insert(_ name: String, kind: SourceKind, url: String, key: String? = nil, order: Int = 0) throws -> SourceRecord {
        let record = SourceRecord(
            descriptor: SourceDescriptor(
                id: UUID(), name: name, kind: kind, url: try #require(URL(string: url)), epgURL: URL(string: "http://epg.test/mine.xml"),
                credentialKey: key),
            sortOrder: order)
        context.insert(record)
        try context.save()
        return record
    }

    private func editor(_ record: SourceRecord, tag: String) throws -> SourceEditor {
        SourceEditor(
            try #require(record.descriptor), connector: SourceConnector(session: StubURLProtocol.session(tag: tag), credentials: held))
    }

    private func channel(_ id: String, _ link: String, source: UUID) throws -> Channel {
        Channel(id: id, name: id, streamURL: try #require(URL(string: link)), sourceID: source)
    }

    @Test("source-management/the-add-form-offers-xtream-for-a-panel-link: Use Xtream fills the login and keeps the name")
    func formOffer() throws {
        let model = OnboardingModel(connector: SourceConnector(credentials: held), clipboard: nil)
        model.choose(.m3u)
        model.fields.name = "Home"
        model.fields.url = "http://tv.example.net/list.m3u"
        #expect(model.fields.xtreamPanel == nil)
        model.fields.url = panelLink("tv.example.net")
        #expect(model.fields.xtreamPanel != nil)
        model.useXtream()
        #expect(model.fields.kind == .xtream)
        #expect(model.fields.name == "Home")
        #expect(model.fields.url == "http://tv.example.net:8080")
        #expect(model.fields.username == "anna")
        #expect(model.fields.password == "s3cret")
    }

    @Test("source-management/a-playlist-source-switches-to-xtream-in-place: same source, login in the Keychain, favorites follow")
    func switchInPlace() async throws {
        let host = "switch-works.test"
        StubURLProtocol.register(host: host, body: Self.account)
        try insert("First", kind: .m3u, url: "http://first.test/list.m3u", order: 0)
        let record = try insert("Home", kind: .m3u, url: panelLink(host), order: 1)
        let source = record.id
        let channels = [
            try channel("m3u.aaa", "http://\(host):8080/anna/s3cret/101", source: source),
            try channel("m3u.bbb", "http://\(host):8080/movie/anna/s3cret/900.mkv", source: source),
        ]
        context.insert(FavoriteRecord(channelID: "m3u.aaa", sourceID: source, sortOrder: 0))
        context.insert(FavoriteRecord(channelID: "m3u.bbb", sourceID: source, sortOrder: 1))
        context.insert(GroupMemberRecord(groupID: UUID(), channelID: "m3u.aaa", sourceID: source, sortOrder: 0))
        try context.save()

        let editor = try editor(record, tag: host)
        #expect(editor.xtreamPanel != nil)
        let descriptor = try #require(await editor.switchToXtream(channels: channels, in: context))

        #expect(descriptor.id == source)
        #expect(record.kind == .xtream)
        #expect(record.name == "Home")
        #expect(record.sortOrder == 1)
        #expect(record.url?.absoluteString == "http://\(host):8080")
        #expect(record.epgURL?.absoluteString == "http://epg.test/mine.xml")
        #expect(record.url?.absoluteString.contains("s3cret") == false)
        let key = try #require(record.credentialKey)
        #expect(!key.contains("s3cret"))
        #expect(try held.load(for: key) == .init(username: "anna", password: "s3cret"))
        let favorites = try context.fetch(FetchDescriptor<FavoriteRecord>(sortBy: [SortDescriptor(\.sortOrder)])).map(\.channelID)
        #expect(favorites == ["xtream#\(host)#101", "m3u.bbb"])
        let members = try context.fetch(FetchDescriptor<GroupMemberRecord>()).map(\.channelID)
        #expect(members == ["xtream#\(host)#101"])
        #expect(StubURLProtocol.requests(host: host).count == 1)
    }

    @Test("source-management/a-playlist-source-switches-to-xtream-in-place: a login the panel turns down changes nothing")
    func switchRefused() async throws {
        let host = "switch-refused.test"
        StubURLProtocol.register(host: host, status: 401, body: "{}")
        let record = try insert("Home", kind: .m3u, url: panelLink(host))
        let editor = try editor(record, tag: host)
        #expect(await editor.switchToXtream(channels: [], in: context) == nil)
        #expect(editor.error == "Could not sign in. Check the username and password.")
        #expect(record.kind == .m3u)
        #expect(record.credentialKey == nil)
        #expect(record.url?.absoluteString == panelLink(host))
    }

    @Test("source-management/a-playlist-source-switches-to-xtream-in-place: an Xtream login already added is refused")
    func switchDuplicate() async throws {
        let host = "switch-duplicate.test"
        try held.save(.init(username: "anna", password: "s3cret"), for: "existing")
        try insert("Xtream", kind: .xtream, url: "http://\(host):8080", key: "existing")
        let record = try insert("Home", kind: .m3u, url: panelLink(host), order: 1)
        let editor = try editor(record, tag: host)
        #expect(await editor.switchToXtream(channels: [], in: context) == nil)
        #expect(editor.error == "This source is already added.")
        #expect(record.kind == .m3u)
        #expect(StubURLProtocol.requestCount(tag: host) == 0)
    }

    @Test("source-management/a-playlist-source-switches-to-xtream-in-place: an ordinary playlist offers no switch")
    func noOfferForPlaylist() throws {
        let record = try insert("Plain", kind: .m3u, url: "http://plain.test/list.m3u")
        #expect(try editor(record, tag: "plain").xtreamPanel == nil)
    }
}
