#if os(iOS) || os(macOS)
    import SwiftUI

    /// The Mac's mute button and volume slider in the player controls
    /// (`iPad-Player`; player-controls-and-playback-errors/extra-buttons-on-iphone-ipad-and-mac).
    enum PlayerVolumeControls {
        /// The speaker, crossed out while muted.
        struct MuteButton: View {
            let isMuted: Bool
            let level: Float
            let toggle: () -> Void

            var body: some View {
                Button(action: toggle) {
                    Image(systemName: symbol)
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Palette.text)
                .accessibilityLabel(isMuted ? "Unmute" : "Mute")
                .accessibilityIdentifier("player.mute")
            }

            private var symbol: String {
                if isMuted || level == 0 { return "speaker.slash.fill" }
                return level < 0.5 ? "speaker.wave.1.fill" : "speaker.wave.2.fill"
            }
        }

        /// A 100 pt slider from silent to full.
        struct Slider: View {
            let level: Float
            let set: (Float) -> Void

            var body: some View {
                SwiftUI.Slider(value: Binding(get: { Double(level) }, set: { set(Float($0)) }), in: 0...1)
                    .frame(width: 100)
                    .tint(Palette.text)
                    .accessibilityLabel("Volume")
                    .accessibilityValue("\(Int((level * 100).rounded())) percent")
                    .accessibilityIdentifier("player.volume")
            }
        }
    }

    extension PlayerStatus {
        /// "Playing on AirPlay" or "Playing in Picture in Picture" in place of
        /// the picture, while it shows somewhere else.
        struct Elsewhere: View {
            let text: String
            let systemImage: String

            var body: some View {
                VStack(spacing: 8) {
                    Image(systemName: systemImage)
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(Palette.textMuted)
                        .accessibilityHidden(true)
                    Text(text)
                        .font(.subheadline)
                        .foregroundStyle(Palette.textMuted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Palette.ground)
                .allowsHitTesting(false)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("player.elsewhere")
            }
        }
    }

    #Preview("Volume, Mac", traits: .fixedLayout(width: 200, height: 60)) {
        HStack(spacing: 4) {
            PlayerVolumeControls.MuteButton(isMuted: false, level: 0.7) {}
            PlayerVolumeControls.Slider(level: 0.7) { _ in }
        }
        .padding(.horizontal, 8)
        .background(Palette.ground)
    }

    #Preview("Volume, muted", traits: .fixedLayout(width: 200, height: 60)) {
        HStack(spacing: 4) {
            PlayerVolumeControls.MuteButton(isMuted: true, level: 0.7) {}
            PlayerVolumeControls.Slider(level: 0.7) { _ in }
        }
        .padding(.horizontal, 8)
        .background(Palette.ground)
    }

    #Preview("Playing on AirPlay", traits: .fixedLayout(width: 390, height: 219)) {
        PlayerStatus.Elsewhere(text: "Playing on AirPlay", systemImage: "airplayvideo")
    }
#endif
