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
}

extension PlaybackEngine {
    /// Opens `url` with default options: live or film decided by the stream,
    /// no start time and no language preferences.
    public func load(_ url: URL) async throws {
        try await load(url, options: PlaybackOptions())
    }
}
