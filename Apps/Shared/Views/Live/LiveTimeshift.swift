#if os(iOS) || os(macOS)
    import AntennaCore
    import SwiftUI

    /// The two-row strip while the channel can rewind
    /// (timeshift-catch-up-and-start-over capability): the scrubber, the
    /// skips, LIVE as a button while behind, and the programme at the
    /// picture's time.
    struct LiveTimeshiftStrip<Extras: View>: View {
        @Environment(\.locale) private var locale
        @Environment(LiveModel.self) private var live
        @ViewBuilder var extras: Extras

        var body: some View {
            let timeshift = live.player.timeshift
            TimelineView(.periodic(from: .now, by: LiveClock.tick)) { context in
                let shown = timeshift.shownTime ?? context.date
                // The programme shown is the one at the picture's time
                // (timeshift-catch-up-and-start-over/pause-live-tv-and-pick-up-where-you-left-off).
                let progress = live.playing.map { live.nowText(for: $0, at: shown, locale: locale) }?.progress
                Browse.TimeshiftControls(
                    scrub: .init(
                        time: LiveModel.time(shown, locale: locale), marker: timeshift.markerFraction ?? 1, gaps: timeshift.gaps,
                        behind: timeshift.behindText, badge: timeshift.catchup == nil ? nil : "CATCH-UP"),
                    isPaused: live.isPaused, progress: progress, clock: LiveModel.time(context.date, locale: locale),
                    isFullScreen: live.fullScreen,
                    playPause: { touched { live.playPause() } },
                    skip: { forward in touched { timeshift.skip(forward: forward) } },
                    drag: { fraction in
                        live.showControls(after: .touch)
                        timeshift.drag(to: fraction)
                    },
                    endDrag: { touched { timeshift.endDrag() } },
                    goLive: { touched { timeshift.goLive() } },
                    toggleFullScreen: { touched { live.setFullScreen(!live.fullScreen) } }
                ) {
                    if timeshift.startOver.isAvailable {
                        Browse.StartOverButton { touched { timeshift.startOverNow() } }
                    }
                } extras: {
                    extras
                }
            }
        }

        /// Runs `action` and keeps the controls up after a touch.
        private func touched(_ action: () -> Void) {
            action()
            live.showControls(after: .touch)
        }
    }

    /// Left and Right skip back 15 and forward 30 seconds while the player
    /// can rewind and the filter field does not have the keyboard. On iPad
    /// and Mac columns the Playback menu has them instead.
    struct LiveSkipKeys: View {
        let live: LiveModel
        @Environment(\.publishesMenuCommands) private var inMenus

        var body: some View {
            if !inMenus, live.playing != nil, live.player.timeshift.canRewind {
                ZStack {
                    Button("Back 15 seconds") { live.player.timeshift.skip(forward: false) }
                        .keyboardShortcut(.leftArrow, modifiers: [])
                    Button("Forward 30 seconds") { live.player.timeshift.skip(forward: true) }
                        .keyboardShortcut(.rightArrow, modifiers: [])
                }
                .disabled(live.typing)
                .frame(width: 0, height: 0)
                .opacity(0)
                .accessibilityHidden(true)
            }
        }
    }

    /// Live's Playback items: pause, the timeshift skips, and on Mac mute
    /// and volume. Each single key is dimmed while the filter field has the
    /// keyboard, and so is volume, which a text field uses to move the cursor
    /// (keyboard-commands/typing-is-never-taken-by-a-shortcut,
    /// player-controls-and-playback-errors/extra-buttons-on-iphone-ipad-and-mac).
    struct LivePlaybackCommands {
        let live: LiveModel

        @MainActor var commands: PlaybackCommands {
            let playing = live.playing != nil
            let free = !live.typing
            let canSkip = playing && free && live.player.timeshift.canRewind
            let timeshift = live.player.timeshift
            let base = PlaybackCommands(
                playPause: MenuCommand(
                    title: KeyCommand.pauseTitle(paused: playing && live.isPaused), isEnabled: playing && free && live.multiView == nil
                ) { live.playPause() },
                skipBack: MenuCommand(title: KeyCommand.skipTitle(forward: false, seconds: 15), isEnabled: canSkip) {
                    timeshift.skip(forward: false)
                },
                skipForward: MenuCommand(title: KeyCommand.skipTitle(forward: true, seconds: 30), isEnabled: canSkip) {
                    timeshift.skip(forward: true)
                })
            #if os(macOS)
                let player = live.player
                var commands = base
                commands.mute = MenuCommand(title: KeyCommand.mute.title, isEnabled: playing && free) { player.toggleMute() }
                commands.volumeUp = MenuCommand(title: KeyCommand.volumeUp.title, isEnabled: playing && free) {
                    player.stepVolume(up: true)
                }
                commands.volumeDown = MenuCommand(title: KeyCommand.volumeDown.title, isEnabled: playing && free) {
                    player.stepVolume(up: false)
                }
                return commands
            #else
                return base
            #endif
        }
    }
#endif
