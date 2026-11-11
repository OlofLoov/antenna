import SwiftUI

/// What the player draws over or in place of the picture while it waits or
/// after it failed (`TV-Player-Buffering`, `TV-Player-Error` and the
/// iPhone and iPad error boards).
enum PlayerStatus {
    /// Sizes that differ between the Apple TV screen and the smaller players.
    struct Metrics: Equatable, Sendable {
        var ring: CGFloat
        var stroke: CGFloat
        var gap: CGFloat
        var caption: Font

        /// `TV-Player-Buffering`: a 64 pt ring and a 26 pt line.
        static let television = Metrics(ring: 64, stroke: 5, gap: 24, caption: .system(size: 26))
        /// The iPhone, iPad and Mac player, not drawn; the same layout at a third of the size.
        static let compact = Metrics(ring: 32, stroke: 3, gap: 10, caption: .footnote)
    }

    /// The indeterminate ring over the picture, with the slow-source line
    /// under it once there is one
    /// (player-controls-and-playback-errors/a-spinner-while-waiting-and-a-reason-if-it-is-slow).
    struct Waiting: View {
        /// The line under the ring, nil for the ring alone.
        let caption: String?
        @Environment(\.playerStatusMetrics) private var metrics

        var body: some View {
            VStack(spacing: metrics.gap) {
                Ring(size: metrics.ring, stroke: metrics.stroke)
                if let caption {
                    Caption(text: caption)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("player.buffering")
            .task { AccessibilityNotification.Announcement("Buffering").post() }
        }
    }

    /// "Reconnecting… attempt 2 of 3" where the ring was, in the caption's
    /// place and style (player-controls-and-playback-errors/a-dropped-stream-shows-that-it-is-reconnecting).
    struct Reconnecting: View {
        let caption: String

        var body: some View {
            Caption(text: caption)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
                .accessibilityIdentifier("player.reconnecting")
        }
    }

    /// The muted line under the ring.
    struct Caption: View {
        let text: String
        @Environment(\.playerStatusMetrics) private var metrics

        var body: some View {
            Text(text)
                .font(metrics.caption)
                .foregroundStyle(Palette.textMuted)
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(0.6), radius: 4)
                .padding(.horizontal, 16)
                .accessibilityIdentifier("player.buffering.caption")
        }
    }

    /// A quarter arc turning on a faint full circle.
    struct Ring: View {
        let size: CGFloat
        let stroke: CGFloat
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @State private var spinning = false

        var body: some View {
            ZStack {
                Circle().stroke(Palette.surface(0.18), lineWidth: stroke)
                Circle()
                    .trim(from: 0, to: 0.25)
                    .stroke(Palette.text, style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                    .rotationEffect(.degrees(spinning ? 360 : 0))
                    .animation(reduceMotion ? nil : .linear(duration: 1).repeatForever(autoreverses: false), value: spinning)
            }
            .frame(width: size, height: size)
            .accessibilityElement()
            .accessibilityLabel("Buffering")
            .task { spinning = !reduceMotion }
        }
    }
}

extension EnvironmentValues {
    /// The player status sizes; the Apple TV shell sets `.television`.
    @Entry var playerStatusMetrics = PlayerStatus.Metrics.compact
}

#Preview("Waiting, Apple TV", traits: .fixedLayout(width: 1920, height: 1080)) {
    PlayerStatus.Waiting(caption: nil)
        .background(Color(red: 0x1A / 255, green: 0x25 / 255, blue: 0x35 / 255))
        .environment(\.playerStatusMetrics, .television)
}

#Preview("Slow source, Apple TV", traits: .fixedLayout(width: 1920, height: 1080)) {
    PlayerStatus.Waiting(caption: "Still buffering. Acme TV is sending data slowly.")
        .background(Color(red: 0x1A / 255, green: 0x25 / 255, blue: 0x35 / 255))
        .environment(\.playerStatusMetrics, .television)
}

#Preview("Reconnecting, iPhone", traits: .fixedLayout(width: 390, height: 220)) {
    PlayerStatus.Reconnecting(caption: "Reconnecting… attempt 2 of 3")
        .background(Color(red: 0x1A / 255, green: 0x25 / 255, blue: 0x35 / 255))
}

#Preview("Slow source, iPhone", traits: .fixedLayout(width: 390, height: 220)) {
    PlayerStatus.Waiting(caption: "Still buffering. Acme TV is sending data slowly.")
        .background(Color(red: 0x1A / 255, green: 0x25 / 255, blue: 0x35 / 255))
}
