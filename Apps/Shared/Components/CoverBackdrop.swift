import SwiftUI

/// The backdrop of a full-screen cover on Apple TV, where the cover's own
/// content paints nothing: the thickest material blurs the screen behind
/// and the ground tint dims it, so none of its text can be read through
/// the cover (design-system/pages-cover-what-is-behind-them). Use it as the
/// cover's `presentationBackground`.
struct CoverBackdrop: View {
    var body: some View {
        Rectangle()
            .fill(.ultraThickMaterial)
            .overlay(Palette.ground.opacity(0.55))
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}

#Preview("Cover backdrop over text", traits: .fixedLayout(width: 1920, height: 1080)) {
    ZStack {
        VStack(alignment: .leading, spacing: Metrics.Spacing.large) {
            ForEach(0..<8) { index in
                Text("Sources & Settings, row \(index + 1)").font(.title3)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(Metrics.televisionSafeArea)
        CoverBackdrop()
        Text("What kind of source?").font(.title2.weight(.semibold))
    }
    .background(Palette.ground)
}
