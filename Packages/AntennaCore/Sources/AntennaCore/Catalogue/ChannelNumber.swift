import Foundation

/// A channel's number as shown, with the part after the dot of an
/// over-the-air number such as 6.1 (channel-catalogue/numbers-with-a-part-after-the-dot).
///
/// Orders by major then minor, a missing minor before 0, so 6, 6.1, 6.2, 7.
public struct ChannelNumber: Sendable, Hashable, Comparable, CustomStringConvertible, ExpressibleByIntegerLiteral {
    public var major: Int
    public var minor: Int?

    public init(major: Int, minor: Int? = nil) {
        self.major = major
        self.minor = minor
    }

    /// A whole number, so fixtures can write `104`.
    public init(integerLiteral value: Int) {
        self.init(major: value)
    }

    /// "6.1" with a minor number, "6000" without.
    public var description: String {
        minor.map { "\(major).\($0)" } ?? String(major)
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.major, lhs.minor ?? -1) < (rhs.major, rhs.minor ?? -1)
    }
}

extension Channel {
    /// The provider's number with its part after the dot, nil without a number.
    public var channelNumber: ChannelNumber? {
        number.map { ChannelNumber(major: $0, minor: minorNumber) }
    }
}
