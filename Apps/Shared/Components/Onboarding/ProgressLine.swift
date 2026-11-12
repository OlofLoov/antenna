import SwiftUI

/// A status line with a spinning ring, or the words "In progress" when
/// Reduce Motion is on, read by VoiceOver as one element
/// (apple-tv-login-from-iphone/the-sign-in-reads-well-without-sight-or-motion).
/// 28 pt ring and 22 pt text on Apple TV, 26 pt and 15 pt elsewhere.
struct ProgressLine: View {
    let text: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let inProgress = "In progress"

    #if os(tvOS)
        private let ring: CGFloat = 28
        private let size: CGFloat = 22
    #else
        private let ring: CGFloat = 26
        private let size: CGFloat = 15
    #endif

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if reduceMotion {
                Text(Self.inProgress)
                    .font(.system(size: size, weight: .semibold))
                    .foregroundStyle(Palette.accent)
            } else {
                ProgressView()
                    .frame(width: ring, height: ring)
            }
            Text(text)
                .font(.system(size: size))
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
