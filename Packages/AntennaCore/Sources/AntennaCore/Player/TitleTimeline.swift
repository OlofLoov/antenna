import Foundation

/// Where a movie or episode is and where a skip or a scrub takes it
/// (player-controls-and-playback-errors/move-around-in-a-movie-or-episode).
/// Every time it returns lies between the start and the end of the title.
public struct TitleTimeline: Sendable, Equatable {
    /// How far back 10 and forward 10 move.
    public static let skip = Duration.seconds(10)

    /// The time on screen, from the start of the title.
    public var time: Duration
    /// The title's length, nil while the stream does not give it.
    public var length: Duration?

    public init(time: Duration, length: Duration?) {
        self.time = max(.zero, time)
        self.length = length
    }

    /// `time` moved by `offset`, back when negative, kept between the start
    /// and the end. With no length only the start bounds it.
    public func skipped(by offset: Duration) -> Duration {
        clamped(time + offset)
    }

    /// `time` moved 10 seconds forward or back.
    public func skipped(forward: Bool) -> Duration {
        skipped(by: forward ? Self.skip : .zero - Self.skip)
    }

    /// How far into the title `time` is, 0 to 1; nil with no length.
    public var fraction: Double? {
        fraction(of: time)
    }

    /// How far into the title `moment` is, 0 to 1; nil with no length.
    public func fraction(of moment: Duration) -> Double? {
        guard let length, length > .zero else { return nil }
        return min(1, max(0, moment / length))
    }

    /// The time at `fraction` of the length, as a scrubber drag gives it;
    /// nil with no length.
    public func time(at fraction: Double) -> Duration? {
        guard let length, length > .zero else { return nil }
        return clamped(length * min(1, max(0, fraction)))
    }

    /// How far one slide across the whole Apple TV touch surface moves the
    /// target: an eighth of the title, at least a minute and at most 20.
    /// Nil with no length, where only skips work.
    public var slideSpan: Duration? {
        guard let length, length > .zero else { return nil }
        return min(.seconds(20 * 60), max(.seconds(60), length / 8))
    }

    /// The target after sliding `slide` of the touch surface's width from
    /// `base`, right when positive; nil with no length.
    public func slid(from base: Duration, by slide: Double) -> Duration? {
        guard let slideSpan else { return nil }
        return clamped(base + slideSpan * slide)
    }

    /// `moment` kept between the start and the end.
    public func clamped(_ moment: Duration) -> Duration {
        let floor = max(.zero, moment)
        guard let length else { return floor }
        return min(length, floor)
    }

    // MARK: Text

    /// "4:05" under an hour, "1:02:03" from an hour on, rounded down to the second.
    public static func clock(_ duration: Duration) -> String {
        let total = max(0, Int(duration.components.seconds))
        let hours = total / 3600
        let minutes = total % 3600 / 60
        let seconds = total % 60
        let tail = String(format: "%02d", seconds)
        return hours > 0 ? "\(hours):\(String(format: "%02d", minutes)):\(tail)" : "\(minutes):\(tail)"
    }

    /// The elapsed time, as on the left of the bar.
    public func elapsedText(at moment: Duration? = nil) -> String {
        Self.clock(clamped(moment ?? time))
    }

    /// What is left after `moment`, as "-1:02:03" on the right of the bar;
    /// nil with no length.
    public func remainingText(at moment: Duration? = nil) -> String? {
        guard let length else { return nil }
        let left = length - clamped(moment ?? time)
        return "-" + Self.clock(left + .milliseconds(999))
    }

    /// "12 minutes, 4 seconds of 1 hour, 30 minutes" for VoiceOver, or the
    /// elapsed time alone with no length.
    public func spokenText(at moment: Duration? = nil) -> String {
        let elapsed = Self.spoken(clamped(moment ?? time))
        guard let length else { return elapsed }
        return "\(elapsed) of \(Self.spoken(length))"
    }

    private static func spoken(_ duration: Duration) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.zeroFormattingBehavior = .dropAll
        let seconds = max(0, Int(duration.components.seconds))
        return seconds == 0 ? "0 seconds" : formatter.string(from: TimeInterval(seconds)) ?? clock(duration)
    }
}
