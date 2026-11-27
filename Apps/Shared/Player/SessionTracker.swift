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
    /// Called with each channel that becomes the last channel, to save it
    /// for launch (session-restore-and-recently-watched/the-last-channel-starts-before-its-source-loads).
    var saved: (Channel) -> Void = { _ in }

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
    /// it was. Throws what the engine throws, or a `PlaybackFailure` when a
    /// portal channel gets no address.
    func load(_ channel: Channel, on engine: any PlaybackEngine, options: PlaybackOptions, toAirPlay: Bool = false) async throws {
        tuned(channel)
        try await StreamResolver.load(channel, on: engine, options: options, toAirPlay: toAirPlay)
        guard let current = self.channel, current.isSame(as: channel) else { return }
        remember(current)
    }

    /// Saves `channel` for launch, then makes it the last channel, so
    /// anything that sees the last channel change finds it saved too.
    func remember(_ channel: Channel) {
        guard let key = LastChannelKey(channel) else { return }
        saved(channel)
        store.write(key)
    }

    /// The list brought `channel`, the one already playing, with fresher
    /// details: it takes the tuned one's place and the count runs on.
    func adopt(_ channel: Channel) {
        guard let current = self.channel, current.isSame(as: channel) else { return }
        self.channel = channel
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
            guard let self, !Task.isCancelled, self.channel?.isSame(as: channel) == true else { return }
            count = nil
            counted = true
            // A channel watched for ten seconds is what was watched last
            // (session-restore-and-recently-watched/what-was-watched-last).
            store.write(LastWatched.live)
            recorded(store.record(key))
        }
    }

    /// `source` was deleted: a channel of it playing now no longer counts.
    func remove(source: UUID) {
        guard channel?.sourceID == source else { return }
        stopCount()
        counted = true
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

extension Channel {
    /// True for the same channel of the same source, whatever details a
    /// fresher list changed.
    func isSame(as other: Channel) -> Bool {
        id == other.id && sourceID == other.sourceID
    }
}
