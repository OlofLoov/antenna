import AntennaCore
import SwiftUI

/// The a tuning on the ground while the first App Store answer is awaited
/// on a device that remembers nothing, at most 750 ms
/// (paywall-and-entitlement/the-splash-tunes-in, `Brand-Mark` board).
struct LaunchSplash: View {
    var body: some View {
        BrandMark.Letter(moment: MarkPlacement.splash.moment)
            .frame(width: 120)
            .accessibilityIdentifier("paywall.splashMark")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.ground)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("paywall.splash")
    }
}

#Preview("Launch splash") {
    LaunchSplash()
}
