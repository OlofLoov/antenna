import Foundation

/// Every number timeshift and Start over tune by, in one place.
public struct TimeshiftLimits: Sendable, Equatable {
    /// How far back the buffer keeps, in seconds.
    public var window: TimeInterval = 3600
    /// The most the buffer stores, in bytes.
    public var byteCap: Int
    /// Free space the buffer always leaves on the device, in bytes.
    public var keepFree: Int = 1 << 30
    /// Below this much usable space at tune time, nothing is recorded.
    public var minimumUsable: Int = 64 << 20
    /// Within this many seconds of the newest recorded moment counts as live.
    public var liveEdgeTolerance: TimeInterval = 10
    public var skipBack: TimeInterval = 15
    public var skipForward: TimeInterval = 30
    /// How many times real time a held scan moves.
    public var scanRate: Double = 60
    /// A press shorter than this is a click; longer is a hold.
    public var clickLimit: Duration = .milliseconds(300)
    /// Holding play/pause this long on Apple TV goes to live.
    public var holdForLive: Duration = .milliseconds(500)
    /// Catch-up skips this close together load once.
    public var catchupCoalesce: Duration = .milliseconds(400)
    /// The share of the oldest recording dropped once when a write fails.
    public var dropOnWriteFailure: Double = 0.1
    /// The least time between two chunks, in seconds; a start point sooner
    /// than this stays in the chunk it is in.
    public var chunkSpacing: TimeInterval = 1
    /// A pause in incoming data longer than this, in seconds, shows as a gap.
    public var gapThreshold: TimeInterval = 5

    public init(byteCap: Int) {
        self.byteCap = byteCap
    }

    /// The device kinds with their own storage cap.
    public enum Device: Sendable {
        case phone, pad, mac, tv
    }

    /// 4 GiB on Apple TV and Mac, 2 GiB on iPhone and iPad.
    public static func standard(for device: Device) -> TimeshiftLimits {
        switch device {
        case .tv, .mac: TimeshiftLimits(byteCap: 4 << 30)
        case .phone, .pad: TimeshiftLimits(byteCap: 2 << 30)
        }
    }

    /// The bytes the buffer may use with `free` bytes free on the device:
    /// the cap, less what must stay free. Nil below `minimumUsable`.
    public func usableBytes(free: Int) -> Int? {
        let usable = min(byteCap, free - keepFree)
        return usable >= minimumUsable ? usable : nil
    }
}
