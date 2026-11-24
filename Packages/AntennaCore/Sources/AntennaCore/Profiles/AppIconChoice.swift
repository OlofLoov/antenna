import Foundation

/// The app icons a device can show (sources-and-settings/pick-the-app-icon-on-this-device,
/// app-release/alternate-icons-keep-the-mark): the standard icon and six
/// alternates, each the Antuna a with its tips in one color on a plain ground.
public enum AppIconChoice: String, CaseIterable, Sendable, Hashable, Identifiable {
    case standard, mono, light, blue, amber, pink, violet

    public var id: String { rawValue }

    /// The name the system knows the icon by, as `setAlternateIconName`
    /// takes it; nil for the standard icon.
    public var alternateName: String? {
        self == .standard ? nil : "AppIcon-\(rawValue.prefix(1).uppercased())\(rawValue.dropFirst())"
    }

    /// The icon the system reports, from its alternate name; the standard
    /// icon for nil or a name this build does not ship, such as the
    /// `AppIcon-Teal` of earlier test builds.
    public init(alternateName: String?) {
        self = Self.allCases.first { $0.alternateName == alternateName && alternateName != nil } ?? .standard
    }

    /// The a's head, tail and antennae as RGB hex.
    public var ink: UInt32 { self == .light ? MarkColor.inkOnLight : MarkColor.ink }

    /// The antennae's tips as RGB hex.
    public var tip: UInt32 {
        switch self {
        case .standard: MarkColor.tip
        case .mono: MarkColor.ink
        case .light: MarkColor.tipOnLight
        case .blue: ProfileAccent.blue.rgb
        case .amber: ProfileAccent.amber.rgb
        case .pink: ProfileAccent.pink.rgb
        case .violet: ProfileAccent.violet.rgb
        }
    }

    /// The ground's color as RGB hex. The standard icon adds a glow
    /// (`MarkColor.glow`) on it.
    public var ground: UInt32 { self == .light ? 0xF2F4F8 : MarkColor.ground }

    /// Whether the ground has the standard icon's glow.
    public var glows: Bool { self == .standard }
}
