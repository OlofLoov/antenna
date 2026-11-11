#if os(iOS) || os(macOS)
    import AntennaCore
    import SwiftUI

    /// The picture area, 16:9: the playing channel with its controls, or
    /// "Select a channel" before one is picked. The same engine feeds it in
    /// every layout, so moving it never restarts the channel.
    struct LivePicture: View {
        @Environment(LiveModel.self) private var live

        var body: some View {
            Color.clear
                .aspectRatio(16 / 9, contentMode: .fit)
                .overlay {
                    if live.playing != nil {
                        PlayerSurfaceView(engine: live.engine)
                            .contentShape(Rectangle())
                            .onTapGesture { live.controlsShown ? live.hideControls() : live.showControls(after: .touch) }
                            .onContinuousHover { phase in
                                switch phase {
                                case .active: live.showControls(after: .pointerInside)
                                case .ended: live.showControls(after: .pointerLeft)
                                }
                            }
                            .accessibilityElement()
                            .accessibilityLabel("Picture")
                            .accessibilityHint("Shows the player controls")
                            .accessibilityAddTraits(.isButton)
                            .accessibilityAction { live.showControls(after: .touch) }
                            .accessibilityIdentifier("browse.player.surface")
                        PlayerWaitingLayer(player: live.player)
                        if let message = live.player.message {
                            failure(message)
                        }
                    } else {
                        Browse.NothingSelected()
                    }
                }
                .overlay(alignment: .bottom) {
                    if live.controlsShown, live.playing != nil, live.player.failure == nil {
                        controls
                            .transition(.opacity)
                    }
                }
                .clipped()
                .animation(.easeOut(duration: 0.2), value: live.controlsShown)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("browse.player")
        }

        /// The error in place of the picture with Try again. In full screen
        /// only the exit button stays, and the error names the channel.
        private func failure(_ message: FailureMessage) -> some View {
            PlayerStatus.Failure(
                channel: live.fullScreen ? live.playing.map { live.subject(for: $0).line } : nil, title: message.title,
                explanation: message.explanation
            ) {
                PlayerStatus.RetryButton { live.player.retry() }
            }
            .overlay(alignment: .topTrailing) {
                if live.fullScreen {
                    Browse.ExitFullScreenButton { live.setFullScreen(false) }
                        .padding(8)
                }
            }
        }

        private var controls: some View {
            TimelineView(.periodic(from: .now, by: LiveClock.tick)) { context in
                let progress = live.playing.map { live.nowText(for: $0, at: context.date) }?.progress
                Browse.Controls(
                    isPaused: live.isPaused, progress: progress, clock: LiveModel.time(context.date), isFullScreen: live.fullScreen,
                    playPause: {
                        live.playPause()
                        live.showControls(after: .touch)
                    },
                    toggleFullScreen: {
                        live.setFullScreen(!live.fullScreen)
                        live.showControls(after: .touch)
                    }
                ) {
                    #if os(iOS)
                        Browse.PictureInPictureButton(isAvailable: live.canPictureInPicture) {
                            live.engine.startPictureInPicture()
                        }
                    #endif
                }
            }
        }
    }
#endif
