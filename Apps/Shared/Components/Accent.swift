import AntennaCore
import SwiftUI

extension EnvironmentValues {
    /// The current profile's accent, the one token every accent use reads
    /// (design-system/one-accent-color-per-profile). `ProfileGate` sets it;
    /// outside a profile (splash, paywall, onboarding, "Who's watching?") it is Blue.
    @Entry var accent: ProfileAccent = .blue
}

extension ProfileAccent {
    var color: Color { Color(hex: rgb) }

    /// The accent's name in Settings and the profile editor.
    var title: LocalizedStringResource {
        switch self {
        case .blue: return "Blue"
        case .teal: return "Teal"
        case .amber: return "Amber"
        case .pink: return "Pink"
        case .violet: return "Violet"
        }
    }
}

extension View {
    /// Sets the profile's accent for everything inside, and on iPhone, iPad
    /// and Mac as the tint system controls and the selected tab draw with.
    /// Apple TV keeps the system tint: tinted, bordered buttons draw accent
    /// text on an accent fill and focused rows tint their titles, while the
    /// focused platter stays light either way (design-system/focus-is-the-lifted-white-card).
    func accent(_ accent: ProfileAccent) -> some View {
        environment(\.accent, accent).modifier(AccentTint(accent: accent))
    }
}

private struct AccentTint: ViewModifier {
    let accent: ProfileAccent

    func body(content: Content) -> some View {
        #if os(tvOS)
            content
        #else
            content.tint(accent.color)
        #endif
    }
}
