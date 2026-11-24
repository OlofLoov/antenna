import Foundation

/// The Antuna mark's shapes from the owner's artwork of 2026-11-24
/// (design-system/the-antuna-mark), in SVG user units: the baseline at
/// y 0, the x-height at y -118, y pointing down. The path strings are the
/// artwork's, copied unchanged; `MarkPath.elements(_:)` reads them.
public enum MarkGeometry {
    /// A rectangle in the artwork's units.
    public struct Box: Equatable, Sendable {
        public var x: Double
        public var y: Double
        public var width: Double
        public var height: Double
    }

    /// One antenna: a stick from `base` to `stickEnd` and a round tip.
    public struct Antenna: Equatable, Sendable {
        /// Where the stick meets the head; the antenna leans about it.
        public var base: MarkPath.Point
        public var stickEnd: MarkPath.Point
        public var tip: MarkPath.Point
        public var tipRadius: Double = 10
        public var stickWidth: Double = 11
    }

    /// The word "antuna" with its antennae.
    public static let wordBox = Box(x: -6, y: -192, width: 760, height: 198)
    /// The last a with its antennae, centered on the head as in the icon.
    public static let letterBox = Box(x: 575, y: -192, width: 200, height: 200)

    /// The stroke of the first five letters, drawn with round caps and joins.
    public static let letterStroke = 38.0
    /// The first five letters, "a", "n", "t", "u", "n", one stroked path each.
    public static let letters = [
        "M99.0 -59.0A40.0 40.0 0 1 0 19.0 -59.0A40.0 40.0 0 1 0 99.0 -59.0M99.0 -99.0V-19.0",
        "M147.0 -19.0V-99.0M147.0 -59.0A40.0 40.0 0 0 1 227.0 -59.0V-19.0",
        "M289.0 -139.0V-59.0A40.0 40.0 0 0 0 329.0 -19.0M275.0 -99.0H323.0",
        "M377.0 -99.0V-59.0A40.0 40.0 0 0 0 457.0 -59.0M457.0 -99.0V-19.0",
        "M505.0 -19.0V-99.0M505.0 -59.0A40.0 40.0 0 0 1 585.0 -59.0V-19.0",
    ]

    /// The tuna head with the mouth closed to a point, filled. The mouth
    /// is cut out of it by `mouth`.
    public static let head =
        "M673 -118A59 59 0 0 1 673 0C640 0 616 -20 606 -46Q604 -54 611 -57L609 -61L612 -66Q610 -67 612 -72C624 -100 646 -118 673 -118Z"
    /// The mouth wedge, cut out of the head. It opens by stretching
    /// vertically about `mouthOrigin`.
    public static let mouth = "M641 -60L605 -56.3L606 -68Z"
    /// The tail, the a's stem, filled.
    public static let tail =
        "M694 -99C694 -111 700 -119 711 -120L733 -122Q740 -122 738 -116Q726 -90 727 -59"
        + "Q726 -28 738 -2Q740 4 733 4L711 2C700 1 694 -7 694 -19Z"
    /// The play triangle, cut out of the head and the tail, with a round
    /// stroke of `playHoleStroke` for its soft corners.
    public static let playHole = "M659 -81L695 -59L659 -37Z"
    public static let playHoleStroke = 6.0

    /// The eye, cut out only while the mark moves.
    public static let eyeCenter = MarkPath.Point(650, -80)
    public static let eyeRadius = 10.0
    /// How far the play triangle travels to become the eye.
    public static let eyeTravel = MarkPath.Point(-21, -21)

    /// The ring a tip sends out while tuning: a circle of the tip's
    /// radius, stroked at this width and scaled about the tip.
    public static let ringStroke = 3.0

    /// Left, then right.
    public static let antennae = [
        Antenna(base: .init(656, -112), stickEnd: .init(640, -140), tip: .init(635.0, -148.7)),
        Antenna(base: .init(690, -112), stickEnd: .init(704, -141), tip: .init(708.3, -150.0)),
    ]

    /// The points the motions scale, skew and stretch about, where the
    /// prototype put its transform origins.
    public enum Pivot {
        /// The middle of the head and tail together; the head lands about it.
        public static let body = MarkPath.Point(672, -59)
        /// The middle of the play triangle's box.
        public static let playHole = MarkPath.Point(677, -59)
        /// The mouth's hinge, at the back of the wedge.
        public static let mouth = MarkPath.Point(641, -60.5)
        /// The left middle of the tail.
        public static let tail = MarkPath.Point(694, -59)
    }
}

/// The mark's colors as RGB hex (design-system/the-mark-s-colors).
public enum MarkColor {
    /// The app's ground, and the icon's.
    public static let ground: UInt32 = 0x0B0E13
    /// The center of the icon's glow.
    public static let glow: UInt32 = 0x1A2A44
    /// Letters on a dark ground.
    public static let ink: UInt32 = 0xF2F4F8
    /// Tips on a dark ground, the same teal as `ProfileAccent.teal`.
    public static let tip: UInt32 = 0x4FD1C5
    /// Letters on a light ground.
    public static let inkOnLight: UInt32 = 0x0B0E13
    /// Tips on a light ground.
    public static let tipOnLight: UInt32 = 0x119C8F
}
