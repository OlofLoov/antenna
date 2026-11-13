import Foundation

/// The words and positions the timeshift row and strip show
/// (timeshift-catch-up-and-start-over capability).
public enum TimeshiftText {
    /// "12 min behind", the minutes rounded up; nil within `tolerance` of live.
    public static func behind(_ seconds: TimeInterval, tolerance: TimeInterval) -> String? {
        guard seconds > tolerance else { return nil }
        return "\(Int((seconds / 60).rounded(.up))) min behind"
    }

    /// The Apple TV zap bar's hint while behind live.
    public static let liveHint = "Hold play/pause for live"

    /// The first pause on a device with too little free storage.
    public static let storageShort = "Not enough free storage to rewind live TV"

    /// Start over through catch-up failed and the buffer does not reach the start.
    public static let startOverUnavailable = "Start over isn't available for this programme"

    /// A double-tap to skip on a channel with nothing to rewind.
    public static let rewindUnavailable = "Rewind isn't available on this channel"

    /// A double-tap to skip forward while already at live.
    public static let alreadyLive = "Already live"

    /// The line a notice shows.
    public static func notice(_ notice: TimeshiftNotice) -> String {
        switch notice {
        case .bufferFull: "Buffer full. Playing from the earliest point"
        case .storageFull(let wasBehind): wasBehind ? "Storage is full. Back to live TV" : "Storage is full"
        case .rewindFailed(let wasBehind): wasBehind ? "Rewind stopped working. Back to live TV" : "Rewind stopped working"
        case .skippedToLive: "Skipped ahead to live"
        }
    }

    /// Where `date` sits between the window's start and end, 0 to 1.
    public static func fraction(of date: Date, in window: TimeshiftWindow) -> Double {
        guard window.duration > 0 else { return 1 }
        return min(1, max(0, date.timeIntervalSince(window.start) / window.duration))
    }

    /// The moment at `fraction` of the window.
    public static func date(at fraction: Double, in window: TimeshiftWindow) -> Date {
        window.start.addingTimeInterval(window.duration * min(1, max(0, fraction)))
    }

    /// The gaps as start and end fractions of the window, for the scrubber.
    public static func gaps(in window: TimeshiftWindow) -> [ClosedRange<Double>] {
        window.gaps.map { fraction(of: $0.start, in: window)...fraction(of: $0.end, in: window) }
    }
}

/// Where a skip, scan or drag lands in the buffer
/// (timeshift-catch-up-and-start-over/skip-scan-and-drag).
public enum TimeshiftMove: Sendable, Equatable {
    /// A moment inside the buffer, never before its start.
    case to(Date)
    /// At or past now: back to live.
    case live

    /// `seconds` from `playhead`, negative going back.
    public static func skip(_ seconds: TimeInterval, from playhead: Date, in window: TimeshiftWindow, limits: TimeshiftLimits) -> Self {
        landing(playhead.addingTimeInterval(seconds), in: window, limits: limits)
    }

    /// A target clamped to the buffer; within the live-edge tolerance of
    /// its end it is live.
    public static func landing(_ target: Date, in window: TimeshiftWindow, limits: TimeshiftLimits) -> Self {
        if target >= window.end.addingTimeInterval(-limits.liveEdgeTolerance) { return .live }
        return .to(max(target, window.start))
    }

    /// Where a scan from `start` is after `held` seconds at the scan rate.
    public static func scan(from start: Date, forward: Bool, held: TimeInterval, in window: TimeshiftWindow, rate: Double) -> Date {
        window.clamped(start.addingTimeInterval((forward ? 1 : -1) * held * rate))
    }
}
