import Foundation

/// The frame rate and dynamic range a TV is switched to for a stream on
/// Apple TV with Match Frame Rate and Match Dynamic Range on
/// (playback-engine/the-screen-learns-the-picture-and-sound-format).
/// Two channels in the same mode leave the TV alone when the user zaps.
public struct DisplayMode: Sendable, Equatable {
    /// Frames a second, one of the broadcast rates `FrameRate.nearest` gives.
    public var frameRate: Double
    public var dynamicRange: PresentationInfo.DynamicRange

    public init(frameRate: Double, dynamicRange: PresentationInfo.DynamicRange) {
        self.frameRate = frameRate
        self.dynamicRange = dynamicRange
    }

    /// The mode for a picture, nil when its frame rate is not known.
    public init?(_ video: PresentationInfo.Video) {
        guard let rate = video.frameRate.flatMap(FrameRate.nearest) else { return nil }
        self.init(frameRate: rate, dynamicRange: video.dynamicRange)
    }
}

/// Frame rates from what a stream says or from its timestamps.
public enum FrameRate {
    /// The rates broadcast and film use.
    public static let standard: [Double] = [23.976, 24, 25, 29.97, 30, 48, 50, 59.94, 60]

    /// The standard rate within 1% of `rate`, or nil.
    public static func nearest(_ rate: Double) -> Double? {
        standard.min { abs($0 - rate) < abs($1 - rate) }.flatMap { abs($0 - rate) / $0 <= 0.01 ? $0 : nil }
    }

    /// The rate the presentation times of a run of frames show, in seconds
    /// and in any order: the smallest step between them. Nil with fewer
    /// than two distinct times or no standard rate near the step.
    public static func estimate(presentationTimes times: [Double]) -> Double? {
        let sorted = Set(times.filter(\.isFinite)).sorted()
        let steps = zip(sorted, sorted.dropFirst()).map { $1 - $0 }.filter { $0 > 0.001 }
        return steps.min().flatMap { nearest(1 / $0) }
    }
}

/// Keeps the TV in one stream's mode across channel changes on Apple TV
/// (playback-engine/the-screen-learns-the-picture-and-sound-format).
///
/// `match` says whether the TV has to be asked for a mode: only when it
/// differs from the one it is in. `letGo` leaves the mode after
/// `releaseDelay` unless a stream asks for one before then, so a switch
/// between the two playback paths, which stops one engine before the other
/// starts, does not switch the TV twice.
@MainActor
public final class DisplayModeKeeper {
    public private(set) var mode: DisplayMode?
    private let releaseDelay: Duration
    private let sleep: @Sendable (Duration) async throws -> Void
    private let leave: @MainActor () -> Void
    private var release: Task<Void, Never>?

    public static let releaseDelay = Duration.seconds(1)

    /// `leave` returns the TV to its own mode.
    public init(
        releaseDelay: Duration = DisplayModeKeeper.releaseDelay,
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        leave: @escaping @MainActor () -> Void
    ) {
        self.releaseDelay = releaseDelay
        self.sleep = sleep
        self.leave = leave
    }

    /// A stream needs `mode`. True when the TV is in another mode and the
    /// caller should ask for this one.
    public func match(_ mode: DisplayMode) -> Bool {
        release?.cancel()
        release = nil
        guard mode != self.mode else { return false }
        self.mode = mode
        return true
    }

    /// Playback stopped. The TV leaves the mode once `releaseDelay` passes
    /// with no stream asking for one.
    public func letGo() {
        guard mode != nil, release == nil else { return }
        let sleep = self.sleep
        let delay = releaseDelay
        release = Task { [weak self] in
            do {
                try await sleep(delay)
            } catch {
                return
            }
            guard let self, !Task.isCancelled else { return }
            self.release = nil
            self.mode = nil
            self.leave()
        }
    }
}
