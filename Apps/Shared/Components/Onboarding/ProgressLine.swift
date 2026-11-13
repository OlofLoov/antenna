import SwiftUI

/// A status line with a spinning ring, or the words "In progress" when
/// Reduce Motion is on, read by VoiceOver as one element
/// (apple-tv-login-from-iphone/the-sign-in-reads-well-without-sight-or-motion).
/// Caption text on Apple TV, subheadline elsewhere.
struct ProgressLine: View {
    let text: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let inProgress = "In progress"

    #if os(tvOS)
        private let ring: CGFloat = 28
        private let font = Font.caption
    #else
        private let ring: CGFloat = 26
        private let font = Font.subheadline
    #endif

    var body: some View {
        HStack(alignment: .center, spacing: Metrics.Spacing.small) {
            if reduceMotion {
                Text(Self.inProgress)
                    .font(font.weight(.semibold))
                    .foregroundStyle(Palette.accent)
            } else {
                ProgressView()
                    .frame(width: ring, height: ring)
            }
            Text(text)
                .font(font)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Self.inProgress). \(text)")
    }
}

#Preview("Progress line") {
    ProgressLine(text: "Sending to your Apple TV…")
        .padding()
        .preferredColorScheme(.dark)
}
