import Foundation

/// The one way screens play video. Apple's player handles HLS and the files
/// the system can read; a demuxing engine handles raw broadcast streams.
/// `EngineRouter` decides which one a stream goes to, and screens never see
/// the difference.
///
/// What every engine promises:
/// - `load` closes whatever played before it opens the new stream, and calls
///   off any planned reconnect. An abandoned load throws `CancellationError`,
///   never a `PlaybackFailure`.
/// - Each stream method returns a new subscription that first yields the
///   current value, then every change, until the engine goes away.
/// - Nothing an engine reports or logs contains the stream address.
public protocol PlaybackEngine: AnyObject, Sendable {
    /// The current state, the same value `states()` last yielded.
    var state: PlaybackState { get async }

    /// What this engine can do on this device.
    var capabilities: EngineCapabilities { get async }

    /// Opens `url` and returns once the stream is ready to play. Throws a
    /// `PlaybackFailure` when it cannot play, and `CancellationError` when a
    /// newer `load` or `stop` replaced it.
    func load(_ url: URL, options: PlaybackOptions) async throws

    func play() async
    func pause() async

    /// Closes the stream and reports `.idle`.
    func stop() async

    /// Closes the stream for another engine that plays into the same
    /// screen, keeping the last picture on screen until that engine's first
    /// frame. Engines with no shared screen stop.
    func handOver() async

    /// Moves a film to `time`. Throws `SeekRefusal` for live TV and for
    /// films whose server cannot skip.
    func seek(to time: Duration) async throws

    /// Picks an audio track by its id from `tracks()`.
    func selectAudio(_ id: MediaTrack.ID) async

    /// Picks a subtitle track by its id from `tracks()`, or turns subtitles off with nil.
    func selectSubtitle(_ id: MediaTrack.ID?) async

    func states() async -> AsyncStream<PlaybackState>

    /// The picture and sound format, nil until the first frame.
    func presentation() async -> AsyncStream<PresentationInfo?>

    func tracks() async -> AsyncStream<TrackList>

    /// The current time, 1 to 4 times a second while playing and once on pause.
    func position() async -> AsyncStream<PlaybackPosition>

    /// The subtitle lines to draw now. An empty list clears them.
    func subtitleCues() async -> AsyncStream<[SubtitleCue]>

    /// The local buffer of the live channel playing, when the load asked
    /// for one. Engines that never record yield `.off`.
    func timeshift() async -> AsyncStream<TimeshiftStatus>

    /// Moves live TV to `date` inside the buffer, clamped to what it holds,
    /// keeping play or pause. Throws `SeekRefusal.live` without a buffer.
    func seek(to date: Date) async throws

    /// Moves live TV to the newest moment in the buffer. Does nothing without one.
    func seekToLive() async

    /// Sets the live buffer aside, still recording, so the next `load` (a
    /// catch-up programme) does not delete it. Does nothing without one.
    func parkTimeshift() async

    /// Plays the parked buffer again as the live channel, from `date` or
    /// from live for nil. Throws `SeekRefusal.live` when none is parked.
    func resumeParkedTimeshift(at date: Date?) async throws

    /// Deletes the parked buffer.
    func dropParkedTimeshift() async
}

extension PlaybackEngine {
    public func timeshift() async -> AsyncStream<TimeshiftStatus> {
        AsyncStream { continuation in
            continuation.yield(.off)
        }
    }

    public func seek(to date: Date) async throws {
        throw SeekRefusal.live
    }

    public func seekToLive() async {}

    public func parkTimeshift() async {}

    public func resumeParkedTimeshift(at date: Date?) async throws {
        throw SeekRefusal.live
    }

    public func dropParkedTimeshift() async {}
}

extension PlaybackEngine {
    public func handOver() async {
        await stop()
    }

    /// Opens `url` with default options: live or film decided by the stream,
    /// no start time and no language preferences.
    public func load(_ url: URL) async throws {
        try await load(url, options: PlaybackOptions())
    }
}
