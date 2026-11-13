import SwiftUI

/// The spacing and radius scale (design-system/one-spacing-and-radius-scale).
/// Padding and gaps take a `Spacing` step; corners take a `Corner`, drawn
/// with `Corner.shape` so the radius matches the platform.
enum Metrics {
    /// The one spacing scale, the same on every platform.
    enum Spacing {
        static let xxSmall: CGFloat = 4
        static let xSmall: CGFloat = 8
        static let small: CGFloat = 12
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let xLarge: CGFloat = 32
        static let xxLarge: CGFloat = 48
        static let xxxLarge: CGFloat = 64
        static let xxxxLarge: CGFloat = 80

        /// Every step, smallest first.
        static let scale: [CGFloat] = [xxSmall, xSmall, small, medium, large, xLarge, xxLarge, xxxLarge, xxxxLarge]
    }

    /// The four corners. Small is for badges and logo tiles, medium for
    /// fields and small cards, large for cards, grouped sections and panels,
    /// capsule for buttons, chips and the tab bar.
    enum Corner: CaseIterable, Sendable {
        case small, medium, large, capsule

        /// The corner as a shape, with the radius from `radii`.
        func shape(_ radii: Radii = Metrics.radii) -> CornerShape {
            CornerShape(corner: self, radii: radii)
        }
    }

    /// The point radius of each rounded corner on one platform.
    struct Radii: Sendable {
        let small: CGFloat
        let medium: CGFloat
        let large: CGFloat

        /// Apple TV: 8, 16 and 20.
        static let television = Radii(small: 8, medium: 16, large: 20)
        /// iPhone, iPad and Mac: 8, 12 and 26.
        static let touch = Radii(small: 8, medium: 12, large: 26)

        /// The radius for `corner`; nil for the capsule, whose radius is half its height.
        func radius(_ corner: Corner) -> CGFloat? {
            switch corner {
            case .small: small
            case .medium: medium
            case .large: large
            case .capsule: nil
            }
        }
    }

    /// The radii of the platform the app runs on.
    static var radii: Radii {
        #if os(tvOS)
            .television
        #else
            .touch
        #endif
    }

    /// The Apple TV safe area: 60 pt top and bottom, 80 pt at the sides
    /// (design-system/apple-tv-content-stays-in-the-safe-area).
    static let televisionSafeArea = EdgeInsets(top: 60, leading: 80, bottom: 60, trailing: 80)

    /// A rounded rectangle with the scale's radius, or a capsule.
    struct CornerShape: Shape {
        let corner: Corner
        let radii: Radii

        func path(in rect: CGRect) -> Path {
            guard let radius = radii.radius(corner) else { return Capsule(style: .continuous).path(in: rect) }
            return RoundedRectangle(cornerRadius: radius, style: .continuous).path(in: rect)
        }
    }
}

private struct ScaleSample: View {
    let radii: Metrics.Radii
    let unit: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.Spacing.large) {
            HStack(alignment: .bottom, spacing: Metrics.Spacing.medium) {
                ForEach(Metrics.Spacing.scale, id: \.self) { step in
                    VStack(spacing: Metrics.Spacing.xSmall) {
                        Palette.accent.frame(width: step, height: step)
                        Text("\(Int(step))").foregroundStyle(Palette.textMuted)
                    }
                }
            }
            HStack(spacing: Metrics.Spacing.large) {
                ForEach(Metrics.Corner.allCases, id: \.self) { corner in
                    VStack(spacing: Metrics.Spacing.xSmall) {
                        corner.shape(radii)
                            .fill(Palette.surface(0.12))
                            .frame(width: unit * 2, height: unit)
                        Text(String(describing: corner)).foregroundStyle(Palette.textMuted)
                    }
                }
            }
        }
        .padding(Metrics.Spacing.xLarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.ground)
    }
}

#Preview("Spacing and radii, Apple TV", traits: .fixedLayout(width: 1920, height: 1080)) {
    ScaleSample(radii: .television, unit: 120)
        .font(.title3)
        .padding(Metrics.televisionSafeArea)
        .background(Palette.ground)
}

#Preview("Spacing and radii, iPhone") {
    ScaleSample(radii: .touch, unit: 60)
        .font(.caption)
}
