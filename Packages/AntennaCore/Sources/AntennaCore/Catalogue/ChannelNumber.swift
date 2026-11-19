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

    /// The number as a person reads it in `locale`: that region's digits and
    /// never a grouping separator, so 1001 stays "1001" and reads "١٠٠١" in
    /// Arabic (localization/numbers-use-the-region-s-digits-and-separators).
    public func text(_ locale: Locale = .autoupdatingCurrent) -> String {
        let style = IntegerFormatStyle<Int>.number.grouping(.never).locale(locale)
        return minor.map { "\(major.formatted(style)).\($0.formatted(style))" } ?? major.formatted(style)
    }

    /// The value of a digit in any script, so a number typed with
    /// Arabic-Indic digits finds the same channel. Nil for anything else.
    public static func digit(_ character: Character) -> Character? {
        guard character.isNumber, let value = character.wholeNumberValue, (0...9).contains(value) else { return nil }
        return Character(String(value))
    }

    /// Typed digits, "0" to "9", in `locale`'s digits, keeping leading zeros.
    public static func digits(_ typed: String, locale: Locale = .autoupdatingCurrent) -> String {
        String(typed.flatMap { $0.wholeNumberValue.map { $0.formatted(.number.locale(locale)) } ?? String($0) })
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
