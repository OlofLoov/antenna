import SwiftUI

/// The system styles the app's buttons take (design-system/controls-use-system-styles).
/// `primaryActionStyle()` is the screen's main action; these are the rest.
extension View {
    /// An action beside the primary one, such as More info, My list, Cancel
    /// or Try again: a capsule in the primary's family, so a row of actions
    /// shares one edge. Glass on iPhone, iPad and Mac beside the glass
    /// prominent primary; bordered on Apple TV, where it rests translucent
    /// and takes the light platter with dark text when focused.
    @ViewBuilder func secondaryActionStyle() -> some View {
        #if os(tvOS)
            buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
        #else
            buttonStyle(.glass)
                .buttonBorderShape(.capsule)
        #endif
    }

    /// A poster or card that is a button. On Apple TV the card style lifts
    /// it, grows it and tilts it with the remote, with no ring of its own;
    /// elsewhere it is borderless and dims while pressed.
    @ViewBuilder func posterButtonStyle() -> some View {
        #if os(tvOS)
            buttonStyle(.card)
        #else
            buttonStyle(.borderless)
        #endif
    }

    /// A chip in a row of choices, such as a season or a genre. On iPhone,
    /// iPad and Mac the picked chip is prominent in the accent tint, on
    /// glass when `floating` over art (design-system/liquid-glass-stays-on-the-navigation-layer).
    /// On Apple TV every chip is bordered, so nothing but the focused chip is
    /// white, and the picked one reads semibold; one style for both keeps
    /// focus on a chip when picking it changes it.
    @ViewBuilder func chipStyle(isPicked: Bool, on surface: ChipSurface = .content) -> some View {
        #if os(tvOS)
            buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
        #else
            switch (surface, isPicked) {
            case (.content, true): buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
            case (.content, false): buttonStyle(.bordered).buttonBorderShape(.capsule)
            case (.art, true): buttonStyle(.glassProminent).buttonBorderShape(.capsule)
            case (.art, false): buttonStyle(.glass).buttonBorderShape(.capsule)
            }
        #endif
    }
}

/// What a chip sits on: the page, or art it floats over.
enum ChipSurface: Sendable {
    case content, art
}

#Preview("Chips and actions") {
    VStack(spacing: Metrics.Spacing.medium) {
        HStack {
            Button("Season 1") {}.chipStyle(isPicked: true)
            Button("Season 2") {}.chipStyle(isPicked: false)
        }
        HStack {
            Button("All") {}.chipStyle(isPicked: true, on: .art)
            Button("Drama") {}.chipStyle(isPicked: false, on: .art)
        }
        HStack {
            Button("Play") {}.primaryActionStyle()
            Button("More info") {}.secondaryActionStyle()
        }
    }
    .padding(Metrics.Spacing.large)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Palette.ground)
    .tint(Palette.accent)
}
