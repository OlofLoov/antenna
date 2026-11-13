import Foundation

/// When a playing movie or episode saves its position
/// (movies-and-series-browsing/your-place-is-saved-as-you-watch): every 30
/// seconds of wall time while it plays, and when the user pauses or stops,
/// the app goes to the background, or the title ends. Live TV saves nothing.
///
/// Feed it the engine's positions and states; each call returns the position
/// to save, or nil.
public struct PositionSaving: Sendable {
    /// How often a playing title saves.
    public static let interval: Duration = .seconds(30)

    private var latest: PlaybackPosition?
    private var lastSave: ContinuousClock.Instant?
    private var isPlaying = false

    public init() {}

    /// A new position from the engine. Returns it when 30 seconds passed
    /// since the last save while playing.
    public mutating func position(_ position: PlaybackPosition, at now: ContinuousClock.Instant) -> PlaybackPosition? {
        guard !position.isLive else { return nil }
        latest = position
        guard isPlaying else { return nil }
        guard let lastSave else {
            self.lastSave = now
            return nil
        }
        guard now - lastSave >= Self.interval else { return nil }
        self.lastSave = now
        return position
    }

    /// A new state from the engine. Pausing saves where it paused; the end
    /// saves the full length, so the title counts as watched.
    public mutating func state(_ state: PlaybackState, at now: ContinuousClock.Instant) -> PlaybackPosition? {
        switch state {
        case .playing:
            if !isPlaying { lastSave = now }
            isPlaying = true
            return nil
        case .paused:
            isPlaying = false
            return saved(at: now)
        case .ended:
            isPlaying = false
            guard var position = latest, let length = position.duration else { return saved(at: now) }
            position.time = length
            latest = position
            return saved(at: now)
        default:
            return nil
        }
    }

    /// The user skipped or scrubbed to `time`. Returns the new position to
    /// save now, so closing before the engine reports it still resumes there
    /// (movies-and-series-browsing/your-place-is-saved-as-you-watch).
    /// Nil before the engine reported anything, and for live TV.
    public mutating func moved(to time: Duration, at now: ContinuousClock.Instant) -> PlaybackPosition? {
        guard var position = latest, !position.isLive else { return nil }
        position.time = time
        latest = position
        return saved(at: now)
    }

    /// The user stopped or the app went to the background: save where it is.
    public mutating func leaving(at now: ContinuousClock.Instant) -> PlaybackPosition? {
        isPlaying = false
        return saved(at: now)
    }

    private mutating func saved(at now: ContinuousClock.Instant) -> PlaybackPosition? {
        guard let latest, !latest.isLive else { return nil }
        lastSave = now
        return latest
    }
}
