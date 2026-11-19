import AntennaCore
import Foundation

/// The pause, then stop, of a channel behind Movies, Series and Search on
/// every platform (tvos-shell/the-video-pauses-behind-movies-series-and-search,
/// live-tv-on-iphone-ipad-mac/the-channel-pauses-behind-movies-series-and-search).
/// The screen that owns the engine says when one of those tabs opens, when
/// a load lands and when Live or the Guide opens again.
@MainActor
final class LiveHold {
    /// What the hold did to the channel.
    enum Kind: Equatable, Sendable {
        /// Paused when the tab opened; Live or the Guide plays on from there.
        case paused
        /// Stopped after 30 seconds; Live or the Guide tunes the channel again.
        case stopped
    }

    /// How long the paused channel waits before it stops.
    static let stopDelay = Duration.seconds(30)

    /// What the hold did, nil when nothing.
    private(set) var kind: Kind?
    private var timer: Task<Void, Never>?
    private let engine: any PlaybackEngine
    private let timeshift: TimeshiftModel
    private let sleep: @MainActor (Duration) async throws -> Void

    init(engine: any PlaybackEngine, timeshift: TimeshiftModel, sleep: @escaping @MainActor (Duration) async throws -> Void) {
        self.engine = engine
        self.timeshift = timeshift
        self.sleep = sleep
    }

    /// Pauses a channel that plays, loads or reconnects, so no sound carries
    /// on behind the tab, and stops it 30 seconds later to free the
    /// provider's connection. The stop happens only while `stillBehind` is
    /// true and the channel has not been played again.
    func begin(stillBehind: @escaping @MainActor () -> Bool) async {
        switch await engine.state {
        case .playing, .loading, .buffering, .reconnecting:
            timeshift.interrupted()
            await engine.pause()
            kind = .paused
        case .idle, .paused, .ended, .failed:
            break
        }
        timer?.cancel()
        timer = Task { [weak self] in
            guard let self else { return }
            do {
                try await sleep(Self.stopDelay)
            } catch {
                return
            }
            guard !Task.isCancelled, stillBehind(), kind == .paused else { return }
            // Played again meanwhile, as from the lock screen, it plays on.
            switch await engine.state {
            case .playing, .buffering, .reconnecting: return
            case .idle, .loading, .paused, .ended, .failed: break
            }
            kind = .stopped
            await engine.stop()
        }
    }

    /// A load that finished behind the tab stays paused, as if it had been
    /// playing when the tab opened. The owner does not play it.
    func loadLanded() {
        guard kind == nil else { return }
        timeshift.interrupted()
        kind = .paused
    }

    /// Ends the hold. A paused channel plays on from where it was. True when
    /// the channel stopped, after 30 seconds or for a movie, and the owner
    /// must tune it again at live.
    func end() async -> Bool {
        timer?.cancel()
        timer = nil
        guard let held = kind else { return false }
        kind = nil
        // A movie played meanwhile stops the paused channel too.
        let state = await engine.state
        guard held == .stopped || state.hasStopped else {
            await timeshift.interruptionEnded()
            return false
        }
        timeshift.channelChanged()
        return true
    }

    /// Forgets the hold without touching the engine, as when a movie
    /// stopped the channel and Live tunes it again by its own path.
    func cancel() {
        timer?.cancel()
        timer = nil
        kind = nil
    }
}

extension PlaybackState {
    /// Failed, or idle after a movie stopped it.
    var hasStopped: Bool {
        switch self {
        case .failed, .idle: true
        case .loading, .playing, .paused, .buffering, .reconnecting, .ended: false
        }
    }
}
