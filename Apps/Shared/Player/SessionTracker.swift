import AntennaCore
import Foundation

/// Every live tune passes through here on every device: it stores the last
/// channel once its stream loads, and adds a channel to Recents after ten
/// seconds of uninterrupted playback
/// (session-restore-and-recently-watched/a-channel-counts-as-watched-after-ten-seconds).
///
/// A new tune, a state other than playing, a movie or episode starting and
/// leaving the app each stop the count; it starts again from zero the next
/// time the channel plays.
@MainActor
final class SessionTracker {
    static let watchedAfter = Duration.seconds(10)

    let store: RecentsStore
    /// Called with the new list each time a channel counts as watched.
    var recorded: (RecentChannels) -> Void = { _ in }

    private let sleep: @MainActor (Duration) async throws -> Void
    private(set) var channel: Channel?
    private var counted = false
    private var count: Task<Void, Never>?

    init(store: RecentsStore, sleep: @escaping @MainActor (Duration) async throws -> Void = { try await Task.sleep(for: $0) }) {
        self.store = store
        self.sleep = sleep
    }

    /// Loads `channel` on `engine`. Once the stream loads, it becomes the
    /// last channel; a stream that fails to load leaves the last channel as
    /// it was. Throws what the engine throws.
    func load(_ channel: Channel, on engine: any PlaybackEngine, options: PlaybackOptions) async throws {
        tuned(channel)
        try await engine.load(channel.streamURL, options: options)
        guard self.channel == channel, let key = LastChannelKey(channel) else { return }
        store.write(key)
    }

    /// `channel` was tuned, or nothing plays when it is nil. Stops the count.
    func tuned(_ channel: Channel?) {
        stopCount()
        self.channel = channel
        counted = false
    }

    /// The engine moved to `state`. Playing starts the count for the tuned
    /// channel; anything else stops it.
    func stateChanged(_ state: PlaybackState) {
        guard case .playing = state else { return stopCount() }
        guard count == nil, !counted, let channel, let key = LastChannelKey(channel) else { return }
        count = Task { [weak self, sleep] in
            do {
                try await sleep(Self.watchedAfter)
            } catch {
                return
            }
            guard let self, !Task.isCancelled, self.channel == channel else { return }
            count = nil
            counted = true
            recorded(store.record(key))
        }
    }

    /// A movie or episode is starting, or the app left the screen.
    func interrupt() {
        stopCount()
    }

    private func stopCount() {
        count?.cancel()
        count = nil
    }
}
