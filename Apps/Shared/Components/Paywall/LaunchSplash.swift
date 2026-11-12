import SwiftUI

/// The mark on the ground while the first App Store answer is awaited on a
/// device that remembers nothing, at most 750 ms. Not drawn on a board yet.
struct LaunchSplash: View {
    var body: some View {
        Image(systemName: Paywall.mark)
            .font(.system(size: 40))
            .foregroundStyle(Palette.text)
            .frame(width: 88, height: 88)
            .background(Paywall.markTile, in: RoundedRectangle(cornerRadius: 22))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.ground)
            .accessibilityElement()
            .accessibilityLabel("Antenna")
            .accessibilityIdentifier("paywall.splash")
    }
}

#Preview("Launch splash") {
    LaunchSplash()
}
