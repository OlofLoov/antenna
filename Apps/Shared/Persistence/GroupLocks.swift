import AntennaCore
import Foundation
import Observation

/// Whether the group locks are open on this device, the wait after wrong
/// passcodes and the passcode this device last knew (group-management
/// capability). Open locks live in memory only, so every launch starts
/// with them closed. The wait and the known passcode live in this
/// device's `UserDefaults`, never synced; neither holds the digits.
@MainActor @Observable
final class GroupLocks {
    /// What one passcode entry did.
    enum Entry: Equatable {
        case right
        case wrong
        /// Input is refused for this many more seconds.
        case waiting(TimeInterval)
        /// No passcode has reached this device yet.
        case noPasscode
    }

    static let lockoutKey = "groups.lockout"
    static let knownKey = "groups.passcodeKnown"
    /// How long the app may sit in the background, or an Apple TV without
    /// remote input, before the locks close.
    static let idleLimit: TimeInterval = 15 * 60

    private(set) var isOpen = false
    private(set) var lockout: PasscodeLockout
    @ObservationIgnored nonisolated(unsafe) private let defaults: UserDefaults
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var backgroundedAt: Date?
    @ObservationIgnored private var lastInput: Date

    init(defaults: UserDefaults = .standard, now: @escaping () -> Date = { .now }) {
        self.defaults = defaults
        self.now = now
        self.lockout = PasscodeLockout(data: defaults.data(forKey: Self.lockoutKey))
        self.lastInput = now()
    }

    /// Seconds left before the prompt takes input again.
    var waitRemaining: TimeInterval { lockout.remaining(at: now()) }

    /// Checks `digits` against the passcode in `records`. The right one
    /// opens the locks and clears the wait; a wrong one counts towards it
    /// (group-management/guessing-the-passcode-is-slow).
    func enter(_ digits: String, records: [PasscodeRecord]) -> Entry {
        guard let record = PasscodeStore.current(records) else { return .noPasscode }
        let wait = lockout.remaining(at: now())
        guard wait == 0 else { return .waiting(wait) }
        guard PasscodeStore.matches(digits, records) else {
            lockout.wrong(at: now())
            store()
            let after = lockout.remaining(at: now())
            return after > 0 ? .waiting(after) : .wrong
        }
        lockout.right()
        store()
        remember(record)
        open()
        return .right
    }

    /// Opens the locks on this device, as after setting the first passcode
    /// or resetting it (group-management/reset-a-forgotten-passcode).
    func open() {
        isOpen = true
        lastInput = now()
    }

    /// Lock now (group-management/locks-close-again-on-their-own).
    func close() {
        isOpen = false
    }

    /// This device set or entered `record`'s passcode.
    func remember(_ record: PasscodeRecord) {
        defaults.set(record.token, forKey: Self.knownKey)
    }

    /// True when the passcode in effect is not the one this device last
    /// set or entered, as when another device changed it or won a race to
    /// set the first one (group-management/lock-a-group-with-a-passcode).
    func changedElsewhere(_ records: [PasscodeRecord]) -> Bool {
        guard let current = PasscodeStore.current(records), let known = defaults.string(forKey: Self.knownKey) else { return false }
        return current.token != known
    }

    // MARK: Closing on their own

    func wentToBackground() {
        backgroundedAt = now()
    }

    /// Back in the foreground: the locks close when the app was away for
    /// `idleLimit` or longer.
    func becameActive() {
        if let backgroundedAt, now().timeIntervalSince(backgroundedAt) >= Self.idleLimit { close() }
        backgroundedAt = nil
        lastInput = now()
    }

    /// The remote moved focus or pressed a button on Apple TV.
    func touched() {
        lastInput = now()
    }

    /// Closes the locks when no input arrived for `idleLimit`.
    func checkIdle() {
        if isOpen, now().timeIntervalSince(lastInput) >= Self.idleLimit { close() }
    }

    private func store() {
        defaults.set(lockout.data, forKey: Self.lockoutKey)
    }
}
