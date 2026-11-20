import Foundation

/// A profile's accent color (design-system/one-accent-color-per-profile):
/// progress, the now line, badges, links and the tint of system controls
/// draw in it while the profile is current. Blue is the default.
public enum ProfileAccent: String, CaseIterable, Sendable, Hashable, Identifiable {
    case blue, teal, amber, pink, violet

    public var id: String { rawValue }

    /// The color as RGB hex.
    public var rgb: UInt32 {
        switch self {
        case .blue: 0x5BB8FF
        case .teal: 0x4FD1C5
        case .amber: 0xFFB454
        case .pink: 0xF472B6
        case .violet: 0xC084FC
        }
    }

    /// The accent a stored value names; Blue for nil or a value this build
    /// does not know (profiles/profiles-sync-between-devices).
    public init(stored: String?) {
        self = stored.flatMap(ProfileAccent.init(rawValue:)) ?? .blue
    }

    /// The dark surfaces an accent must reach 4.5:1 against: the ground, a
    /// row at 6% white, the tab bar and the lightest dark system material,
    /// which stands in for glass.
    public static let surfaces: [UInt32] = [0x0B0E13, 0x1A1C21, 0x11151C, 0x2C2C2E]

    /// The color of text and glyphs on an accent fill, such as a prominent
    /// button's label or a NOW badge: the dark ground. White on the five
    /// accents is 1.76 to 2.65:1; this is 7.30:1 or more.
    public static let label: UInt32 = 0x0B0E13
}

/// WCAG 2.x contrast between two RGB hex colors.
public enum Contrast {
    /// The ratio from 1 to 21, the same whichever color is passed first.
    public static func ratio(_ first: UInt32, _ second: UInt32) -> Double {
        let (lighter, darker) = (max(luminance(first), luminance(second)), min(luminance(first), luminance(second)))
        return (lighter + 0.05) / (darker + 0.05)
    }

    /// Relative luminance from 0 for black to 1 for white.
    public static func luminance(_ rgb: UInt32) -> Double {
        func channel(_ shift: UInt32) -> Double {
            let value = Double((rgb >> shift) & 0xFF) / 255
            return value <= 0.039_28 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0)
    }
}
