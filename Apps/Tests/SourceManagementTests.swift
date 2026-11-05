import AntennaCore
import Foundation
import Security
import SwiftData
import SwiftUI
import Synchronization
import Testing

#if os(iOS)
    import UIKit
#endif

@testable import Antenna

/// Spec 0004. Records live in an in-memory container with CloudKit off.
/// Credentials go to the simulator Keychain under a service of their own per
/// test, except AC-4, which checks the production service and removes its item.
@MainActor
@Suite struct SourceManagementTests {
    let container: ModelContainer
    let store = CredentialStore(service: "se.codecrave.antenna.tests.\(UUID().uuidString)")
    /// For criteria that need a credential to exist but assert nothing about the Keychain.
    let held = HeldCredentialStore()

    init() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: SourceRecord.self, FavoriteRecord.self, configurations: configuration)
    }

    private var context: ModelContext { container.mainContext }

    private func records() throws -> [SourceRecord] {
        try context.fetch(FetchDescriptor<SourceRecord>(sortBy: SourceRecord.displayOrder))
    }

    private func descriptors() throws -> [SourceDescriptor] {
        try records().compactMap(\.descriptor)
    }

    private func insert(_ kind: SourceKind, url: String, sortOrder: Int, credentialKey: String? = nil) throws -> SourceRecord {
        let descriptor = SourceDescriptor(name: url, kind: kind, url: try #require(URL(string: url)), credentialKey: credentialKey)
        let record = SourceRecord(descriptor: descriptor, sortOrder: sortOrder)
        context.insert(record)
        return record
    }

    /// Registers a two-channel playlist at `host` and returns its URL.
    private func twoChannelPlaylist(host: String) -> String {
        StubURLProtocol.register(
            host: host,
            body: """
                #EXTM3U
                #EXTINF:-1,\(host) one
                http://\(host)/1.ts
                #EXTINF:-1,\(host) two
                http://\(host)/2.ts
                """)
        return "http://\(host)/list.m3u"
    }

    private func load(credentials: any CredentialStoring) async throws -> ChannelListModel {
        let model = ChannelListModel()
        await model.load(try descriptors(), using: SourceLoader(session: StubURLProtocol.session(), credentials: credentials))
        return model
    }

    /// The `localizedDescription` the stub session produces for a request to `url`.
    private func failureDescription(_ url: String) async throws -> String {
        do {
            _ = try await StubURLProtocol.session().data(from: try #require(URL(string: url)))
        } catch {
            return error.localizedDescription
        }
        Issue.record("expected \(url) to fail")
        return ""
    }

    // MARK: Saving

    @Test("0004/AC-1 invalid URL is rejected")
    func invalidURL() throws {
        let form = NewSource(kind: .m3u, url: "example.com/list.m3u")
        #expect(throws: NewSource.SaveError.invalidURL) { try form.save(into: context, credentials: store) }
        #expect(NewSource.SaveError.invalidURL.message == "Enter a valid URL.")
        #expect(try records().isEmpty)
    }

    @Test("0004/AC-2 M3U source is saved")
    func m3uSaved() throws {
        _ = try insert(.m3u, url: "http://a.test/a.m3u", sortOrder: 0)
        _ = try insert(.m3u, url: "http://b.test/b.m3u", sortOrder: 1)

        let form = NewSource(kind: .m3u, name: "Mine", url: "http://example.com/list.m3u", epgURL: "http://example.com/epg.xml")
        let saved = try form.save(into: context, credentials: store)

        #expect(try records().count == 3)
        #expect(saved.kind == .m3u)
        #expect(saved.url == URL(string: "http://example.com/list.m3u"))
        #expect(saved.epgURL == URL(string: "http://example.com/epg.xml"))
        #expect(saved.credentialKey == nil)
        #expect(saved.sortOrder == 2)
    }

    @Test("0004/AC-3 name defaults to host")
    func nameDefaultsToHost() throws {
        let saved = try NewSource(kind: .m3u, url: "http://example.com/list.m3u").save(into: context, credentials: store)
        #expect(saved.name == "example.com")
    }

    @Test("0004/AC-4 Xtream credentials go to the Keychain only")
    func xtreamCredentialsInKeychain() throws {
        let username = "ac4-user-\(UUID().uuidString)"
        let password = "ac4-pass-\(UUID().uuidString)"
        let production = CredentialStore()
        let form = NewSource(kind: .xtream, name: "Panel", url: "http://panel.test:8080", username: username, password: password)

        let saved = try form.save(into: context, credentials: production)
        defer { try? production.delete(for: saved.id.uuidString) }

        #expect(saved.credentialKey == saved.id.uuidString)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "se.codecrave.antenna.sources",
            kSecAttrAccount as String: saved.id.uuidString,
            kSecAttrSynchronizable as String: true,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        #expect(SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess)
        let attributes = try #require(item as? [String: Any])
        #expect((attributes[kSecAttrSynchronizable as String] as? NSNumber)?.boolValue == true)

        let stored = [saved.name, saved.kindRaw, saved.url?.absoluteString, saved.epgURL?.absoluteString, saved.credentialKey]
            .compactMap(\.self)
        #expect(!stored.contains { $0.contains(username) || $0.contains(password) })
    }

    @Test("0004/AC-5 Keychain failure blocks the save")
    func keychainFailureBlocksSave() throws {
        let form = NewSource(kind: .xtream, url: "http://panel.test", username: "u", password: "p")
        do {
            try form.save(into: context, credentials: FailingCredentialStore())
            Issue.record("save succeeded")
        } catch {
            #expect(error.message.hasPrefix("Could not store credentials"))
        }
        #expect(try records().isEmpty)
    }

    @Test("0004/AC-13 Stalker type is stored")
    func stalkerStored() throws {
        let form = NewSource(kind: .stalker, url: "http://portal.test/c/", username: "00:1A:79:00:00:01", password: "secret")
        let saved = try form.save(into: context, credentials: store)
        defer { try? store.delete(for: saved.id.uuidString) }

        #expect(saved.kind == .stalker)
        #expect(try store.load(for: saved.id.uuidString) == .init(username: "00:1A:79:00:00:01", password: "secret"))
    }

    // MARK: Deleting

    @Test("0004/AC-6 deleting a source removes its credential")
    func deleteRemovesCredential() throws {
        let form = NewSource(kind: .xtream, url: "http://panel.test", username: "u", password: "p")
        let saved = try form.save(into: context, credentials: store)
        let key = try #require(saved.credentialKey)
        #expect(try store.load(for: key) != nil)

        SourceRecord.delete(saved, from: context, credentials: store)

        #expect(try records().isEmpty)
        #expect(try store.load(for: key) == nil)
    }

    // MARK: Loading

    @Test("0004/AC-9 channels from all sources are combined in sortOrder")
    func combined() async throws {
        let host = "ac9-xtream.test"
        StubURLProtocol.register(host: host, action: "get_live_categories", body: #"[{"category_id":"1","category_name":"News"}]"#)
        StubURLProtocol.register(
            host: host, action: "get_live_streams",
            body: #"[{"stream_id":1,"name":"X1","category_id":"1"},{"stream_id":2,"name":"X2"},{"stream_id":3,"name":"X3"}]"#)
        let key = UUID().uuidString
        try held.save(.init(username: "u", password: "p"), for: key)
        defer { try? held.delete(for: key) }
        _ = try insert(.xtream, url: "http://\(host)", sortOrder: 1, credentialKey: key)
        _ = try insert(.m3u, url: twoChannelPlaylist(host: "ac9-m3u.test"), sortOrder: 0)

        let model = try await load(credentials: held)

        #expect(model.channels.map(\.name) == ["ac9-m3u.test one", "ac9-m3u.test two", "X1", "X2", "X3"])
        #expect(model.channels.first { $0.name == "X1" }?.group == "News")
    }

    @Test("0004/AC-10 missing Keychain item yields no channels")
    func missingCredential() async throws {
        _ = try insert(.xtream, url: "http://ac10-xtream.test", sortOrder: 0, credentialKey: UUID().uuidString)
        _ = try insert(.m3u, url: twoChannelPlaylist(host: "ac10-m3u.test"), sortOrder: 1)

        let model = try await load(credentials: store)

        #expect(model.channels.count == 2)
        #expect(StubURLProtocol.requests(host: "ac10-xtream.test").isEmpty)
    }

    @Test("0004/AC-16 nil credential key yields no channels")
    func nilCredentialKey() async throws {
        _ = try insert(.xtream, url: "http://ac16-xtream.test", sortOrder: 0, credentialKey: nil)
        _ = try insert(.m3u, url: twoChannelPlaylist(host: "ac16-m3u.test"), sortOrder: 1)

        let model = try await load(credentials: store)

        #expect(model.channels.count == 2)
        #expect(StubURLProtocol.requests(host: "ac16-xtream.test").isEmpty)
    }

    @Test("0004/AC-11 one failing source does not block the rest")
    func failingSourceDoesNotBlock() async throws {
        _ = try insert(.m3u, url: "http://ac11-down.test/list.m3u", sortOrder: 0)
        _ = try insert(.m3u, url: twoChannelPlaylist(host: "ac11-up.test"), sortOrder: 1)

        let model = try await load(credentials: store)

        #expect(model.channels.map(\.name) == ["ac11-up.test one", "ac11-up.test two"])
    }

    @Test("0004/AC-15 the last load failure is recorded")
    func lastFailureRecorded() async throws {
        let down = "http://ac15-down.test/list.m3u"
        let xtream = "ac15-xtream.test"
        StubURLProtocol.register(host: xtream, action: "get_live_categories", status: 500, body: "")
        StubURLProtocol.register(host: xtream, action: "get_live_streams", status: 500, body: "")
        let key = UUID().uuidString
        try held.save(.init(username: "u", password: "p"), for: key)
        defer { try? held.delete(for: key) }

        _ = try insert(.m3u, url: down, sortOrder: 0)
        _ = try insert(.m3u, url: twoChannelPlaylist(host: "ac15-up.test"), sortOrder: 1)
        let single = try await load(credentials: held)
        let transport = try await failureDescription(down)
        #expect(single.error == transport)

        _ = try insert(.xtream, url: "http://\(xtream)", sortOrder: 2, credentialKey: key)
        _ = try insert(.m3u, url: twoChannelPlaylist(host: "ac15-last.test"), sortOrder: 3)
        let double = try await load(credentials: held)
        let badStatus = XtreamClient.XtreamError.badStatus(500).localizedDescription
        #expect(double.error == badStatus)
        #expect(badStatus != transport)
        #expect(double.channels.count == 4)
    }

    @Test("0004/AC-17 unreadable credential fails like any other source")
    func unreadableCredential() async throws {
        _ = try insert(.xtream, url: "http://ac17-xtream.test", sortOrder: 0, credentialKey: UUID().uuidString)
        _ = try insert(.m3u, url: twoChannelPlaylist(host: "ac17-m3u.test"), sortOrder: 1)

        let readFails = try await load(credentials: FailingCredentialStore())
        #expect(readFails.channels.count == 2)
        #expect(readFails.error == FailingCredentialStore.Failure.keychain.localizedDescription)

        let garbled = try #require(try records().first?.credentialKey)
        let add: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: store.service,
            kSecAttrAccount as String: garbled,
            kSecAttrSynchronizable as String: true,
            kSecValueData as String: Data("not json".utf8),
        ]
        #expect(SecItemAdd(add as CFDictionary, nil) == errSecSuccess)
        defer { try? store.delete(for: garbled) }

        let undecodable = try await load(credentials: store)
        #expect(undecodable.channels.count == 2)
        var decodeFailure: String?
        do {
            _ = try JSONDecoder().decode(CredentialStore.Credential.self, from: Data("not json".utf8))
        } catch {
            decodeFailure = error.localizedDescription
        }
        #expect(undecodable.error == decodeFailure)
        #expect(StubURLProtocol.requests(host: "ac17-xtream.test").isEmpty)
    }

    @Test("0004/AC-18 Stalker contributes no channels")
    func stalkerInert() async throws {
        let key = UUID().uuidString
        try held.save(.init(username: "00:1A:79:00:00:01", password: "p"), for: key)
        defer { try? held.delete(for: key) }
        _ = try insert(.stalker, url: "http://ac18-portal.test/c/", sortOrder: 0, credentialKey: key)
        _ = try insert(.m3u, url: twoChannelPlaylist(host: "ac18-m3u.test"), sortOrder: 1)

        let model = try await load(credentials: held)

        #expect(model.channels.count == 2)
        #expect(StubURLProtocol.requests(host: "ac18-portal.test").isEmpty)
    }

    #if os(iOS)
        @Test("0004/AC-8 no sources, no request")
        func emptyStateMakesNoRequest() async throws {
            let tag = "ac8-\(UUID().uuidString)"
            let loader = SourceLoader(session: StubURLProtocol.session(tag: tag), credentials: store)
            let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
            let window = UIWindow(windowScene: scene)
            window.rootViewController = UIHostingController(
                rootView: ChannelsView().modelContainer(container).environment(\.sourceLoader, loader))
            window.makeKeyAndVisible()
            defer { window.isHidden = true }

            try await Task.sleep(for: .seconds(1))
            #expect(StubURLProtocol.requestCount(tag: tag) == 0)

            // The same harness does see a request once a source exists, so the zero above is not vacuous.
            _ = try insert(.m3u, url: "http://ac8.test/list.m3u", sortOrder: 0)
            try context.save()
            for _ in 0..<50 where StubURLProtocol.requestCount(tag: tag) == 0 {
                try await Task.sleep(for: .milliseconds(100))
            }
            #expect(StubURLProtocol.requestCount(tag: tag) > 0)
        }
    #endif
}

/// 0004 edge cases fixed after the first slice. An extension so the suite
/// stays under SwiftLint's type body length.
extension SourceManagementTests {
    // MARK: Edge cases fixed after the first 0004 slice (no criterion of their own)

    @Test("0004 edge case: a repeated Xtream category id loads instead of crashing")
    func repeatedCategoryID() async throws {
        let host = "dup-category.test"
        StubURLProtocol.register(
            host: host, action: "get_live_categories",
            body: #"[{"category_id":"1","category_name":"News"},{"category_id":"1","category_name":"Sport"}]"#)
        StubURLProtocol.register(
            host: host, action: "get_live_streams",
            body: #"[{"stream_id":7,"name":"One","category_id":"1"}]"#)
        let key = UUID().uuidString
        try held.save(.init(username: "u", password: "p"), for: key)
        defer { try? held.delete(for: key) }
        _ = try insert(.xtream, url: "http://\(host)", sortOrder: 0, credentialKey: key)

        let model = try await load(credentials: held)

        #expect(model.channels.map(\.name) == ["One"])
        #expect(model.channels.first?.group == "News")
    }

    @Test("0004 edge case: an M3U URL answering 404 fails the source")
    func m3uBadStatus() async throws {
        let host = "m3u-404.test"
        StubURLProtocol.register(host: host, status: 404, body: "<html>Not found</html>")
        _ = try insert(.m3u, url: "http://\(host)/list.m3u", sortOrder: 0)
        _ = try insert(.m3u, url: twoChannelPlaylist(host: "m3u-404-up.test"), sortOrder: 1)

        let model = try await load(credentials: store)

        #expect(model.error == SourceLoader.LoadError.badStatus(404).localizedDescription)
        #expect(model.channels.map(\.name) == ["m3u-404-up.test one", "m3u-404-up.test two"])
    }

    @Test("0004 edge case: loading with no sources clears the channels and the error")
    func reloadWithNoSourcesClears() async throws {
        _ = try insert(.m3u, url: twoChannelPlaylist(host: "clear.test"), sortOrder: 0)
        let model = try await load(credentials: store)
        #expect(model.channels.count == 2)

        await model.load([], using: SourceLoader(session: StubURLProtocol.session(), credentials: store))

        #expect(model.channels.isEmpty)
        #expect(model.error == nil)
    }

    @Test("0004 edge case: unchanged sources are not downloaded again")
    func unchangedSourcesSkipped() async throws {
        let host = "unchanged.test"
        _ = try insert(.m3u, url: twoChannelPlaylist(host: host), sortOrder: 0)
        let loader = SourceLoader(session: StubURLProtocol.session(), credentials: store)
        let model = ChannelListModel()

        await model.load(try descriptors(), using: loader)
        await model.load(try descriptors(), using: loader)

        #expect(StubURLProtocol.requests(host: host).count == 1)
        #expect(model.channels.count == 2)
    }

    @Test("0004 edge case: a changed source reloads the list")
    func changedSourceReloads() async throws {
        let record = try insert(.m3u, url: twoChannelPlaylist(host: "before.test"), sortOrder: 0)
        let loader = SourceLoader(session: StubURLProtocol.session(), credentials: store)
        let model = ChannelListModel()
        await model.load(try descriptors(), using: loader)

        record.url = URL(string: twoChannelPlaylist(host: "after.test"))
        await model.load(try descriptors(), using: loader)

        #expect(model.channels.map(\.name) == ["after.test one", "after.test two"])
    }
}

/// A credential store that keeps items in memory.
final class HeldCredentialStore: CredentialStoring {
    private let items = Mutex<[String: CredentialStore.Credential]>([:])

    func save(_ credential: CredentialStore.Credential, for key: String) throws { items.withLock { $0[key] = credential } }
    func load(for key: String) throws -> CredentialStore.Credential? { items.withLock { $0[key] } }
    func delete(for key: String) throws { _ = items.withLock { $0.removeValue(forKey: key) } }
}

/// A credential store whose every call fails.
struct FailingCredentialStore: CredentialStoring {
    enum Failure: Error { case keychain }

    func save(_ credential: CredentialStore.Credential, for key: String) throws { throw Failure.keychain }
    func load(for key: String) throws -> CredentialStore.Credential? { throw Failure.keychain }
    func delete(for key: String) throws { throw Failure.keychain }
}
