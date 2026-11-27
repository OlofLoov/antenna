#if DEBUG
    import AntennaCore
    import SwiftUI

    extension UITestingLive {
        /// A tiny text the UI tests read through `browse.debug.engine`, and
        /// a button, `browse.debug.switchLayout`, that flips `Layout.compact`.
        /// Draws nothing outside UI tests, or in the store screenshots
        /// (`UITestingStoreShots`).
        struct Probe: View {
            let engine: any PlaybackEngine
            /// With a player, `browse.debug.player` reads the engine's
            /// summary and what the player draws over the picture in one
            /// value, `"paused loads=1 waiting=none"`, so a test can wait for
            /// both at once instead of timing the spinner's removal.
            var player: PlayerModel?

            var body: some View {
                let shown = !UITestingStoreShots.isOn
                if shown, let engine = UITestingLive.scripted(engine) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(engine.summary)
                            .font(.system(size: 8))
                            .foregroundStyle(Palette.textMuted)
                            .accessibilityIdentifier("browse.debug.engine")
                            .accessibilityValue(engine.summary)
                            .allowsHitTesting(false)
                        if let player {
                            let summary = "\(engine.summary) waiting=\(Self.name(player.waiting))"
                            Text(summary)
                                .font(.system(size: 8))
                                .foregroundStyle(Palette.textMuted)
                                .accessibilityIdentifier("browse.debug.player")
                                .accessibilityValue(summary)
                                .allowsHitTesting(false)
                            if UITestingLive.xtreamHLS {
                                airPlayProbe(player)
                            }
                        }
                        Button("Switch layout") { Layout.shared.compact.toggle() }
                            .font(.system(size: 8))
                            .foregroundStyle(Palette.textMuted)
                            .frame(minWidth: 44, minHeight: 24)
                            .contentShape(Rectangle())
                            .accessibilityIdentifier("browse.debug.switchLayout")
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
            }

            /// `browse.debug.airPlayList` reads how often the AirPlay list
            /// opened, and `browse.debug.airPlayRoute` switches the scripted
            /// sound route between the device and an AirPlay device.
            @ViewBuilder private func airPlayProbe(_ player: PlayerModel) -> some View {
                Text("list=\(player.airPlayListOpenings)")
                    .font(.system(size: 8))
                    .foregroundStyle(Palette.textMuted)
                    .accessibilityIdentifier("browse.debug.airPlayList")
                    .accessibilityValue("\(player.airPlayListOpenings)")
                    .allowsHitTesting(false)
                Button("Switch AirPlay") { UITestingLive.airPlayRoute.send(!UITestingLive.airPlayRoute.value) }
                    .font(.system(size: 8))
                    .foregroundStyle(Palette.textMuted)
                    .frame(minWidth: 44, minHeight: 24)
                    .contentShape(Rectangle())
                    .accessibilityIdentifier("browse.debug.airPlayRoute")
            }

            static func name(_ waiting: PlayerWaiting?) -> String {
                switch waiting {
                case nil: "none"
                case .spinner: "spinner"
                case .slow: "slow"
                case .reconnecting: "reconnecting"
                }
            }
        }
    }
#endif
