#if os(iOS) || os(macOS)
    import AntennaCore
    import SwiftUI

    /// The two-row strip while the channel can rewind
    /// (timeshift-catch-up-and-start-over capability): the scrubber, the
    /// skips, LIVE as a button while behind, and the programme at the
    /// picture's time.
    struct LiveTimeshiftStrip<Extras: View>: View {
        @Environment(LiveModel.self) private var live
        @ViewBuilder var extras: Extras

        var body: some View {
            let timeshift = live.player.timeshift
            TimelineView(.periodic(from: .now, by: LiveClock.tick)) { context in
                let shown = timeshift.shownTime ?? context.date
                // The programme shown is the one at the picture's time
                // (timeshift-catch-up-and-start-over/pause-live-tv-and-pick-up-where-you-left-off).
                let progress = live.playing.map { live.nowText(for: $0, at: shown) }?.progress
                Browse.TimeshiftControls(
                    scrub: .init(
                        time: LiveModel.time(shown), marker: timeshift.markerFraction ?? 1, gaps: timeshift.gaps,
                        behind: timeshift.behindText, badge: timeshift.catchup == nil ? nil : "CATCH-UP"),
                    isPaused: live.isPaused, progress: progress, clock: LiveModel.time(context.date), isFullScreen: live.fullScreen,
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
    /// can rewind and the filter field does not have the keyboard.
    struct LiveSkipKeys: View {
        let live: LiveModel

        var body: some View {
            if live.playing != nil, live.player.timeshift.canRewind {
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
#endif
