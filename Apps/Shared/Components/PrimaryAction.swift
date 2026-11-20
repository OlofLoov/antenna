import SwiftUI

extension View {
    /// The system style for a screen's main action, such as Connect, Add a
    /// source or Start watching (design-system/controls-use-system-styles):
    /// glass prominent in the accent tint on iPhone, iPad and Mac, and
    /// bordered on Apple TV, where it rests translucent like the buttons
    /// beside it and takes the light platter with dark text when focused
    /// (design-system/focus-is-the-lifted-white-card). Glass prominent on
    /// Apple TV rests white with white text, so it is not used there.
    @ViewBuilder func primaryActionStyle() -> some View {
        #if os(tvOS)
            buttonStyle(.bordered)
        #else
            prominentStyle(.glass)
        #endif
    }

    /// A prominent system button filled with the accent, its label in the
    /// dark ground color (design-system/text-on-the-accent-is-dark). White
    /// on the five accents is under 2.7:1. Every prominent button goes
    /// through here, and `scripts/check-rules.sh` fails on one that does not.
    @ViewBuilder func prominentStyle(_ material: ProminentMaterial) -> some View {
        switch material {
        case .glass: buttonStyle(.glassProminent).foregroundStyle(Palette.onAccent)
        case .bordered: buttonStyle(.borderedProminent).foregroundStyle(Palette.onAccent)
        }
    }
}

/// What a prominent button is drawn in: glass over art and beside glass
/// buttons, a plain fill on the page.
enum ProminentMaterial: Sendable {
    case glass, bordered
}
