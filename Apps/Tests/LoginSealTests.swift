import AntennaCore
import CloudKit
import Foundation
import Testing

#if os(tvOS)
    @testable import AntennaTV
#else
    @testable import Antenna
#endif

/// Sealing a login to the TV's key and opening it there, with CryptoKit's
/// HPKE. Runs in both the iOS and tvOS unit tests.
@Suite struct LoginSealTests {
    let token = PairingToken("AAAAAAAAAAAAAAAAAAAAAA") ?? PairingToken()
    let source = UUID()

    var payload: LoginPayload {
        LoginPayload(logins: [.init(source: source, username: "anna", password: "secret")])
    }

    @Test("apple-tv-login-from-iphone/only-the-apple-tv-that-showed-the-code-can-read-the-login: a round trip opens")
    func roundTrip() throws {
        let key = LoginReceiverKey()
        let sealed = try LoginSeal.seal(payload, to: key.publicKey, token: token)
        #expect(sealed.enc.count == 32)
        #expect(!String(decoding: sealed.box, as: UTF8.self).contains("secret"))
        #expect(try LoginSeal.open(sealed, with: key, token: token) == payload)
    }

    @Test("apple-tv-login-from-iphone/only-the-apple-tv-that-showed-the-code-can-read-the-login: another key cannot open it")
    func wrongKey() throws {
        let sealed = try LoginSeal.seal(payload, to: LoginReceiverKey().publicKey, token: token)
        #expect(throws: LoginSeal.OpenError.unreadable) { try LoginSeal.open(sealed, with: LoginReceiverKey(), token: token) }
    }

    @Test("apple-tv-login-from-iphone/a-code-works-once-and-for-ten-minutes: a box for another code does not open")
    func wrongToken() throws {
        let key = LoginReceiverKey()
        let sealed = try LoginSeal.seal(payload, to: key.publicKey, token: token)
        #expect(throws: LoginSeal.OpenError.unreadable) { try LoginSeal.open(sealed, with: key, token: PairingToken()) }
        var damaged = sealed
        damaged.box[damaged.box.startIndex] ^= 1
        #expect(throws: LoginSeal.OpenError.unreadable) { try LoginSeal.open(damaged, with: key, token: token) }
    }

    @Test("apple-tv-login-from-iphone/the-apple-tv-checks-a-login-before-keeping-it: a newer payload or record is unknown")
    func unknownVersion() throws {
        let key = LoginReceiverKey()
        let newer = try LoginSeal.seal(Data(#"{"v":2,"logins":[]}"#.utf8), to: key.publicKey, token: token)
        #expect(throws: LoginSeal.OpenError.unknownVersion) { try LoginSeal.open(newer, with: key, token: token) }
        var record = try LoginSeal.seal(payload, to: key.publicKey, token: token)
        record.version = 2
        #expect(throws: LoginSeal.OpenError.unknownVersion) { try LoginSeal.open(record, with: key, token: token) }
        let junk = try LoginSeal.seal(Data("junk".utf8), to: key.publicKey, token: token)
        #expect(throws: LoginSeal.OpenError.unreadable) { try LoginSeal.open(junk, with: key, token: token) }
    }

    @Test("apple-tv-login-from-iphone/nothing-about-a-login-is-logged-or-kept: keys and boxes print no content")
    func redacted() throws {
        let key = try LoginReceiverKey(rawRepresentation: Data(repeating: 7, count: 32))
        let again = try LoginReceiverKey(rawRepresentation: Data(repeating: 7, count: 32))
        #expect(key.publicKey == again.publicKey)
        #expect("\(key)" == "LoginReceiverKey" && String(reflecting: key) == "LoginReceiverKey")
        let sealed = try LoginSeal.seal(payload, to: key.publicKey, token: token)
        #expect("\(sealed)".hasPrefix("SealedLogin(v1, "))
        #expect(!String(reflecting: sealed).contains(sealed.box.base64EncodedString()))
    }
}

/// The drop store's rules, against the in-memory store with a scripted clock.
@Suite struct LoginDropsTests {
    final class Clock: @unchecked Sendable {
        var now = Date(timeIntervalSince1970: 1_800_000_000)
    }

    let clock = Clock()
    let token = PairingToken()
    let sealed = SealedLogin(enc: Data(repeating: 1, count: 32), box: Data(repeating: 2, count: 48))

    var drops: InMemoryLoginDrops { InMemoryLoginDrops(now: { [clock] in clock.now }) }

    @Test("apple-tv-login-from-iphone/a-code-works-once-and-for-ten-minutes: a second save for the same code is refused")
    func createOnly() async throws {
        let drops = drops
        try await drops.save(sealed, token: token)
        await #expect(throws: LoginDropError.alreadyUsed) { try await drops.save(sealed, token: token) }
        #expect(try await drops.fetch(token: token) == .waiting(sealed))
        #expect(try await drops.fetch(token: PairingToken()) == nil)
    }

    @Test("apple-tv-login-from-iphone/only-the-apple-tv-that-showed-the-code-can-read-the-login: pickup deletes the box")
    func deleteOnPickup() async throws {
        let drops = drops
        try await drops.save(sealed, token: token)
        try await drops.pickUp(token: token)
        #expect(try await drops.fetch(token: token) == .pickedUp)
        // A second sender after pickup still hears the code was used.
        await #expect(throws: LoginDropError.alreadyUsed) { try await drops.save(sealed, token: token) }
        try await drops.delete(token: token)
        try await drops.delete(token: token)
        #expect(try await drops.fetch(token: token) == nil)
        #expect(await drops.isEmpty)
    }

    @Test("apple-tv-login-from-iphone/only-the-apple-tv-that-showed-the-code-can-read-the-login: the ten-minute sweep")
    func sweep() async throws {
        let drops = drops
        try await drops.save(sealed, token: token)
        clock.now += 300
        let later = PairingToken()
        try await drops.save(sealed, token: later)
        clock.now += 301
        await LoginDrops.sweep(drops, now: clock.now)
        #expect(try await drops.fetch(token: token) == nil)
        #expect(try await drops.fetch(token: later) == .waiting(sealed))
        clock.now += 300
        await LoginDrops.sweep(drops, now: clock.now)
        #expect(await drops.isEmpty)
    }

    @Test("apple-tv-login-from-iphone/the-iphone-says-whether-the-tv-picked-it-up: failures come back as they are")
    func failures() async {
        let drops = drops
        await drops.fail(with: .offline)
        await #expect(throws: LoginDropError.offline) { try await drops.save(sealed, token: token) }
        await #expect(throws: LoginDropError.offline) { try await drops.fetch(token: token) }
        await drops.fail(with: nil)
        await #expect(throws: Never.self) { try await drops.save(sealed, token: token) }
    }

    @Test("apple-tv-login-from-iphone/the-iphone-says-whether-the-tv-picked-it-up: CloudKit errors map to what the sheet says")
    func cloudKitErrors() {
        #expect(CloudKitLoginDrops.map(CKError(.serverRecordChanged), for: nil) == .alreadyUsed)
        #expect(CloudKitLoginDrops.map(CKError(.networkUnavailable), for: nil) == .offline)
        #expect(CloudKitLoginDrops.map(CKError(.notAuthenticated), for: nil) == .notSignedIn)
        #expect(CloudKitLoginDrops.map(CKError(.quotaExceeded), for: nil) == .quotaExceeded)
        #expect(CloudKitLoginDrops.map(CKError(.requestRateLimited), for: nil) == .busy(retryAfter: nil))
        #expect(CloudKitLoginDrops.map(URLError(.badURL), for: nil) == .failed)
        let id = CKRecord.ID(recordName: "drop-x", zoneID: CloudKitLoginDrops.zoneID)
        let partial = CKError(.partialFailure, userInfo: [CKPartialErrorsByItemIDKey: [id: CKError(.serverRecordChanged)]])
        #expect(CloudKitLoginDrops.map(partial, for: id) == .alreadyUsed)
    }
}
