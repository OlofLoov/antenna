import AntennaCore
import SwiftUI

/// A channel number in the reader's digits, never grouped: "1001", or
/// "١٠٠١" in Arabic (localization/numbers-use-the-region-s-digits-and-separators).
/// Empty for a channel without a number.
struct ChannelNumberText: View {
    let number: ChannelNumber?
    @Environment(\.locale) private var locale

    init(_ number: ChannelNumber?) {
        self.number = number
    }

    var body: some View {
        Text(number?.text(locale) ?? "")
    }
}

#Preview("Channel numbers") {
    VStack(spacing: 8) {
        ChannelNumberText(1001)
        ChannelNumberText(ChannelNumber(major: 6, minor: 1))
        ChannelNumberText(1001).environment(\.locale, Locale(identifier: "ar_SA"))
    }
    .padding()
}
