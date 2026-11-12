import SwiftUI

/// The pieces that show where live TV is in the local buffer
/// (timeshift-catch-up-and-start-over capability; `TV-ZapBar-Timeshift`,
/// `iPhone-Player-Timeshift`). They take values and closures only.
enum Timeshift {
    /// The track from the start of the buffer to now: played up to the
    /// marker in the accent, buffered after it, gaps cut out, and the knob.
    struct Track: View {
        /// Where the marker is, 0 to 1.
        let marker: Double
        var gaps: [ClosedRange<Double>] = []
        var height: CGFloat = 8
        var knob: CGFloat = 18
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            GeometryReader { proxy in
                let width = proxy.size.width
                let at = width * min(1, max(0, marker))
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.surface(0.16))
                    Capsule().fill(Palette.buffered)
                        .padding(.leading, at)
                        .accessibilityIdentifier("timeshift.buffered")
                    Capsule().fill(Palette.accent)
                        .frame(width: at)
                        .accessibilityIdentifier("timeshift.played")
                    ForEach(Array(gaps.enumerated()), id: \.offset) { _, gap in
                        Rectangle().fill(Palette.ground)
                            .frame(width: max(2, width * (gap.upperBound - gap.lowerBound)))
                            .offset(x: width * gap.lowerBound)
                    }
                    Circle().fill(Palette.accent)
                        .overlay(Circle().strokeBorder(Palette.ground, lineWidth: 2))
                        .frame(width: knob, height: knob)
                        .offset(x: at - knob / 2)
                        .accessibilityIdentifier("timeshift.knob")
                }
                .frame(height: height)
                .frame(maxHeight: .infinity)
                .animation(reduceMotion ? nil : .linear(duration: 0.25), value: marker)
            }
            .frame(height: knob)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("timeshift.track")
        }
    }

    /// The Apple TV rewind row under the programme: paused or playing,
    /// the time on screen, the track and how far behind live. Never focusable.
    struct Row: View {
        let isPaused: Bool
        let time: String
        let marker: Double
        var gaps: [ClosedRange<Double>] = []
        let behind: String?

        var body: some View {
            HStack(spacing: 18) {
                Image(systemName: isPaused ? "pause.fill" : "play.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Palette.textMuted)
                    .accessibilityLabel(isPaused ? "Paused" : "Playing")
                    .accessibilityIdentifier("timeshift.stateGlyph")
                    .accessibilityValue(isPaused ? "paused" : "playing")
                Text(time)
                    .font(.system(size: 22).monospacedDigit())
                    .accessibilityIdentifier("timeshift.positionTime")
                Track(marker: marker, gaps: gaps)
                    .accessibilityIdentifier("timeshift.scrubber")
                if let behind {
                    Text(behind)
                        .font(.system(size: 22))
                        .foregroundStyle(Palette.textMuted)
                        .lineLimit(1)
                        .accessibilityIdentifier("timeshift.behindLive")
                }
            }
            .frame(height: 24)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("timeshift.row")
        }
    }

    /// A line over the picture for a few seconds, read aloud by VoiceOver
    /// (timeshift-catch-up-and-start-over/when-the-stream-cannot-be-recorded).
    struct Notice: View {
        let text: String
        var size: CGFloat = 15

        var body: some View {
            Text(text)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(Palette.text)
                .padding(.horizontal, size)
                .padding(.vertical, size * 0.55)
                .background(Palette.scrimTint.opacity(0.88), in: Capsule())
                .accessibilityIdentifier("timeshift.notice")
                .task(id: text) {
                    AccessibilityNotification.Announcement(text).post()
                }
        }
    }
}

#Preview("Timeshift row, paused 12 minutes behind", traits: .fixedLayout(width: 1100, height: 60)) {
    Timeshift.Row(isPaused: true, time: "21:22", marker: 0.8, behind: "12 min behind")
        .padding()
        .background(Palette.scrimTint)
}

#Preview("Timeshift row, playing with a gap", traits: .fixedLayout(width: 1100, height: 60)) {
    Timeshift.Row(isPaused: false, time: "21:05", marker: 0.4, gaps: [0.6...0.65], behind: "29 min behind")
        .padding()
        .background(Palette.scrimTint)
}

#Preview("Timeshift notice", traits: .fixedLayout(width: 500, height: 80)) {
    Timeshift.Notice(text: "Buffer full. Playing from the earliest point")
        .padding()
        .background(Palette.ground)
}
