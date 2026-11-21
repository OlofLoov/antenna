import AntennaCore
import Foundation
import Security
import Synchronization
import Testing

@testable import Antenna

/// Whether a source has its login, asked of the Keychain once per login
/// (source-management/login-checks-are-remembered).
@Suite struct LoginPresenceTests {
    static let group = "TEAM.se.codecrave.antenna.shared"

    let keychain = CountingKeychain(GroupedKeychain(defaultGroup: group, entitled: [group]))
    let presence = LoginPresence()
    let login = CredentialStore.Credential(username: "anna", password: "s3cret")

    private var store: CredentialStore {
        CredentialStore(service: "test", sharedGroup: Self.group, keychain: keychain, presence: presence)
    }

    private func source(_ kind: SourceKind = .xtream, key: String = "a") throws -> SourceDescriptor {
        SourceDescriptor(
            name: "Home", kind: kind, url: try #require(URL(string: "http://panel.test")), credentialKey: key)
    }

    // source-management/login-checks-are-remembered
    @Test func aFoundLoginIsAskedForOnce() throws {
        try store.save(login, for: "a")
        let loader = SourceLoader(credentials: store)
        let source = try source()
        keychain.reads.withLock { $0 = 0 }
        #expect(loader.hasLogin(source))
        let first = keychain.reads.withLock { $0 }
        #expect(first == 3)
        for _ in 0..<50 { #expect(loader.hasLogin(source)) }
        #expect(keychain.reads.withLock { $0 } == first)
    }

    // source-management/login-checks-are-remembered
    @Test func aMissingLoginIsAskedForEachTimeAndSeenWhenItArrives() throws {
        let loader = SourceLoader(credentials: store)
        let source = try source()
        #expect(!loader.hasLogin(source))
        let first = keychain.reads.withLock { $0 }
        #expect(!loader.hasLogin(source))
        #expect(keychain.reads.withLock { $0 } > first)
        try keychain.inner.put(login, account: "a", group: Self.group)
        #expect(loader.hasLogin(source))
    }

    // source-management/login-checks-are-remembered
    @Test func deletingOrComingBackToTheFrontAsksAgain() throws {
        try store.save(login, for: "a")
        let loader = SourceLoader(credentials: store)
        let source = try source()
        #expect(loader.hasLogin(source))
        try store.delete(for: "a")
        #expect(!loader.hasLogin(source))

        try store.save(login, for: "a")
        #expect(loader.hasLogin(source))
        keychain.inner.items = [:]
        #expect(loader.hasLogin(source))
        presence.forgetAll()
        #expect(!loader.hasLogin(source))
    }

    // source-management/login-checks-are-remembered
    @Test func anUnreadableLoginCountsAsHere() throws {
        keychain.failing.withLock { $0 = true }
        let loader = SourceLoader(credentials: store)
        #expect(loader.hasLogin(try source()))
    }

    // source-management/login-checks-are-remembered
    @Test func aStalkerLoginWithoutAMACIsNotRemembered() throws {
        try store.save(CredentialStore.Credential(username: "not a mac", password: ""), for: "s")
        let loader = SourceLoader(credentials: store)
        let portal = try source(.stalker, key: "s")
        #expect(!loader.hasLogin(portal))
        try store.save(CredentialStore.Credential(username: "00:1A:79:12:34:56", password: ""), for: "s")
        #expect(loader.hasLogin(portal))
    }
}

/// A Keychain that counts reads and can fail them, around `GroupedKeychain`.
final class CountingKeychain: KeychainItems {
    let inner: GroupedKeychain
    let reads = Mutex(0)
    let failing = Mutex(false)

    init(_ inner: GroupedKeychain) {
        self.inner = inner
    }

    func groups(service: String, account: String) throws -> [String?] {
        reads.withLock { $0 += 1 }
        if failing.withLock({ $0 }) { throw CredentialStore.StoreError.unexpectedStatus(errSecInteractionNotAllowed) }
        return try inner.groups(service: service, account: account)
    }

    func data(service: String, account: String, group: String?) throws -> Data? {
        reads.withLock { $0 += 1 }
        if failing.withLock({ $0 }) { throw CredentialStore.StoreError.unexpectedStatus(errSecInteractionNotAllowed) }
        return try inner.data(service: service, account: account, group: group)
    }

    func write(_ data: Data, service: String, account: String, group: String?) throws {
        try inner.write(data, service: service, account: account, group: group)
    }

    func delete(service: String, account: String, group: String?) throws {
        try inner.delete(service: service, account: account, group: group)
    }
}
