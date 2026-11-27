import SwiftUI

/// The Apple TV's offer for a request that waited in iCloud
/// (`TV-FromIPhone-Offer`, play-on-apple-tv/the-tv-offers-a-waiting-request):
/// a 760 pt panel with the item's art, "From Anna's iPhone", the item, a
/// facts line, and the buttons the screen passes, Play first. Takes values
/// and closures only.
struct FromDeviceOffer<Art: View, Buttons: View>: View {
    let eyebrow: String
    let title: String
    let facts: String
    @ViewBuilder var art: Art
    @ViewBuilder var buttons: Buttons

    var body: some View {
        HStack(alignment: .top, spacing: 32) {
            art
                .frame(width: 160, height: 240)
                .clipShape(cornerShape(.medium))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 14) {
                Label(eyebrow, systemImage: "iphone")
                    .font(.boardStyle(22, weight: .semibold))
                    .letterSpacing(1.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.textMuted)
                    .accessibilityIdentifier("playOn.offer.sender")
                Text(title)
                    .font(.boardStyle(48, weight: .bold))
                    .lineLimit(1)
                    .accessibilityIdentifier("playOn.offer.title")
                Text(facts)
                    .font(.boardStyle(25))
                    .foregroundStyle(ChannelOverlay.tileText)
                    .lineLimit(1)
                    .accessibilityIdentifier("playOn.offer.facts")
                Spacer(minLength: 0)
                HStack(spacing: 20) { buttons }
            }
        }
        .padding(36)
        .frame(width: 760, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(Palette.text)
        .background(Palette.scrimTint.opacity(0.92), in: cornerShape(.large))
        .shadow(color: Palette.focusShadow, radius: 16, y: 12)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("playOn.offer")
    }
}

/// The offer's art when no picture loads: the item's initials on a tile
/// (design-system/channels-without-a-logo-show-initials).
struct FromDeviceOfferTile: View {
    let initials: String

    var body: some View {
        ZStack {
            Palette.surface(0.14)
            Text(initials)
                .font(.boardStyle(48, weight: .bold))
                .foregroundStyle(Palette.text)
        }
    }
}

#Preview("From iPhone offer", traits: .fixedLayout(width: 1000, height: 480)) {
    FromDeviceOffer(eyebrow: "From Anna's iPhone", title: "Salt Road", facts: "Movie · Resumes at 40 min") {
        FromDeviceOfferTile(initials: "SR")
    } buttons: {
        Button("Play", systemImage: "play.fill") {}
            .primaryActionStyle()
        Button("Not now") {}
            .secondaryActionStyle()
    }
    .padding()
    .background(Palette.ground)
}
