import Foundation
import Security
import Synchronization
import Testing

@testable import Antenna

/// Where logins land and how ones from an earlier build move, against a
/// Keychain in memory that keeps access groups apart.
@Suite struct CredentialStoreTests {
    static let shared = "TEAM.se.codecrave.antenna.shared"
    static let iPhoneGroup = "TEAM.se.codecrave.antenna"

    let keychain = GroupedKeychain(defaultGroup: iPhoneGroup, entitled: [shared, iPhoneGroup])
    let login = CredentialStore.Credential(username: "anna", password: "s3cret")

    private var store: CredentialStore {
        CredentialStore(service: "test", sharedGroup: Self.shared, keychain: keychain)
    }

    @Test("source-management/logins-are-shared-between-the-apps: a new login is written to the shared group")
    func savesToSharedGroup() throws {
        try store.save(login, for: "a")
        #expect(keychain.groups(of: "a") == [Self.shared])
        #expect(try store.load(for: "a") == login)
    }

    @Test("source-management/logins-are-shared-between-the-apps: the Apple TV app reads a login the iPhone app saved")
    func otherAppReads() throws {
        try store.save(login, for: "a")
        let tv = GroupedKeychain(defaultGroup: "TEAM.se.codecrave.antenna.tv", entitled: [Self.shared, "TEAM.se.codecrave.antenna.tv"])
        tv.items = keychain.items
        #expect(try CredentialStore(service: "test", sharedGroup: Self.shared, keychain: tv).load(for: "a") == login)
    }

    @Test("source-management/logins-saved-by-an-earlier-version-move-to-the-shared-place: first read moves it")
    func firstReadMoves() throws {
        try keychain.put(login, account: "a", group: Self.iPhoneGroup)
        #expect(try store.load(for: "a") == login)
        #expect(keychain.groups(of: "a") == [Self.shared])
    }

    @Test("source-management/logins-saved-by-an-earlier-version-move-to-the-shared-place: a failed move keeps the old copy")
    func failedMoveKeepsOld() throws {
        try keychain.put(login, account: "a", group: Self.iPhoneGroup)
        keychain.refusing = [Self.shared]
        #expect(try store.load(for: "a") == login)
        #expect(keychain.groups(of: "a") == [Self.iPhoneGroup])

        keychain.refusing = []
        #expect(try store.load(for: "a") == login)
        #expect(keychain.groups(of: "a") == [Self.shared])
    }

    @Test("source-management/logins-saved-by-an-earlier-version-move-to-the-shared-place: the shared copy wins over an old one")
    func sharedCopyWins() throws {
        let old = CredentialStore.Credential(username: "anna", password: "old")
        try keychain.put(old, account: "a", group: Self.iPhoneGroup)
        try keychain.put(login, account: "a", group: Self.shared)
        #expect(try store.load(for: "a") == login)
        #expect(keychain.groups(of: "a") == [Self.shared])
    }

    @Test("source-management/logins-saved-by-an-earlier-version-move-to-the-shared-place: saving replaces an old copy")
    func saveRemovesOld() throws {
        try keychain.put(CredentialStore.Credential(username: "anna", password: "old"), account: "a", group: Self.iPhoneGroup)
        try store.save(login, for: "a")
        #expect(keychain.groups(of: "a") == [Self.shared])
    }

    @Test("source-management/logins-saved-by-an-earlier-version-move-to-the-shared-place: deleting removes every copy")
    func deleteRemovesAll() throws {
        try keychain.put(login, account: "a", group: Self.iPhoneGroup)
        try keychain.put(login, account: "a", group: Self.shared)
        try store.delete(for: "a")
        #expect(keychain.groups(of: "a").isEmpty)
        #expect(try store.load(for: "a") == nil)
    }

    @Test("source-management/logins-are-shared-between-the-apps: without the shared group's entitlement the app's own group is used")
    func missingEntitlementFallsBack() throws {
        let unentitled = GroupedKeychain(defaultGroup: Self.iPhoneGroup, entitled: [Self.iPhoneGroup])
        let store = CredentialStore(service: "test", sharedGroup: Self.shared, keychain: unentitled)
        try store.save(login, for: "a")
        #expect(unentitled.groups(of: "a") == [Self.iPhoneGroup])
        #expect(try store.load(for: "a") == login)
        #expect(unentitled.groups(of: "a") == [Self.iPhoneGroup])
    }

    @Test("source-management/logins-are-shared-between-the-apps: the device Keychain round trip with the app's group")
    func systemKeychainRoundTrip() throws {
        let store = CredentialStore(service: "se.codecrave.antenna.tests.\(UUID().uuidString)")
        defer { try? store.delete(for: "a") }
        try store.save(login, for: "a")
        #expect(try store.load(for: "a") == login)
        try store.delete(for: "a")
        #expect(try store.load(for: "a") == nil)
    }
}

/// A Keychain in memory with access groups. Items outside `entitled` are
/// invisible, writes to them fail with a missing entitlement, and writes
/// to a group in `refusing` fail with an I/O error.
final class GroupedKeychain: KeychainItems {
    struct Key: Hashable {
        var account: String
        var group: String
    }

    private let state = Mutex<[Key: Data]>([:])
    private let refused = Mutex<Set<String>>([])
    let defaultGroup: String
    let entitled: Set<String>

    init(defaultGroup: String, entitled: Set<String>) {
        self.defaultGroup = defaultGroup
        self.entitled = entitled
    }

    var items: [Key: Data] {
        get { state.withLock { $0 } }
        set { state.withLock { $0 = newValue } }
    }

    var refusing: Set<String> {
        get { refused.withLock { $0 } }
        set { refused.withLock { $0 = newValue } }
    }

    func groups(of account: String) -> [String] {
        items.keys.filter { $0.account == account && entitled.contains($0.group) }.map(\.group).sorted()
    }

    func put(_ credential: CredentialStore.Credential, account: String, group: String) throws {
        let data = try JSONEncoder().encode(credential)
        state.withLock { $0[Key(account: account, group: group)] = data }
    }

    func groups(service: String, account: String) throws -> [String?] {
        groups(of: account)
    }

    func data(service: String, account: String, group: String?) throws -> Data? {
        guard let group = group ?? groups(of: account).first, entitled.contains(group) else { return nil }
        return items[Key(account: account, group: group)]
    }

    func write(_ data: Data, service: String, account: String, group: String?) throws {
        guard let group else {
            let existing = groups(of: account)
            for group in existing.isEmpty ? [defaultGroup] : existing { try write(data, service: service, account: account, group: group) }
            return
        }
        guard entitled.contains(group) else { throw CredentialStore.StoreError.unexpectedStatus(errSecMissingEntitlement) }
        guard !refusing.contains(group) else { throw CredentialStore.StoreError.unexpectedStatus(errSecIO) }
        state.withLock { $0[Key(account: account, group: group)] = data }
    }

    func delete(service: String, account: String, group: String?) throws {
        let targets = group.map { [$0] } ?? groups(of: account)
        state.withLock { items in
            for group in targets where entitled.contains(group) { items[Key(account: account, group: group)] = nil }
        }
    }
}
