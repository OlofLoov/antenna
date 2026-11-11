import AntennaCore
import Foundation
import Observation

/// The channel the player is showing and the names its messages use.
struct PlayerSubject: Equatable, Sendable {
    var channel: Channel
    /// The source's display name, such as "Acme TV".
    var source: String
    /// The channel's number in the catalogue, nil when it has none.
    var number: Int?

    /// "104 Sport One", or the name alone without a number.
    var line: String {
        [number.map(String.init), channel.name].compactMap(\.self).joined(separator: " ")
    }
}

/// What the player draws over the picture while it waits for data.
enum PlayerWaiting: Equatable, Sendable {
    /// Loading or waiting for data for more than half a second.
    case spinner
    /// The spinner with a line saying the source sends data slowly.
    case slow(caption: String)
    /// The engine's reconnect count, in place of the spinner.
    case reconnecting(caption: String)

    var caption: String? {
        switch self {
        case .spinner: nil
        case .slow(let caption), .reconnecting(let caption): caption
        }
    }
}

/// Player state every platform shares (player-controls-and-playback-errors
/// capability): the spinner and its slow-source line, the reconnect count,
/// the failure and its message, and loading the same channel again on Try
/// again, when the network returns or when a missing login arrives.
///
/// The screen that tunes channels owns one, tells it about each tune with
/// `tuned(_:)` and gives it `reload`, which loads a channel again without
/// counting as a channel change.
@MainActor @Observable
final class PlayerModel {
    struct Dependencies {
        var engine: any PlaybackEngine
        var device: FailureMessage.Device = .current
        var sleep: @MainActor (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
        var now: @MainActor () -> Date = { .now }
        var network: NetworkWatch = .system
        var log: PlayerLog = .system
        var spinnerDelay = Duration.milliseconds(500)
        var slowDelay = Duration.seconds(10)
        var loginCheck = Duration.seconds(5)
    }

    /// The channel on screen, nil before the first tune.
    private(set) var subject: PlayerSubject?
    /// The engine's state, as last reported.
    private(set) var state: PlaybackState = .idle
    /// The spinner, the slow line or the reconnect count; nil while nothing waits.
    private(set) var waiting: PlayerWaiting?
    /// Why the channel stopped, nil unless the error shows.
    private(set) var failure: PlaybackFailure?
    /// When the failed attempt happened.
    private(set) var failedAt: Date?

    /// Loads the channel again. The owner sets it.
    @ObservationIgnored var reload: @MainActor (Channel) -> Void = { _ in }
    /// True once the login of the source with this id is in the Keychain.
    /// The owner sets it.
    @ObservationIgnored var hasLogin: @MainActor (UUID) -> Bool = { _ in true }

    @ObservationIgnored let engine: any PlaybackEngine
    @ObservationIgnored private let dependencies: Dependencies
    @ObservationIgnored private var waitTimer: Task<Void, Never>?
    @ObservationIgnored private var recovery: Task<Void, Never>?

    init(_ dependencies: Dependencies) {
        self.dependencies = dependencies
        engine = dependencies.engine
    }

    var device: FailureMessage.Device { dependencies.device }

    /// The title and explanation for the failure, naming the source.
    var message: FailureMessage? {
        failure.map { FailureMessage($0, source: subject?.source ?? Self.unnamedSource, device: device) }
    }

    static let unnamedSource = "The provider"

    // MARK: Engine

    /// Follows the engine until the calling task ends.
    func run() async {
        for await state in await engine.states() {
            stateChanged(state)
        }
    }

    func stateChanged(_ new: PlaybackState) {
        state = new
        switch new {
        case .loading, .buffering:
            if waitTimer == nil || waiting?.isReconnecting == true { startWaiting() }
        case .reconnecting(let attempt, let total):
            waitTimer?.cancel()
            waiting = .reconnecting(caption: PlayerStatusText.reconnecting(attempt: attempt, of: total))
        case .failed(let reason):
            fail(reason)
        case .playing, .paused, .idle, .ended:
            stopWaiting()
        }
    }

    /// A load threw `failure`. Engines report the same through their
    /// state; this covers a load that throws first.
    func loadFailed(_ failure: PlaybackFailure) {
        guard self.failure != failure else { return }
        fail(failure)
    }

    // MARK: Tuning

    /// A channel was tuned, or the player stopped with nil. Any error,
    /// recovery and wait for the old channel go.
    func tuned(_ new: PlayerSubject?) {
        subject = new
        clearFailure()
        stopWaiting()
        if new != nil { startWaiting() }
    }

    /// Try again: the same channel loads once more without counting as a
    /// channel change, the error goes and the spinner shows at once
    /// (player-controls-and-playback-errors/try-again-or-recover-on-its-own).
    func retry() {
        guard let subject else { return }
        dependencies.log.write("retry")
        clearFailure()
        stopWaiting()
        waiting = .spinner
        startSlowTimer()
        reload(subject.channel)
    }

    // MARK: Waiting

    private func startWaiting() {
        waitTimer?.cancel()
        waiting = nil
        let delay = dependencies.spinnerDelay
        waitTimer = Task { [weak self] in
            guard let self else { return }
            do { try await dependencies.sleep(delay) } catch { return }
            guard !Task.isCancelled else { return }
            waiting = .spinner
            await waitForSlow()
        }
    }

    private func startSlowTimer() {
        waitTimer?.cancel()
        waitTimer = Task { [weak self] in await self?.waitForSlow() }
    }

    private func waitForSlow() async {
        do { try await dependencies.sleep(dependencies.slowDelay) } catch { return }
        guard !Task.isCancelled, waiting == .spinner else { return }
        waiting = .slow(caption: PlayerStatusText.slowSource(subject?.source ?? Self.unnamedSource))
    }

    private func stopWaiting() {
        waitTimer?.cancel()
        waitTimer = nil
        waiting = nil
    }

    // MARK: Failure and recovery

    private func fail(_ reason: PlaybackFailure) {
        stopWaiting()
        guard subject != nil else { return }
        dependencies.log.write("playback failed: \(reason.logName)")
        failure = reason
        failedAt = dependencies.now()
        recovery?.cancel()
        switch reason {
        case .offline: recovery = Task { [weak self] in await self?.reloadWhenOnline() }
        case .loginNotOnDevice: recovery = Task { [weak self] in await self?.reloadWhenLoginArrives() }
        default: recovery = nil
        }
    }

    private func clearFailure() {
        recovery?.cancel()
        recovery = nil
        failure = nil
        failedAt = nil
    }

    /// Loads again once the connection comes back after being gone.
    private func reloadWhenOnline() async {
        var wasOffline = false
        for await online in dependencies.network.updates() {
            guard !Task.isCancelled else { return }
            if !online {
                wasOffline = true
            } else if wasOffline {
                dependencies.log.write("connection returned")
                return retry()
            }
        }
    }

    /// Looks for the login every few seconds and loads again once it is there.
    private func reloadWhenLoginArrives() async {
        while !Task.isCancelled {
            if let source = subject?.channel.sourceID, hasLogin(source) {
                dependencies.log.write("login arrived")
                return retry()
            }
            do { try await dependencies.sleep(dependencies.loginCheck) } catch { return }
        }
    }
}

extension PlayerWaiting {
    fileprivate var isReconnecting: Bool {
        if case .reconnecting = self { return true }
        return false
    }
}
