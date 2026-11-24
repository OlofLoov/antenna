import AntennaCore
import SwiftUI

/// An app icon as Settings shows it (`iPhone-Settings-AppIcon`): the still
/// Antuna a in the icon's colors on its ground, with the glow on the
/// standard icon, drawn here rather than loaded, so no extra images ship.
/// `side` is the side of the tile.
struct AppIconTile: View {
    let icon: AppIconChoice
    let side: CGFloat

    var body: some View {
        // The artwork places the a at (120, 134) of a 240 tile, 1.05 times
        // its size; the letter box is 200 wide and centered on (675, -92).
        BrandMark.Letter(moment: .still, ink: .init(letters: Color(hex: icon.ink), tips: Color(hex: icon.tip)), clock: .frozen(0))
            .frame(width: side * 200 * 1.05 / 240)
            .offset(y: side * (134 - 120 - (-59 - -92) * 1.05) / 240)
            .frame(width: side, height: side)
            .background(ground, in: RoundedRectangle(cornerRadius: side * 0.225, style: .continuous))
            .accessibilityHidden(true)
    }

    private var ground: some ShapeStyle {
        RadialGradient(
            colors: [Color(hex: icon.glows ? MarkColor.glow : icon.ground), Color(hex: icon.ground)],
            center: UnitPoint(x: 0.5, y: 0.25), startRadius: 0, endRadius: side * 170 / 240)
    }
}

extension AppIconChoice {
    /// The icon's name in Settings.
    var title: LocalizedStringResource {
        switch self {
        case .standard: return "Antuna"
        case .mono: return "Mono"
        case .light: return "Light"
        case .blue: return ProfileAccent.blue.title
        case .amber: return ProfileAccent.amber.title
        case .pink: return ProfileAccent.pink.title
        case .violet: return ProfileAccent.violet.title
        }
    }
}

#Preview("App icons") {
    HStack(spacing: Metrics.Spacing.small) {
        ForEach(AppIconChoice.allCases) { icon in
            AppIconTile(icon: icon, side: 60)
        }
    }
    .padding(Metrics.Spacing.large)
    .background(Palette.ground)
}
