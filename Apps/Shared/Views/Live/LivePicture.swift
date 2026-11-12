#if os(iOS) || os(macOS)
    import AntennaCore
    import SwiftUI

    /// The picture area, 16:9: the playing channel with its controls, or
    /// "Select a channel" before one is picked. The same engine feeds it in
    /// every layout, so moving it never restarts the channel.
    struct LivePicture: View {
        @Environment(LiveModel.self) private var live
        #if os(iOS)
            @Environment(\.horizontalSizeClass) private var sizeClass
        #endif

        var body: some View {
            Color.clear
                .aspectRatio(16 / 9, contentMode: .fit)
                .overlay {
                    if live.playing != nil {
                        PlayerSurfaceView(engine: live.engine)
                            .overlay { PlayerSubtitles(engine: live.engine, raised: live.controlsShown ? 52 : 0) }
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
                        if live.player.airPlayActive {
                            PlayerStatus.Elsewhere(text: "Playing on AirPlay", systemImage: "airplayvideo")
                        } else if live.player.pictureInPictureActive {
                            PlayerStatus.Elsewhere(text: "Playing in Picture in Picture", systemImage: "pip")
                        }
                        PlayerWaitingLayer(player: live.player)
                        if let notice = live.player.timeshift.notice {
                            Timeshift.Notice(text: notice)
                                .frame(maxHeight: .infinity, alignment: .top)
                                .padding(.top, 12)
                        }
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
                .background { keys }
                .background { LiveSkipKeys(live: live) }
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

        /// The audio-and-subtitles button with its list: a sheet at compact
        /// width, a popover above the button otherwise
        /// (player-controls-and-playback-errors/choose-audio-and-subtitles).
        private var tracksButton: some View {
            @Bindable var player = live.player
            return TrackPicker.OpenButton(isAvailable: player.hasTrackChoices) { player.openPicker() }
                .popover(isPresented: $player.pickerOpen, arrowEdge: .bottom) {
                    if isCompact {
                        TrackPicker.Sheet(lists: trackLists) { player.closePicker() }
                            .presentationDetents([.medium, .large])
                            .presentationDragIndicator(.visible)
                    } else {
                        TrackPicker.Popover(lists: trackLists)
                            .presentationCompactAdaptation(.popover)
                    }
                }
        }

        /// True at compact width on iPhone and iPad, never on a Mac.
        private var isCompact: Bool {
            #if os(iOS)
                sizeClass == .compact
            #else
                false
            #endif
        }

        private var trackLists: TrackPicker.Lists {
            let player = live.player
            return TrackPicker.Lists(
                audio: player.audioRows, subtitles: player.subtitleRows,
                footer: [player.streamLine] + (player.route == .demuxer ? [Self.noAirPlay] : []),
                pickAudio: { player.selectAudio($0) }, pickSubtitle: { player.selectSubtitle($0) })
        }

        /// Antenna reads this stream itself, so it cannot go to AirPlay.
        static let noAirPlay = "AirPlay not available for this stream"

        /// The Mac's M, Command-Up and Command-Down, off while the filter
        /// field takes typing (player-controls-and-playback-errors/extra-buttons-on-iphone-ipad-and-mac).
        @ViewBuilder private var keys: some View {
            #if os(macOS)
                if live.playing != nil {
                    ZStack {
                        Button("Mute") { live.player.toggleMute() }
                            .keyboardShortcut("m", modifiers: [])
                            .disabled(live.typing)
                        Button("Volume up") { live.player.stepVolume(up: true) }
                            .keyboardShortcut(.upArrow, modifiers: .command)
                        Button("Volume down") { live.player.stepVolume(up: false) }
                            .keyboardShortcut(.downArrow, modifiers: .command)
                    }
                    .frame(width: 0, height: 0)
                    .opacity(0)
                    .accessibilityHidden(true)
                }
            #endif
        }

        @ViewBuilder private var controls: some View {
            if live.player.timeshift.canRewind {
                LiveTimeshiftStrip(extras: { extras })
            } else {
                strip
            }
        }

        private var strip: some View {
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
                    extras
                }
            }
        }

        /// The buttons each platform adds to the strip.
        @ViewBuilder private var extras: some View {
            tracksButton
            // The subtitles switch shows where AirPlay can: full screen, regular width and Mac.
            if live.fullScreen || !isCompact {
                TrackPicker.SubtitlesButton(isOn: live.player.subtitlesOn, isAvailable: live.player.canSwitchSubtitles) {
                    live.player.switchSubtitles()
                    live.showControls(after: .touch)
                }
            }
            // AirPlay at compact width is reached from full screen or Control Center.
            if live.player.route == .system, live.fullScreen || !isCompact {
                AirPlayPicker()
            }
            #if os(macOS)
                PlayerVolumeControls.MuteButton(isMuted: live.player.muted, level: live.player.volume) {
                    live.player.toggleMute()
                }
                PlayerVolumeControls.Slider(level: live.player.muted ? 0 : live.player.volume) { live.player.setVolume($0) }
            #endif
            #if os(iOS)
                Browse.PictureInPictureButton(isAvailable: live.canPictureInPicture) {
                    live.engine.startPictureInPicture()
                }
            #endif
        }
    }
#endif
