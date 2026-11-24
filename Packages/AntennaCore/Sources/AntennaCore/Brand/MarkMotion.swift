import Foundation

/// When the mark moves (design-system/the-mark-moves-at-three-moments).
public enum MarkMoment: String, CaseIterable, Sendable {
    /// Standing still, with the play triangle in the middle and no eye.
    case still
    /// Launch and onboarding, once.
    case hello
    /// While something loads, for as long as it lasts.
    case tuning
    /// The wait is over, once.
    case gotIt
}

/// Every moving part of the mark at one instant. Offsets are in the
/// artwork's units, angles in degrees clockwise, scales about the part's
/// own pivot (`MarkGeometry.Pivot`, the tip, or the antenna's base).
public struct MarkPose: Equatable, Sendable {
    /// A part that slides and stretches about its pivot.
    public struct Part: Equatable, Sendable {
        public var dx = 0.0
        public var dy = 0.0
        public var scaleX = 1.0
        public var scaleY = 1.0

        public static let identity = Part()
        public static let hidden = Part(scaleX: 0, scaleY: 0)
    }

    /// A stroked path drawn from its start up to `drawn` of its length.
    public struct Stroke: Equatable, Sendable {
        public var drawn = 1.0
        public var opacity = 1.0
    }

    public struct Antenna: Equatable, Sendable {
        /// Rotation about the antenna's base.
        public var lean = 0.0
        public var stick = Stroke()
        public var tipScale = 1.0
        /// How far the tip sits above its place, in units.
        public var tipLift = 0.0
        public var tipOpacity = 1.0
        public var ringScale = 1.0
        /// 0 hides the ring.
        public var ringOpacity = 0.0
    }

    /// The whole mark's opacity, for the Reduce Motion fades.
    public var opacity = 1.0
    /// The five letters before the last a.
    public var letters = Array(repeating: Stroke(), count: 5)
    /// The head and tail, with everything cut out of them.
    public var bodyScale = 1.0
    /// The tail's vertical skew.
    public var tailSkew = 0.0
    /// The mouth wedge's vertical stretch about its hinge; 1 is closed.
    public var mouthOpen = 1.0
    /// The play triangle; it becomes the eye by sliding by
    /// `MarkGeometry.eyeTravel` while shrinking to nothing.
    public var playHole = Part.identity
    /// The eye, offset from `MarkGeometry.eyeCenter`; hidden when still.
    public var eye = Part.hidden
    /// Left, then right.
    public var antennae = [Antenna(), Antenna()]

    public init() {}

    /// The mark at rest.
    public static let still = MarkPose()
}

/// The three motions as keyframe tables, ported from the owner's web
/// prototype (design.md decision 2 of add-tuna-wordmark), and their
/// Reduce Motion forms (design-system/reduce-motion-stills-the-mark).
public enum MarkMotion {
    /// How long a moment plays before it stands still; nil for Tuning,
    /// which loops, and for the still mark.
    public static func duration(_ moment: MarkMoment, reduceMotion: Bool) -> Double? {
        switch moment {
        case .still, .tuning: nil
        case .hello: reduceMotion ? 0.4 : 3.2
        case .gotIt: reduceMotion ? 0.4 : 1.2
        }
    }

    /// Tuning repeats every this many seconds, with or without Reduce Motion.
    public static let tuningPeriod = 2.4

    /// The pose `seconds` after `moment` started. Past a one-shot
    /// moment's duration it is the still pose.
    public static func pose(_ moment: MarkMoment, at seconds: Double, reduceMotion: Bool) -> MarkPose {
        if reduceMotion { return reduced(moment, at: seconds) }
        switch moment {
        case .still: return .still
        case .hello: return hello(at: seconds)
        case .tuning: return tuning(at: seconds)
        case .gotIt: return gotIt(at: seconds)
        }
    }

    // MARK: - Reduce Motion

    private static func reduced(_ moment: MarkMoment, at time: Double) -> MarkPose {
        var pose = MarkPose.still
        switch moment {
        case .still:
            break
        case .hello:
            pose.opacity = Track(0.4, .easeInOut, [(0, [0]), (1, [1])]).scalar(time)
        case .gotIt:
            pose.opacity = Track(0.4, .easeInOut, [(0, [0.5]), (1, [1])]).scalar(time)
        case .tuning:
            let pulse = Track(tuningPeriod, .easeInOut, [(0, [1]), (0.5, [0.35]), (1, [1])], repeats: true).scalar(time)
            for side in pose.antennae.indices { pose.antennae[side].tipOpacity = pulse }
        }
        return pose
    }

    // MARK: - Hello

    private static let land = CubicBezier(0.3, 1.5, 0.5, 1)
    private static let pop = CubicBezier(0.3, 1.8, 0.5, 1)
    private static let draw = CubicBezier(0.5, 0, 0.3, 1)

    /// A stroke drawing itself, which fades in over the first 4% as in the
    /// prototype. The fade has its own keys, so the draw eases over the
    /// whole length.
    private static func drawing(_ duration: Double, delay: Double, _ curve: CubicBezier, at time: Double) -> MarkPose.Stroke {
        MarkPose.Stroke(
            drawn: Track(duration, curve, [(0, [0]), (1, [1])], delay: delay).scalar(time),
            opacity: Track(duration, curve, [(0, [0]), (0.04, [1]), (1, [1])], delay: delay).scalar(time))
    }

    private static func hello(at time: Double) -> MarkPose {
        var pose = MarkPose.still
        for index in pose.letters.indices {
            pose.letters[index] = drawing(0.55, delay: 0.09 * Double(index), draw, at: time)
        }
        pose.bodyScale = Track(0.45, land, [(0, [0]), (1, [1])], delay: 0.5).scalar(time)
        let hole = Track(
            3.2, .easeInOut,
            [
                (0, [0, 0, 0]), (0.26, [0, 0, 0]), (0.32, [0, 0, 1.15]), (0.36, [0, 0, 1]), (0.62, [0, 0, 1]),
                (0.70, [-21, -21, 0]), (0.86, [-21, -21, 0]), (0.95, [0, 0, 1]), (1, [0, 0, 1]),
            ]
        ).value(time)
        pose.playHole = .init(dx: hole[0], dy: hole[1], scaleX: hole[2], scaleY: hole[2])
        let eyeIn = Track(
            3.2, .easeInOut, [(0, [0]), (0.66, [0]), (0.72, [1.15]), (0.75, [1]), (0.86, [1]), (0.90, [0]), (1, [0])]
        ).scalar(time)
        let blink = Track(0.24, .easeInOut, [(0, [1]), (0.5, [0.1]), (1, [1])], delay: 2.45).scalar(time)
        pose.eye = .init(scaleX: eyeIn, scaleY: eyeIn * blink)
        pose.mouthOpen = Track(0.5, .easeInOut, [(0, [1]), (0.4, [3]), (0.7, [1.5]), (1, [1])], delay: 1.55).scalar(time)
        for (side, delay) in [(0, 0.0), (1, 0.07)] {
            pose.antennae[side].stick = drawing(0.25, delay: 1.05 + delay, .easeOut, at: time)
            pose.antennae[side].tipScale = Track(0.35, pop, [(0, [0]), (1, [1])], delay: 1.25 + delay).scalar(time)
        }
        return pose
    }

    // MARK: - Tuning

    private static func tuning(at time: Double) -> MarkPose {
        var pose = MarkPose.still
        let leans: [[Double]] = [[0, -14, 9, 0], [0, -9, 14, 0]]
        for side in 0..<2 {
            let lean = leans[side]
            pose.antennae[side].lean = Track(
                tuningPeriod, .easeInOut, [(0, [lean[0]]), (0.3, [lean[1]]), (0.65, [lean[2]]), (1, [lean[3]])], repeats: true
            ).scalar(time)
            let ring = Track(
                1.2, .easeOut, [(0, [1, 0.7]), (1, [2.6, 0])], delay: 0.6 * Double(side), repeats: true, before: [1, 0]
            ).value(time)
            pose.antennae[side].ringScale = ring[0]
            pose.antennae[side].ringOpacity = ring[1]
        }
        pose.mouthOpen = Track(tuningPeriod, .easeInOut, [(0, [1]), (0.5, [2.1]), (1, [1])], repeats: true).scalar(time)
        let hole = Track(0.35, .easeIn, [(0, [0, 0, 1]), (1, [-21, -21, 0])]).value(time)
        pose.playHole = .init(dx: hole[0], dy: hole[1], scaleX: hole[2], scaleY: hole[2])
        let eyeIn = Track(0.3, CubicBezier(0.3, 1.6, 0.5, 1), [(0, [0]), (1, [1])], delay: 0.25).scalar(time)
        let look = Track(
            tuningPeriod, .easeInOut, [(0, [0, 0]), (0.3, [-3, -1]), (0.6, [3, -1]), (1, [0, 0])], repeats: true
        ).value(time)
        let blink = Track(
            tuningPeriod, .easeInOut, [(0, [1]), (0.8, [1]), (0.86, [0.1]), (0.92, [1]), (1, [1])], repeats: true
        ).scalar(time)
        pose.eye = .init(dx: look[0], dy: look[1], scaleX: eyeIn, scaleY: eyeIn * blink)
        return pose
    }

    // MARK: - Got it

    private static func gotIt(at time: Double) -> MarkPose {
        var pose = MarkPose.still
        pose.tailSkew = Track(
            0.7, .easeOut, [(0, [0]), (0.25, [-20]), (0.55, [12]), (0.8, [-3]), (1, [0])], delay: 0.15
        ).scalar(time)
        for (side, delay) in [(0, 0.3), (1, 0.38)] {
            pose.antennae[side].tipLift = Track(
                0.45, CubicBezier(0.3, 0, 0.4, 1), [(0, [0]), (0.45, [9]), (1, [0])], delay: delay
            ).scalar(time)
        }
        pose.mouthOpen = Track(
            0.6, .easeOut, [(0, [1]), (0.3, [3.4]), (0.55, [1]), (0.75, [1.8]), (1, [1])], delay: 0.1
        ).scalar(time)
        let hole = Track(
            1.2, .easeInOut, [(0, [-21, -21, 0]), (0.52, [-21, -21, 0]), (0.8, [0, 0, 1.12]), (0.9, [0, 0, 1]), (1, [0, 0, 1])]
        ).value(time)
        pose.playHole = .init(dx: hole[0], dy: hole[1], scaleX: hole[2], scaleY: hole[2])
        let eyeIn = Track(1.2, .easeInOut, [(0, [1]), (0.5, [1]), (0.6, [0]), (1, [0])]).scalar(time)
        let squint = Track(1.2, .easeInOut, [(0, [1, 1]), (0.12, [1.15, 0.4]), (0.4, [1.15, 0.4]), (1, [1, 1])]).value(time)
        pose.eye = .init(scaleX: eyeIn * squint[0], scaleY: eyeIn * squint[1])
        return pose
    }
}

/// One CSS animation: keyframes at offsets from 0 to 1, each value a list
/// of numbers, eased by `curve` between each pair of keys as a browser
/// does. Before `delay` it holds `before`, or the first key; a one-shot
/// track holds its last key after it ends.
struct Track {
    var duration: Double
    var curve: CubicBezier
    var keys: [(offset: Double, values: [Double])]
    var delay: Double
    var repeats: Bool
    var before: [Double]?

    init(
        _ duration: Double, _ curve: CubicBezier, _ keys: [(Double, [Double])], delay: Double = 0, repeats: Bool = false,
        before: [Double]? = nil
    ) {
        self.duration = duration
        self.curve = curve
        self.keys = keys.map { (offset: $0.0, values: $0.1) }
        self.delay = delay
        self.repeats = repeats
        self.before = before
    }

    func value(_ time: Double) -> [Double] {
        let local = time - delay
        guard let first = keys.first, let last = keys.last else { return [] }
        if local < 0 { return before ?? first.values }
        let progress = repeats ? local.truncatingRemainder(dividingBy: duration) / duration : min(local / duration, 1)
        if progress >= last.offset { return last.values }
        guard let next = keys.firstIndex(where: { $0.offset > progress }), next > 0 else { return first.values }
        let (from, to) = (keys[next - 1], keys[next])
        let eased = curve((progress - from.offset) / (to.offset - from.offset))
        return zip(from.values, to.values).map { $0 + ($1 - $0) * eased }
    }

    func scalar(_ time: Double) -> Double { value(time).first ?? 0 }
}
