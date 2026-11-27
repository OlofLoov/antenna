import SwiftUI

/// The Apple TV's "From Anna's iPhone" banner for a request that came over
/// the home network (`TV-FromIPhone-Banner`,
/// play-on-apple-tv/starts-at-once-on-the-same-network): the sending device
/// as the eyebrow and the item, or why it could not play, under it. It
/// takes no focus, in the reminder banner's panel at the top trailing
/// corner inside the safe area.
struct FromDeviceBanner: View {
    let eyebrow: String
    let line: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(eyebrow, systemImage: "iphone")
                .font(.boardStyle(18, weight: .semibold))
                .letterSpacing(1.5)
                .textCase(.uppercase)
                .foregroundStyle(Palette.textMuted)
            Text(line)
                .font(.boardStyle(29, weight: .semibold))
                .lineLimit(2)
        }
        .padding(EdgeInsets(top: 24, leading: 28, bottom: 24, trailing: 28))
        .frame(width: 640, alignment: .leading)
        .foregroundStyle(Palette.text)
        .background(Palette.scrimTint.opacity(0.88), in: cornerShape(.medium))
        .shadow(color: Palette.focusShadow, radius: 16, y: 12)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("playOn.banner")
    }
}

#Preview("From iPhone banner", traits: .fixedLayout(width: 800, height: 240)) {
    FromDeviceBanner(eyebrow: "From Anna's iPhone", line: "Sport One")
        .padding()
        .background(Palette.ground)
}

#Preview("From iPhone banner, no login", traits: .fixedLayout(width: 800, height: 260)) {
    FromDeviceBanner(eyebrow: "From Anna's iPhone", line: "Living Room isn't signed in to Acme TV.")
        .padding()
        .background(Palette.ground)
}
