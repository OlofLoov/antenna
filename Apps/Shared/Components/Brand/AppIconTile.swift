import AntennaCore
import SwiftUI

/// An app icon as Settings shows it (`iPhone-Settings-AppIcon`): the mark
/// in the icon's color on its ground, drawn here rather than loaded, so
/// no extra images ship. `side` is the side of the tile.
struct AppIconTile: View {
    let icon: AppIconChoice
    let side: CGFloat

    var body: some View {
        Glyph()
            .fill(Color(hex: icon.mark))
            .padding(side * 0.12)
            .frame(width: side, height: side)
            .background(Color(hex: icon.ground), in: RoundedRectangle(cornerRadius: side * 0.225, style: .continuous))
            .accessibilityHidden(true)
    }

    /// The icon's mast and waves, from its 1024-point artwork, cropped to
    /// the 640-point square around them.
    struct Glyph: Shape {
        func path(in rect: CGRect) -> Path {
            let scale = min(rect.width, rect.height) / 640
            let origin = CGPoint(x: rect.midX - 320 * scale, y: rect.midY - 320 * scale)
            func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: origin.x + (x - 192) * scale, y: origin.y + (y - 194) * scale)
            }
            var path = Path()
            let tip = point(512, 410)
            path.addEllipse(in: CGRect(x: tip.x - 56 * scale, y: tip.y - 56 * scale, width: 112 * scale, height: 112 * scale))
            var mast = Path()
            mast.move(to: point(512, 486))
            mast.addLine(to: point(512, 790))
            path.addPath(mast.strokedPath(StrokeStyle(lineWidth: 64 * scale, lineCap: .round)))
            var waves = Path()
            for radius in [150.0, 270.0] {
                for side in [180.0, 0.0] {
                    for step in 0...24 {
                        let degrees = side - 40 + 80 * Double(step) / 24
                        let angle = degrees * .pi / 180
                        let next = point(512 + radius * cos(angle), 410 + radius * sin(angle))
                        if step == 0 { waves.move(to: next) } else { waves.addLine(to: next) }
                    }
                }
            }
            path.addPath(waves.strokedPath(StrokeStyle(lineWidth: 60 * scale, lineCap: .round, lineJoin: .round)))
            return path
        }
    }
}

extension AppIconChoice {
    /// The icon's name in Settings.
    var title: LocalizedStringResource {
        switch self {
        case .standard: return "Antuna"
        case .mono: return "Mono"
        case .light: return "Light"
        case .teal: return ProfileAccent.teal.title
        case .amber: return ProfileAccent.amber.title
        case .pink: return ProfileAccent.pink.title
        case .violet: return ProfileAccent.violet.title
        }
    }
}

#Preview("App icons") {
    HStack(spacing: Metrics.Spacing.small) {
        ForEach(AppIconChoice.allCases) { icon in
            AppIconTile(icon: icon, side: 44)
        }
    }
    .padding(Metrics.Spacing.large)
    .background(Palette.ground)
}
