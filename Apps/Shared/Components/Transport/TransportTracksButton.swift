#if os(tvOS)
    import SwiftUI

    extension Transport {
        /// The Audio and Subtitles button at the end of the Apple TV bar's
        /// title row (`TV-Title-Player-Transport`, `TV-Title-Player-TracksButton`;
        /// player-controls-and-playback-errors/audio-and-subtitles-from-the-bar-on-apple-tv).
        /// The captions bubble, filled while full subtitles are on, on a
        /// circle that turns white and grows with focus. Grayed out when the
        /// title has one sound and no subtitles. It takes focus only while
        /// `reachable`, so the focus engine never moves to it on its own;
        /// the screen decides when a press sends focus here.
        struct TracksButton: View {
            let subtitlesOn: Bool
            let isAvailable: Bool
            let reachable: Bool
            let open: () -> Void

            var body: some View {
                Button(action: open) {
                    Image(systemName: subtitlesOn ? "captions.bubble.fill" : "captions.bubble")
                        .font(.boardStyle(30, weight: .semibold))
                }
                .buttonStyle(Circled())
                .disabled(!isAvailable || !reachable)
                .opacity(isAvailable ? 1 : 0.4)
                .accessibilityLabel("Audio and Subtitles")
                .accessibilityValue(subtitlesOn ? "Subtitles On" : "Subtitles Off")
                .accessibilityIdentifier("title.transport.tracks")
            }
        }

        /// A 66 pt circle on the 0.14 surface, white with dark text and
        /// grown while focused, the same at rest whether or not it can take
        /// focus.
        private struct Circled: ButtonStyle {
            func makeBody(configuration: Configuration) -> some View {
                Look(configuration: configuration)
            }

            private struct Look: View {
                let configuration: ButtonStyleConfiguration
                @Environment(\.isFocused) private var focused

                var body: some View {
                    configuration.label
                        .foregroundStyle(focused ? Palette.ground : Palette.text)
                        .frame(width: 66, height: 66)
                        .background(focused ? Palette.text : Palette.surface(0.14), in: Circle())
                        .scaleEffect(focused ? (configuration.isPressed ? 1.04 : 1.1) : 1)
                        .shadow(color: .black.opacity(focused ? 0.45 : 0), radius: 16, y: 12)
                        .animation(.easeOut(duration: 0.15), value: focused)
                }
            }
        }
    }
#endif
