import AntennaCore
import Foundation
import Observation

/// Sends sealed logins to the Apple TV that showed a code and follows the
/// pickup (apple-tv-login-from-iphone/the-iphone-says-whether-the-tv-picked-it-up).
/// The logins are sealed to the code's key and saved once under its
/// code; the store is then asked every 2 seconds whether the TV took them.
/// After a minute without a pickup the state says so and keeps looking;
/// at ten minutes the delivery is deleted. The logins are held in memory
/// only and never logged.
@MainActor @Observable
final class LoginDelivery {
    enum State: Equatable {
        /// Sealing and saving.
        case sending
        /// Saved; the TV has not taken it yet.
        case waiting
        /// The TV took it.
        case pickedUp
        /// A minute passed without a pickup; still looking.
        case notPickedUp
        /// Nothing was sent: no connection to iCloud.
        case offline
        /// Nothing was sent: this device is not signed in to iCloud.
        case notSignedIn
        /// Nothing was sent: the user's iCloud storage is full.
        case storageFull
        /// Nothing was sent: another device already used the code.
        case alreadyUsed
        /// Nothing was sent for another reason.
        case failed
    }

    struct Dependencies {
        var identity: any ICloudIdentity
        var drops: any LoginDropping
        var sleep: @MainActor (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
        var now: @MainActor () -> Date = { Date.now }
        var pollInterval = Duration.seconds(2)
        var pickupWait: TimeInterval = 60
    }

    private(set) var state = State.sending
    @ObservationIgnored private let payload: LoginPayload
    @ObservationIgnored private let link: SetupLink
    @ObservationIgnored private let dependencies: Dependencies

    init(_ payload: LoginPayload, to link: SetupLink, dependencies: Dependencies) {
        self.payload = payload
        self.link = link
        self.dependencies = dependencies
    }

    /// True once nothing was sent and Try again could help.
    var canRetry: Bool { state == .offline || state == .failed }

    /// Sends, then follows the pickup until the task is cancelled, the TV
    /// takes it or ten minutes pass.
    func run() async {
        state = .sending
        guard await dependencies.identity.isSignedIn() else {
            state = .notSignedIn
            return
        }
        guard let key = link.key, let sealed = try? LoginSeal.seal(payload, to: key, token: link.token) else {
            state = .failed
            return
        }
        do {
            try await dependencies.drops.save(sealed, token: link.token)
        } catch {
            state = Self.state(for: error)
            return
        }
        let sentAt = dependencies.now()
        state = .waiting
        while !Task.isCancelled {
            do {
                try await dependencies.sleep(dependencies.pollInterval)
            } catch {
                return
            }
            let elapsed = dependencies.now().timeIntervalSince(sentAt)
            if elapsed >= LoginDrops.lifetime {
                try? await dependencies.drops.delete(token: link.token)
                return
            }
            let drop: LoginDrop?
            do {
                drop = try await dependencies.drops.fetch(token: link.token)
            } catch {
                // A failed look says nothing either way.
                if elapsed >= dependencies.pickupWait { state = .notPickedUp }
                continue
            }
            // A record that is gone was taken and swept.
            guard case .waiting = drop else {
                state = .pickedUp
                return
            }
            if elapsed >= dependencies.pickupWait { state = .notPickedUp }
        }
    }

    private static func state(for error: LoginDropError) -> State {
        switch error {
        case .alreadyUsed: .alreadyUsed
        case .offline, .busy: .offline
        case .notSignedIn: .notSignedIn
        case .quotaExceeded: .storageFull
        case .failed: .failed
        }
    }
}
