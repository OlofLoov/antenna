import AntennaCore
import Foundation

/// Where sealed logins wait for an Apple TV
/// (apple-tv-login-from-iphone/only-the-apple-tv-that-showed-the-code-can-read-the-login):
/// one delivery per code. Picking it up deletes the sealed box and leaves
/// an empty marker, so a second sender learns the code was used; a sweep
/// deletes markers and boxes older than ten minutes. `CloudKitLoginDrops`
/// is the app's store; `InMemoryLoginDrops` stands in for it in tests,
/// previews and UI tests.
protocol LoginDropping: Sendable {
    /// Saves a new delivery. A second save for the same code, even after
    /// pickup, throws `.alreadyUsed`.
    func save(_ sealed: SealedLogin, token: PairingToken) async throws(LoginDropError)
    /// The delivery for a code, or nil when none is there.
    func fetch(token: PairingToken) async throws(LoginDropError) -> LoginDrop?
    /// Deletes the sealed box for a code and leaves the used marker.
    func pickUp(token: PairingToken) async throws(LoginDropError)
    /// Deletes the delivery for a code; deleting one that is gone is not an error.
    func delete(token: PairingToken) async throws(LoginDropError)
    /// Deletes every delivery saved before `cutoff` and returns how many.
    @discardableResult func sweep(olderThan cutoff: Date) async throws(LoginDropError) -> Int
}

/// What the store holds for one code.
enum LoginDrop: Equatable, Sendable {
    /// Sealed and waiting for the TV.
    case waiting(SealedLogin)
    /// The TV took it; nothing secret is left.
    case pickedUp
}

/// Why the drop store did not do what was asked.
enum LoginDropError: Error, Equatable, Sendable {
    /// A delivery for this code exists already.
    case alreadyUsed
    /// No connection to iCloud.
    case offline
    /// This device is not signed in to iCloud.
    case notSignedIn
    /// The user's iCloud storage is full.
    case quotaExceeded
    /// iCloud asked to wait, for this many seconds when it said.
    case busy(retryAfter: TimeInterval?)
    /// Anything else.
    case failed
}

enum LoginDrops {
    /// How long a delivery may wait, and how long a code works.
    static let lifetime: TimeInterval = 600

    /// The record name for a code.
    static func recordName(_ token: PairingToken) -> String { "drop-\(token.text)" }

    /// Deletes deliveries older than ten minutes. Each device runs it on
    /// launch and on returning to the foreground; a failure waits for the next time.
    static func sweep(_ drops: any LoginDropping, now: Date) async {
        _ = try? await drops.sweep(olderThan: now.addingTimeInterval(-lifetime))
    }
}

/// Deliveries kept in memory, with the time each was saved.
actor InMemoryLoginDrops: LoginDropping {
    private var drops: [String: (drop: LoginDrop, savedAt: Date)] = [:]
    private var failure: LoginDropError?
    private let now: @Sendable () -> Date

    /// `failure`, when given, is thrown by every call until `fail(with: nil)`.
    init(now: @escaping @Sendable () -> Date = { Date.now }, failure: LoginDropError? = nil) {
        self.now = now
        self.failure = failure
    }

    /// Picks up every waiting delivery, as a TV would; for UI tests.
    func pickUpWaiting() {
        for (name, kept) in drops where kept.drop != .pickedUp {
            drops[name] = (.pickedUp, kept.savedAt)
        }
    }

    /// Every later call throws `error`, or works again for nil.
    func fail(with error: LoginDropError?) {
        failure = error
    }

    /// How many deliveries and markers are kept.
    var count: Int { drops.count }

    /// True when nothing is kept.
    var isEmpty: Bool { drops.isEmpty }

    func save(_ sealed: SealedLogin, token: PairingToken) throws(LoginDropError) {
        if let failure { throw failure }
        let name = LoginDrops.recordName(token)
        guard drops[name] == nil else { throw .alreadyUsed }
        drops[name] = (.waiting(sealed), now())
    }

    func fetch(token: PairingToken) throws(LoginDropError) -> LoginDrop? {
        if let failure { throw failure }
        return drops[LoginDrops.recordName(token)]?.drop
    }

    func pickUp(token: PairingToken) throws(LoginDropError) {
        if let failure { throw failure }
        let name = LoginDrops.recordName(token)
        guard let kept = drops[name] else { return }
        drops[name] = (.pickedUp, kept.savedAt)
    }

    func delete(token: PairingToken) throws(LoginDropError) {
        if let failure { throw failure }
        drops[LoginDrops.recordName(token)] = nil
    }

    @discardableResult func sweep(olderThan cutoff: Date) throws(LoginDropError) -> Int {
        if let failure { throw failure }
        let old = drops.filter { $0.value.savedAt < cutoff }.map(\.key)
        old.forEach { drops[$0] = nil }
        return old.count
    }
}
