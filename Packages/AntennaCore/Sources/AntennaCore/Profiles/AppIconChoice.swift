import Foundation

/// The app icons a device can show (sources-and-settings/pick-the-app-icon-on-this-device,
/// app-release/alternate-icons-keep-the-mark): the standard icon and six
/// alternates, each the mark in one color on a plain ground.
public enum AppIconChoice: String, CaseIterable, Sendable, Hashable, Identifiable {
    case standard, mono, light, teal, amber, pink, violet

    public var id: String { rawValue }

    /// The name the system knows the icon by, as `setAlternateIconName`
    /// takes it; nil for the standard icon.
    public var alternateName: String? {
        self == .standard ? nil : "AppIcon-\(rawValue.prefix(1).uppercased())\(rawValue.dropFirst())"
    }

    /// The icon the system reports, from its alternate name; the standard
    /// icon for nil or a name this build does not ship.
    public init(alternateName: String?) {
        self = Self.allCases.first { $0.alternateName == alternateName && alternateName != nil } ?? .standard
    }

    /// The mark's color as RGB hex.
    public var mark: UInt32 {
        switch self {
        case .standard: ProfileAccent.blue.rgb
        case .mono: 0xF2F4F8
        case .light: 0x0B0E13
        case .teal: ProfileAccent.teal.rgb
        case .amber: ProfileAccent.amber.rgb
        case .pink: ProfileAccent.pink.rgb
        case .violet: ProfileAccent.violet.rgb
        }
    }

    /// The ground's color as RGB hex.
    public var ground: UInt32 { self == .light ? 0xF2F4F8 : 0x0B0E13 }
}
