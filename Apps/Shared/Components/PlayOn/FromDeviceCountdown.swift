import SwiftUI

/// The Apple TV's countdown for a request it did not start at once
/// (`TV-FromIPhone-Countdown`, play-on-apple-tv/the-tv-counts-down-a-waiting-request):
/// the sending device as the eyebrow, the item, the time left, and the
/// buttons the screen passes, Cancel first. In the reminder banner's panel
/// at the top trailing corner. Takes values and closures only.
struct FromDeviceCountdown<Buttons: View>: View {
    let eyebrow: String
    let title: String
    /// "Starts in 5".
    let time: String
    @ViewBuilder var buttons: Buttons

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(eyebrow, systemImage: "iphone")
                .font(.boardStyle(18, weight: .semibold))
                .letterSpacing(1.5)
                .textCase(.uppercase)
                .foregroundStyle(Palette.textMuted)
                .accessibilityIdentifier("playOn.countdown.sender")
            Text(title)
                .font(.boardStyle(29, weight: .semibold))
                .lineLimit(1)
                .accessibilityIdentifier("playOn.countdown.title")
            Text(time)
                .font(.boardStyle(22))
                .monospacedDigit()
                .foregroundStyle(ChannelOverlay.tileText)
                .accessibilityIdentifier("playOn.countdown.time")
            HStack(spacing: 14) { buttons }
                .padding(.top, 4)
        }
        .padding(EdgeInsets(top: 24, leading: 28, bottom: 24, trailing: 28))
        .frame(width: 640, alignment: .leading)
        .foregroundStyle(Palette.text)
        .background(Palette.scrimTint.opacity(0.88), in: cornerShape(.medium))
        .shadow(color: Palette.focusShadow, radius: 16, y: 12)
        // VoiceOver reads the sending device and the item, then the focused button.
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(verbatim: "\(eyebrow), \(title)"))
        .accessibilityIdentifier("playOn.countdown")
    }
}

#Preview("From iPhone countdown", traits: .fixedLayout(width: 800, height: 360)) {
    FromDeviceCountdown(eyebrow: "From Anna's iPhone", title: "Salt Road", time: "Starts in 5") {
        ReminderBanner.TelevisionButton(title: "Cancel") {}
        ReminderBanner.TelevisionButton(title: "Play now") {}
    }
    .padding(40)
    .background(Palette.ground)
}
