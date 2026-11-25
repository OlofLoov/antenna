import SwiftUI

/// The ground color laid over art behind copy, on the Movies and Series
/// banner, the Apple TV preview and the title pages
/// (design-system/the-scrim-blends-into-the-art). It covers the whole
/// picture: darkest at the leading edge, still dark where the copy ends,
/// clear at the trailing edge, with no edge in between. It mirrors in a
/// right-to-left language, so the dark side stays under the copy.
struct HeroScrim: View {
    /// Where the copy ends, as a share of the width from the leading edge.
    let copyEnd: Double

    var body: some View {
        LinearGradient(stops: Self.stops(copyEnd: copyEnd), startPoint: .leading, endPoint: .trailing)
            .flipsForRightToLeftLayoutDirection(true)
            .accessibilityHidden(true)
    }

    /// 0.85 at the leading edge, 0.72 where the copy ends, 0.3 halfway from
    /// there to the trailing edge, and clear at it.
    static func stops(copyEnd: Double) -> [Gradient.Stop] {
        [
            .init(color: Palette.ground.opacity(0.85), location: 0),
            .init(color: Palette.ground.opacity(0.72), location: copyEnd),
            .init(color: Palette.ground.opacity(0.3), location: (copyEnd + 1) / 2),
            .init(color: Palette.ground.opacity(0), location: 1),
        ]
    }
}

/// The band under the copy at the foot of the iPhone banner: clear to 0.78
/// over the `fade` above the copy, then 0.78 to 0.86 behind it, so the band
/// blends into the art above (design-system/the-scrim-blends-into-the-art).
/// Use it as the copy's background; the fade reaches above the copy.
struct HeroFootScrim: View {
    let fade: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [Palette.ground.opacity(0), Palette.ground.opacity(0.78)], startPoint: .top, endPoint: .bottom)
                .frame(height: fade)
            LinearGradient(colors: [Palette.ground.opacity(0.78), Palette.ground.opacity(0.86)], startPoint: .top, endPoint: .bottom)
        }
        .padding(.top, -fade)
        .accessibilityHidden(true)
    }
}

/// The band behind the section's name and the genre button at the top of
/// the iPhone banner: 0.86 at the top edge to 0.8 at the foot of the
/// content, then clear over the `fade` below it, so the name, the count and
/// the chevron stay legible on a white picture and the band blends into the
/// art (design-system/the-scrim-blends-into-the-art). Use it as the
/// content's background; the fade reaches below the content.
struct HeroTopScrim: View {
    let fade: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [Palette.ground.opacity(0.86), Palette.ground.opacity(0.8)], startPoint: .top, endPoint: .bottom)
            LinearGradient(colors: [Palette.ground.opacity(0.8), Palette.ground.opacity(0)], startPoint: .top, endPoint: .bottom)
                .frame(height: fade)
        }
        .padding(.bottom, -fade)
        .accessibilityHidden(true)
    }
}

#Preview("Hero scrim over art", traits: .fixedLayout(width: 1920, height: 640)) {
    ZStack(alignment: .topLeading) {
        LinearGradient(colors: [.orange, .teal], startPoint: .topLeading, endPoint: .bottomTrailing)
        HeroScrim(copyEnd: 0.5)
        Text(verbatim: "The Long Harbor")
            .font(.boardStyle(76, weight: .bold))
            .foregroundStyle(Palette.text)
            .padding(.leading, Metrics.televisionSafeArea.leading)
            .padding(.top, 180)
    }
}

#Preview("Hero scrim over art, Arabic", traits: .fixedLayout(width: 1920, height: 640)) {
    ZStack(alignment: .topLeading) {
        LinearGradient(colors: [.orange, .teal], startPoint: .topLeading, endPoint: .bottomTrailing)
        HeroScrim(copyEnd: 0.5)
        Text(verbatim: "الميناء الطويل")
            .font(.boardStyle(76, weight: .bold))
            .foregroundStyle(Palette.text)
            .padding(.leading, Metrics.televisionSafeArea.leading)
            .padding(.top, 180)
    }
    .environment(\.layoutDirection, .rightToLeft)
    .environment(\.locale, Locale(identifier: "ar"))
}

#Preview("Hero foot scrim over art", traits: .fixedLayout(width: 390, height: 520)) {
    ZStack(alignment: .bottom) {
        LinearGradient(colors: [.orange, .teal], startPoint: .top, endPoint: .bottom)
        Text(verbatim: "The Long Harbor")
            .font(.boardStyle(28, weight: .bold))
            .foregroundStyle(Palette.text)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HeroFootScrim(fade: 56))
    }
}

#Preview("Hero top scrim over white", traits: .fixedLayout(width: 390, height: 320)) {
    ZStack(alignment: .top) {
        Color.white
        Text(verbatim: "Series")
            .font(.title.bold())
            .foregroundStyle(Palette.text)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HeroTopScrim(fade: 56))
    }
}
