import Foundation

/// Tells a user scanning through channels from one who has settled on one
/// (playback-engine/channel-switching-is-fast). Two changes in the same
/// direction within `window` mean scanning; no change for `settle` means
/// settled. While scanning, the engine shows each first picture at once and
/// holds back the work a settled channel needs.
public struct ZapTracker: Sendable, Equatable {
    public enum Mode: Sendable, Equatable {
        case settled
        case scanning(ZapAhead.Direction)
    }

    /// Two changes in one direction closer together than this start a scan.
    public static let window = Duration.seconds(2)
    /// A scan ends when no change comes for this long.
    public static let settle = Duration.milliseconds(1500)

    private var lastDirection: ZapAhead.Direction?
    private var lastChange: ContinuousClock.Instant?
    private var scanning = false

    public init() {}

    /// Records a channel change and returns the mode it leaves the user in.
    public mutating func zapped(_ direction: ZapAhead.Direction, at now: ContinuousClock.Instant) -> Mode {
        let continues = lastDirection == direction && lastChange.map { now - $0 < Self.window } == true
        scanning = continues
        lastDirection = direction
        lastChange = now
        return scanning ? .scanning(direction) : .settled
    }

    /// The mode at `now`: a scan that has had no change for `settle` is over.
    public func mode(at now: ContinuousClock.Instant) -> Mode {
        guard scanning, let lastDirection, let lastChange, now - lastChange < Self.settle else { return .settled }
        return .scanning(lastDirection)
    }
}
