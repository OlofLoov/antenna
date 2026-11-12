import AntennaCore
import Foundation
import SwiftData
import Testing

@testable import Antenna

/// Source details, reordering, delete and preferences against an in-memory
/// store, stubbed servers and an in-memory Keychain.
@MainActor
@Suite struct SourcesSettingsTests {
    let container: ModelContainer
    let held = HeldCredentialStore()

    init() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: Schema(AntennaSchema.models), configurations: configuration)
    }

    private var context: ModelContext { container.mainContext }

    typealias Login = CredentialStore.Credential

    private static let account = #"{"user_info":{"status":"Active","auth":1}}"#

    @discardableResult
    private func insert(_ name: String, kind: SourceKind, url: String, login: Login? = nil, order: Int = 0) throws -> SourceRecord {
        let id = UUID()
        let key = login.map { _ in id.uuidString }
        if let login, let key { try held.save(login, for: key) }
        let record = SourceRecord(
            descriptor: SourceDescriptor(id: id, name: name, kind: kind, url: try #require(URL(string: url)), credentialKey: key),
            sortOrder: order)
        context.insert(record)
        try context.save()
        return record
    }

    private func editor(_ record: SourceRecord, tag: String) throws -> SourceEditor {
        SourceEditor(
            try #require(record.descriptor), connector: SourceConnector(session: StubURLProtocol.session(tag: tag), credentials: held))
    }

    @Test("sources-and-settings/your-password-stays-hidden: the username shows, the password field is empty and an empty field keeps it")
    func passwordHidden() async throws {
        let record = try insert("Home", kind: .xtream, url: "http://hidden.test", login: .init(username: "anna", password: "s3cret"))
        let editor = try editor(record, tag: "hidden")
        #expect(editor.username == "anna")
        #expect(editor.password.isEmpty)
        #expect(!Mirror(reflecting: editor).children.contains { ($0.value as? String) == "s3cret" })
        editor.name = "Home TV"
        #expect(await editor.save(in: context))
        #expect(StubURLProtocol.requestCount(tag: "hidden") == 0)
        #expect(record.name == "Home TV")
        #expect(try held.load(for: try #require(record.credentialKey))?.password == "s3cret")
    }

    @Test("sources-and-settings/fix-a-source-s-link-or-login: a changed login that works is saved")
    func changeWorks() async throws {
        let host = "change-works.test"
        StubURLProtocol.register(host: host, body: Self.account)
        let record = try insert("Home", kind: .xtream, url: "http://old-\(host)", login: .init(username: "anna", password: "old"))
        let editor = try editor(record, tag: host)
        editor.link = "http://\(host)"
        editor.password = "new"
        #expect(await editor.save(in: context))
        #expect(record.url?.absoluteString == "http://\(host)")
        #expect(try held.load(for: try #require(record.credentialKey)) == .init(username: "anna", password: "new"))
        #expect(editor.password.isEmpty)
    }

    @Test("sources-and-settings/fix-a-source-s-link-or-login: a change the server refuses changes nothing")
    func changeFails() async throws {
        let host = "change-fails.test"
        StubURLProtocol.register(host: host, status: 401, body: "{}")
        let record = try insert("Home", kind: .xtream, url: "http://\(host)", login: .init(username: "anna", password: "old"))
        let editor = try editor(record, tag: host)
        editor.name = "Renamed"
        editor.password = "wrong"
        #expect(await !editor.save(in: context))
        #expect(editor.error == "Could not sign in. Check the username and password.")
        #expect(record.name == "Home")
        #expect(try held.load(for: try #require(record.credentialKey))?.password == "old")
    }

    @Test("sources-and-settings/fix-a-source-s-link-or-login: a bad or duplicate link is refused")
    func badOrDuplicate() async throws {
        try insert("Other", kind: .m3u, url: "http://dup.test/list.m3u", order: 0)
        let record = try insert("Mine", kind: .m3u, url: "http://mine.test/list.m3u", order: 1)
        let editor = try editor(record, tag: "dup")
        editor.link = "mine.test/list.m3u"
        #expect(await !editor.save(in: context))
        #expect(editor.error == "Enter a valid URL.")
        editor.link = "HTTP://DUP.test/list.m3u/"
        #expect(await !editor.save(in: context))
        #expect(editor.error == "This source is already added.")
        #expect(StubURLProtocol.requestCount(tag: "dup") == 0)
        #expect(record.url?.absoluteString == "http://mine.test/list.m3u")
    }

    @Test("sources-and-settings/sign-in-on-this-apple-tv: a login typed here loads the source")
    func signIn() async throws {
        let host = "sign-in.test"
        StubURLProtocol.register(host: host, body: Self.account)
        let record = try insert("Family", kind: .xtream, url: "http://\(host)")
        record.credentialKey = "missing-\(UUID().uuidString)"
        let editor = try editor(record, tag: host)
        #expect(!editor.hasLogin)
        editor.username = "anna"
        #expect(await !editor.save(in: context))
        #expect(editor.error == "Enter your username and password.")
        editor.password = "pw"
        #expect(await editor.save(in: context))
        #expect(editor.hasLogin)
        #expect(try held.load(for: try #require(record.credentialKey))?.username == "anna")
    }

    @Test("sources-and-settings/put-sources-in-your-order: the last source moves to the top and nothing reloads")
    func reorder() async throws {
        let tag = "order-\(UUID().uuidString)"
        let hosts = ["one.test", "two.test", "three.test"]
        for (index, host) in hosts.enumerated() {
            StubURLProtocol.register(host: host, body: "#EXTM3U\n#EXTINF:-1,\(host)\nhttp://\(host)/1.ts\n")
            try insert(host, kind: .m3u, url: "http://\(host)/tv.m3u", order: index)
        }
        let live = LiveModel(.live(loader: SourceLoader(session: StubURLProtocol.session(tag: tag), credentials: held), guide: nil))
        let ordered = { try self.context.fetch(FetchDescriptor<SourceRecord>(sortBy: SourceRecord.displayOrder)) }
        live.sourcesChanged(try ordered().compactMap(\.descriptor))
        await live.settled()
        var records = try ordered()
        let last = try #require(records.last)
        SourceOrder.move(last, by: -1, among: records, in: context)
        records = try ordered()
        SourceOrder.move(try #require(records.last { $0.name == "three.test" }), by: -1, among: records, in: context)
        live.sourcesChanged(try ordered().compactMap(\.descriptor))
        await live.settled()
        #expect(try ordered().map(\.name) == ["three.test", "one.test", "two.test"])
        #expect(live.channels.map(\.name) == ["three.test", "one.test", "two.test"])
        #expect(StubURLProtocol.requestCount(tag: tag) == 3)
    }

    @Test("sources-and-settings/delete-a-source-and-everything-that-came-with-it: the source, login, favorites and channels go")
    func delete() async throws {
        let record = try insert("Home", kind: .xtream, url: "http://delete.test", login: .init(username: "anna", password: "pw"))
        let key = try #require(record.credentialKey)
        context.insert(FavoriteRecord(channelID: "1", sourceID: record.id, sortOrder: 0))
        context.insert(FavoriteRecord(channelID: "2", sourceID: record.id, sortOrder: 1, profileID: UUID()))
        context.insert(FavoriteRecord(channelID: "3", sourceID: UUID(), sortOrder: 2))
        try context.save()
        #expect(SourceRemoval.favorites(of: record.id, in: context) == 2)
        #expect(
            SourceRemoval.message(channels: 412, favorites: 2, signedInToICloud: true)
                == "Removes its 412 channels, 2 favorites and guide from every device signed in to your iCloud account.")
        #expect(SourceRemoval.message(channels: nil, favorites: 0, signedInToICloud: false) == "Removes its guide from this device.")
        #expect(SourceRemoval.title(name: "Home") == "Delete Home?")

        await SourceRemoval(credentials: held).delete(record, in: context)
        #expect(try context.fetch(FetchDescriptor<SourceRecord>()).isEmpty)
        #expect(try held.load(for: key) == nil)
        #expect(try context.fetch(FetchDescriptor<FavoriteRecord>()).map(\.channelID) == ["3"])
        // sources-and-settings/delete-a-source-and-everything-that-came-with-it: the last source gone opens onboarding.
        #expect(OnboardingRoute(sourceCount: 0) == .welcome)
    }

    @Test("sources-and-settings/delete-a-source-and-everything-that-came-with-it: a playing channel of the deleted source stops")
    func deleteStopsPlayback() async throws {
        let tag = "delete-playing-\(UUID().uuidString)"
        let host = "delete-playing.test"
        StubURLProtocol.register(host: host, body: "#EXTM3U\n#EXTINF:-1,One\nhttp://\(host)/1.ts\n")
        let other = try #require(URL(string: "http://kept.test/tv.m3u"))
        let source = SourceDescriptor(name: "Gone", kind: .m3u, url: try #require(URL(string: "http://\(host)/tv.m3u")))
        let kept = SourceDescriptor(name: "Kept", kind: .m3u, url: other)
        let live = LiveModel(.live(loader: SourceLoader(session: StubURLProtocol.session(tag: tag), credentials: held), guide: nil))
        live.sourcesChanged([source, kept])
        await live.settled()
        live.pick(try #require(live.channels.first))
        #expect(live.playing != nil)
        live.sourcesChanged([kept])
        #expect(live.playing == nil)
    }

    @Test("sources-and-settings/choose-how-the-app-behaves: showing preferences inserts nothing and duplicates resolve to the newest")
    func preferences() throws {
        #expect(PreferencesStore.current(in: context) == AppPreferences())
        #expect(try context.fetchCount(FetchDescriptor<PreferencesRecord>()) == 0)
        #expect(AppPreferences() == AppPreferences(openOnLaunch: .live, guideHours: 2, refresh: .twelve, swipe: .changesChannel))

        let older = PreferencesRecord()
        older.store(AppPreferences(guideHours: 3), at: Date(timeIntervalSince1970: 100))
        let newer = PreferencesRecord()
        newer.store(AppPreferences(refresh: .manual), at: Date(timeIntervalSince1970: 200))
        context.insert(older)
        context.insert(newer)
        try context.save()
        #expect(PreferencesStore.current(in: context).refresh == .manual)
        #expect(try context.fetchCount(FetchDescriptor<PreferencesRecord>()) == 1)
        #expect(AppPreferences.winner([(id: "b", updated: .distantPast), (id: "a", updated: .distantPast)]) == "a")
    }

    @Test("sources-and-settings/choose-how-the-app-behaves: each change applies on this device")
    func preferencesApply() throws {
        var preferences = AppPreferences()
        preferences.openOnLaunch = .movies
        preferences.refresh = .six
        preferences.swipe = .showsZapBar
        PreferencesStore.save(preferences, in: context)
        let stored = PreferencesStore.current(in: context)
        #expect(stored.launchScreen(offersMovies: true) == .movies)
        // A stored Movies opens Live where Movies is not offered, and nothing is written.
        #expect(stored.launchScreen(offersMovies: false) == .live)
        #expect(stored.refresh.duration == .seconds(6 * 3600))
        #expect(AppPreferences.RefreshInterval.manual.duration == nil)
        #expect(stored.swipe == .showsZapBar)
        preferences.guideHours = 4
        PreferencesStore.save(preferences, in: context)
        #expect(PreferencesStore.current(in: context).guideHours == 4)
        #expect(try context.fetchCount(FetchDescriptor<PreferencesRecord>()) == 1)
    }
}
