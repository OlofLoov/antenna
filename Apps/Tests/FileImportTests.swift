import AntennaCore
import Foundation
import SwiftData
import Synchronization
import Testing

@testable import Antenna

/// Saving, loading, re-importing and deleting imported playlist files
/// (local-m3u-file-import capability), in an in-memory store with an
/// in-memory Keychain.
@MainActor
@Suite struct FileImportTests {
    let container: ModelContainer
    let held = HeldCredentialStore()

    init() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: Schema(AntennaSchema.models), configurations: configuration)
    }

    private var context: ModelContext { container.mainContext }

    static let withLogins = """
        #EXTM3U url-tvg="http://panel.example.com/xmltv.php?username=u1&password=p1"
        #EXTINF:-1 tvg-id="one" group-title="News",One
        http://panel.example.com/live/u1/p1/1.ts
        #EXTINF:-1 tvg-id="two" group-title="Sport",Two
        http://panel.example.com/get.php?username=u1&password=p1&stream=2
        #EXTINF:-1 tvg-id="three" group-title="Sport",Three
        http://u2:p2@cdn.example.com:8080/3.m3u8
        #EXTINF:-1,Broken
        not a link

        """

    static func inspected(_ text: String) throws -> PlaylistImport.Inspected {
        guard case .playlist(let inspected) = PlaylistImport.inspect(Data(text.utf8)) else {
            throw CancellationError()
        }
        return inspected
    }

    private func loader(tag: String) -> SourceLoader {
        SourceLoader(
            session: StubURLProtocol.session(tag: tag), credentials: held, files: PlaylistFileStore(container: container))
    }

    private func importFile(_ text: String = Self.withLogins, name: String = "", replacing: UUID? = nil) throws -> SourceRecord {
        try FileImport(credentials: held).save(
            .init(inspected: try Self.inspected(text), fileName: "home-playlist.m3u", name: name, replacing: replacing), into: context)
    }

    @Test("local-m3u-file-import/import-and-watch: channels load from the store, match the summary and make no request")
    func importAndLoad() async throws {
        let record = try importFile()
        #expect(record.kind == .m3uFile)
        #expect(record.name == "home-playlist")
        #expect(record.url == nil)
        let inspected = try Self.inspected(Self.withLogins)
        let tag = UUID().uuidString
        let source = try #require(record.descriptor)
        #expect(loader(tag: tag).hasLogin(source))
        let playlist = try await loader(tag: tag).load(source)
        #expect(playlist.channels.count == inspected.playlist.channels.count)
        #expect(playlist.channels.map(\.name) == ["One", "Two", "Three"])
        #expect(playlist.channels[0].streamURL.absoluteString == "http://panel.example.com/live/u1/p1/1.ts")
        #expect(playlist.epgURLs.first?.absoluteString == "http://panel.example.com/xmltv.php?username=u1&password=p1")
        #expect(StubURLProtocol.requestCount(tag: tag) == 0)
    }

    @Test("local-m3u-file-import/logins-in-stream-links-stay-private: the synced record holds no login")
    func noLoginInStore() throws {
        let record = try importFile()
        let stored = String(decoding: try #require(record.playlistData), as: UTF8.self)
        for secret in ["u1", "p1", "u2", "p2"] {
            #expect(!stored.contains("=\(secret)&") && !stored.contains("/\(secret)/") && !stored.contains("\(secret)@"))
        }
        #expect(record.epgURL == nil)
        let key = try #require(record.credentialKey)
        let logins = try #require(try StreamLoginStore(credentials: held).load(for: key))
        #expect(logins.map(\.username) == ["u1", "u2"])
    }

    @Test("local-m3u-file-import/logins-in-stream-links-stay-private: channel ids never hold a login")
    func idsWithoutLogins() async throws {
        let source = try #require(try importFile().descriptor)
        let playlist = try await loader(tag: UUID().uuidString).load(source)
        #expect(playlist.channels.allSatisfy { !$0.id.contains("p1") && !$0.id.contains("p2") })
    }

    @Test("local-m3u-file-import/channels-reach-apple-tv: a login not on this device waits instead of loading")
    func waitingForLogin() throws {
        let record = try importFile()
        let source = try #require(record.descriptor)
        try held.delete(for: try #require(record.credentialKey))
        #expect(!loader(tag: "").hasLogin(source))
        #expect(!loader(tag: "").waitsForICloud(source))
    }

    @Test("local-m3u-file-import/channels-reach-apple-tv: a record without its text waits for iCloud")
    func waitingForICloud() async throws {
        let record = try importFile("#EXTM3U\n#EXTINF:-1,One\nhttp://example.com/1.ts\n")
        record.playlistData = nil
        try context.save()
        let source = try #require(record.descriptor)
        #expect(loader(tag: "").waitsForICloud(source))
        #expect(!loader(tag: "").hasLogin(source))
        await #expect(throws: SourceLoader.LoadError.waitingForICloud) { try await loader(tag: "").load(source) }
    }

    @Test("local-m3u-file-import/logins-in-stream-links-stay-private: an unusable login fails without a request")
    func unreadableLogin() async throws {
        let record = try importFile()
        let key = try #require(record.credentialKey)
        try StreamLoginStore(credentials: held).save([], for: key)
        let tag = UUID().uuidString
        let source = try #require(record.descriptor)
        await #expect(throws: SourceLoader.LoadError.loginUnreadable) { try await loader(tag: tag).load(source) }
        try held.save(.init(username: "someone", password: "secret"), for: key)
        await #expect(throws: SourceLoader.LoadError.loginUnreadable) { try await loader(tag: tag).load(source) }
        #expect(StubURLProtocol.requestCount(tag: tag) == 0)
    }

    @Test("local-m3u-file-import/re-import-onto-the-same-source: Replace keeps the record, its place and its channel ids")
    func reimport() async throws {
        let first = try importFile(name: "Home")
        first.sortOrder = 3
        let firstIDs = try await loader(tag: "").load(try #require(first.descriptor)).channels.map(\.id)
        context.insert(FavoriteRecord(channelID: firstIDs[1], sourceID: first.id))
        let newer = Self.withLogins.replacingOccurrences(of: "p1", with: "p9") + "#EXTINF:-1,Four\nhttp://example.com/4.ts\n"
        let replaced = try importFile(newer, replacing: first.id)
        #expect(replaced.id == first.id)
        #expect(replaced.name == "Home")
        #expect(replaced.sortOrder == 3)
        #expect(try context.fetchCount(FetchDescriptor<SourceRecord>()) == 1)
        let playlist = try await loader(tag: "").load(try #require(replaced.descriptor))
        #expect(Array(playlist.channels.map(\.id).prefix(3)) == firstIDs)
        #expect(playlist.channels[0].streamURL.absoluteString == "http://panel.example.com/live/u1/p9/1.ts")
        #expect(playlist.channels.count == 4)
        let favorite = try #require(try context.fetch(FetchDescriptor<FavoriteRecord>()).first)
        #expect(playlist.channels.contains { $0.id == favorite.channelID } && favorite.sourceID == replaced.id)
    }

    @Test("local-m3u-file-import/re-import-onto-the-same-source: a file without logins removes the old login")
    func reimportWithoutLogins() throws {
        let first = try importFile()
        let key = try #require(first.credentialKey)
        let replaced = try importFile("#EXTM3U\n#EXTINF:-1,One\nhttp://example.com/1.ts\n", replacing: first.id)
        #expect(replaced.credentialKey == nil)
        #expect(try held.load(for: key) == nil)
    }

    @Test("local-m3u-file-import/re-import-onto-the-same-source: Replace after the source was deleted inserts a new one")
    func replaceDeleted() throws {
        let record = try importFile(replacing: UUID())
        #expect(record.kind == .m3uFile)
        #expect(try context.fetchCount(FetchDescriptor<SourceRecord>()) == 1)
    }

    @Test("local-m3u-file-import/see-what-s-in-the-file-before-importing: the earlier import of the same file name")
    func importedBefore() throws {
        let later = try importFile(name: "Later")
        later.sortOrder = 2
        let earlier = try importFile(name: "Earlier")
        earlier.sortOrder = 1
        #expect(FileImport.importedBefore("home-playlist.m3u", in: context)?.name == "Earlier")
        #expect(FileImport.importedBefore("other.m3u", in: context) == nil)
    }

    @Test("local-m3u-file-import/deleting-removes-everything: the record, its text and its login go")
    func delete() throws {
        let record = try importFile()
        let key = try #require(record.credentialKey)
        SourceRecord.delete(record, from: context, credentials: held)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<SourceRecord>()) == 0)
        #expect(try held.load(for: key) == nil)
    }

    @Test("local-m3u-file-import/import-and-watch: the guide link field is stored only when it differs from the header")
    func guideLink() throws {
        let header = URL(string: "http://guide.example.com/a.xml")
        #expect(FileImport.guideLink("http://guide.example.com/a.xml", header: header) == nil)
        #expect(FileImport.guideLink("not a link", header: header) == nil)
        #expect(FileImport.guideLink(" http://other.example.com/b.xml ", header: header)?.host() == "other.example.com")
    }

    @Test("local-m3u-file-import/import-and-watch: Refresh all and the schedule skip a file source")
    func noRefresh() async throws {
        let file = try #require(try importFile().descriptor)
        let link = SourceDescriptor(name: "Link", kind: .m3u, url: try #require(URL(string: "http://link.example.com/a.m3u")))
        let files = PlaylistFileStore(container: container)
        let loader = SourceLoader(session: StubURLProtocol.session(tag: UUID().uuidString), credentials: held, files: files)
        var dependencies = SourceRefresher.Dependencies(
            load: { source in
                source.kind == .m3uFile ? try await loader.load(source) : Playlist(channels: [])
            },
            hasLogin: { loader.hasLogin($0) })
        dependencies.lastLoads = LastLoadStore(defaults: try #require(UserDefaults(suiteName: "file-\(UUID().uuidString)")))
        let clock = Mutex(Date(timeIntervalSince1970: 1_800_000_000))
        dependencies.now = { clock.withLock { $0 } }
        let refresher = SourceRefresher(dependencies)
        var asked: [[UUID]] = []
        refresher.attach { asked.append($0) }
        _ = try await refresher.load(file)
        _ = try await refresher.load(link)
        #expect(refresher.status(of: file.id).channels == 3)
        refresher.refresh([file.id, link.id])
        clock.withLock { $0 += 3600 }
        #expect(refresher.due(interval: .seconds(60)) == [link.id])
        #expect(asked == [[link.id]])
    }
}
