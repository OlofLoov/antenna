import Foundation

/// Asks an engine to record a live channel to a local buffer while it
/// plays, so it can pause, rewind and go back to live
/// (timeshift-catch-up-and-start-over capability).
public struct TimeshiftRequest: Sendable, Equatable {
    public var store: TimeshiftStore
    public var limits: TimeshiftLimits
    /// The buffer's file operations; tests make them fail.
    public var files: any TimeshiftFiles
    /// Stamps each write; tests move it by hand.
    public var now: @Sendable () -> Date

    public init(
        store: TimeshiftStore = .standard, limits: TimeshiftLimits, files: any TimeshiftFiles = DiskTimeshiftFiles(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.store = store
        self.limits = limits
        self.files = files
        self.now = now
    }

    /// Equal when they record to the same root with the same limits.
    public static func == (lhs: TimeshiftRequest, rhs: TimeshiftRequest) -> Bool {
        lhs.store.root == rhs.store.root && lhs.limits == rhs.limits
    }
}

/// Whether and where the channel playing is recorded, and where playback is.
public struct TimeshiftStatus: Sendable, Equatable {
    public enum Recording: Sendable, Equatable {
        /// No timeshift asked for, or nothing plays.
        case off
        case recording
        /// The stream is not one the buffer can record, such as HLS.
        case cannotRecord
        /// Too little free storage at tune time.
        case storageShort
        /// Recording stopped partway after a write or read failed.
        case stopped
    }

    public var recording: Recording
    /// What the buffer holds; nil until its first start point.
    public var window: TimeshiftWindow?
    /// The moment on screen; nil while nothing is recorded.
    public var playhead: Date?
    /// The newest notice, and how many have come before it, so a watcher
    /// that joins late can tell a new one from one it saw.
    public var notice: TimeshiftNotice?
    public var noticeCount: Int

    public static let off = TimeshiftStatus(recording: .off)

    public init(
        recording: Recording, window: TimeshiftWindow? = nil, playhead: Date? = nil, notice: TimeshiftNotice? = nil, noticeCount: Int = 0
    ) {
        self.recording = recording
        self.window = window
        self.playhead = playhead
        self.notice = notice
        self.noticeCount = noticeCount
    }

    /// Seconds from the playhead to the newest recorded moment, 0 at live.
    public var behind: TimeInterval {
        guard let window, let playhead else { return 0 }
        return max(0, window.end.timeIntervalSince(playhead))
    }

    /// True when the playhead is within `tolerance` seconds of live, or nothing is recorded.
    public func isAtLive(tolerance: TimeInterval) -> Bool {
        behind <= tolerance
    }
}

/// Something the player says once about the buffer.
public enum TimeshiftNotice: Sendable, Equatable {
    /// The pause outlasted the buffer; playback goes on from the earliest point.
    case bufferFull
    /// A write failed for lack of space; playback went back to live.
    case storageFull(wasBehind: Bool)
    /// A write or read failed; playback went back to live.
    case rewindFailed(wasBehind: Bool)
    /// Playback reached a gap in the recording and jumped to live.
    case skippedToLive
}
