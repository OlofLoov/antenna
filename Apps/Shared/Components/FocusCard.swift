import SwiftUI

/// The focus look for the parts the app draws itself: guide programme
/// blocks, channel overlay rows and groups, zap bar sections, multi-view
/// tiles and passcode digits (design-system/controls-use-system-styles).
/// Focused, the content sits on a light card with dark text and the focus
/// shadow, and on Apple TV the highlight hover effect adds the lift and the
/// tilt that follows the remote (design-system/focus-is-the-lifted-white-card).
/// At rest it shows `resting` behind text in `restingText`.
///
/// Apply it to a button's label, inside the button, so it reads the
/// button's focus: `.modifier(FocusCard(.medium))` or `.focusCard(.medium)`.
struct FocusCard: ViewModifier {
    let corner: Metrics.Corner
    let resting: Color
    let restingText: Color
    let radii: Metrics.Radii
    @Environment(\.isFocused) private var isFocused

    init(_ corner: Metrics.Corner, resting: Color = .clear, restingText: Color = Palette.text, radii: Metrics.Radii = Metrics.radii) {
        self.corner = corner
        self.resting = resting
        self.restingText = restingText
        self.radii = radii
    }

    func body(content: Content) -> some View {
        content
            .modifier(Look(isFocused: isFocused, corner: corner, resting: resting, restingText: restingText, radii: radii))
            .highlightHoverOnTelevision()
    }

    /// The card for a known focus state, so a preview can draw it focused.
    struct Look: ViewModifier {
        let isFocused: Bool
        let corner: Metrics.Corner
        var resting: Color = .clear
        var restingText: Color = Palette.text
        var radii: Metrics.Radii = Metrics.radii

        func body(content: Content) -> some View {
            content
                .foregroundStyle(isFocused ? Palette.ground : restingText)
                .background(isFocused ? Palette.focus : resting, in: corner.shape(radii))
                .shadow(color: isFocused ? Palette.focusShadow : .clear, radius: 16, y: 12)
        }
    }
}

extension View {
    /// The focus card for an app-drawn part; see `FocusCard`.
    func focusCard(_ corner: Metrics.Corner, resting: Color = .clear, restingText: Color = Palette.text) -> some View {
        modifier(FocusCard(corner, resting: resting, restingText: restingText))
    }

    /// `hoverEffect(.highlight)` on Apple TV, where it lifts and tilts the
    /// focused view; nothing elsewhere.
    @ViewBuilder fileprivate func highlightHoverOnTelevision() -> some View {
        #if os(tvOS)
            hoverEffect(.highlight)
        #else
            self
        #endif
    }
}

private struct FocusCardSample: View {
    let radii: Metrics.Radii
    let padding: CGFloat

    var body: some View {
        HStack(spacing: padding) {
            ForEach([Metrics.Corner.small, .medium, .large, .capsule], id: \.self) { corner in
                VStack(spacing: padding) {
                    sample("Focused", corner: corner, focused: true)
                    sample("Resting", corner: corner, focused: false)
                }
            }
        }
    }

    private func sample(_ title: String, corner: Metrics.Corner, focused: Bool) -> some View {
        Text(title)
            .font(.headline)
            .padding(.vertical, padding)
            .padding(.horizontal, padding * 2)
            .modifier(FocusCard.Look(isFocused: focused, corner: corner, resting: Palette.surface(0.12), radii: radii))
    }
}

#Preview("Focus card, Apple TV", traits: .fixedLayout(width: 1920, height: 1080)) {
    FocusCardSample(radii: .television, padding: Metrics.Spacing.large)
        .scaleEffect(1.6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Metrics.televisionSafeArea)
        .background(Palette.ground)
}

#Preview("Focus card, iPhone") {
    FocusCardSample(radii: .touch, padding: Metrics.Spacing.xSmall)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.ground)
}
