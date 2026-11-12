#if os(iOS) || os(macOS)
    import SwiftUI

    extension Browse {
        /// The two-row strip while live TV can rewind (`iPhone-Player-Timeshift`).
        /// Row one: the time on screen, the scrubber, how far behind live and
        /// the clock. Row two: back 15 seconds, play or pause, forward 30, the
        /// Start over slot, the programme's progress, LIVE, the platform's
        /// extras and full screen. Glyphs are 32 pt in 44 pt hit areas.
        struct TimeshiftControls<StartOver: View, Extras: View>: View {
            struct Scrub {
                let time: String
                /// Where the marker is, 0 to 1.
                let marker: Double
                var gaps: [ClosedRange<Double>] = []
                /// "12 min behind", nil at live.
                let behind: String?
                /// "CATCH-UP" while catch-up plays, nil on live TV.
                var badge: String?
            }

            let scrub: Scrub
            let isPaused: Bool
            /// How far into the programme on screen, 0 to 1; nil leaves the bar empty.
            let progress: Double?
            let clock: String
            let isFullScreen: Bool
            let playPause: () -> Void
            let skip: (_ forward: Bool) -> Void
            let drag: (_ fraction: Double) -> Void
            let endDrag: () -> Void
            let goLive: () -> Void
            let toggleFullScreen: () -> Void
            @ViewBuilder var startOver: StartOver
            @ViewBuilder var extras: Extras
            @Environment(\.browseMetrics) private var metrics

            var body: some View {
                let regular = metrics == .regular
                VStack(spacing: 2) {
                    HStack(spacing: 10) {
                        if let badge = scrub.badge {
                            Text(badge)
                                .font(.system(size: 10, weight: .bold))
                                .tracking(1)
                                .foregroundStyle(Palette.ground)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Palette.accent, in: RoundedRectangle(cornerRadius: 4))
                                .accessibilityIdentifier("timeshift.catchupBadge")
                        }
                        Text(scrub.time)
                            .font(.footnote.monospacedDigit())
                            .accessibilityIdentifier("timeshift.positionTime")
                        scrubber
                        if let behind = scrub.behind {
                            Text(behind)
                                .font(.footnote)
                                .foregroundStyle(Browse.textSecondary)
                                .lineLimit(1)
                                .accessibilityIdentifier("timeshift.behindLive")
                        }
                        Text(clock)
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(Browse.textSecondary)
                            .accessibilityIdentifier("browse.player.clock")
                    }
                    .padding(.horizontal, 6)
                    .frame(height: 30)
                    HStack(spacing: regular ? 10 : 4) {
                        glyph("gobackward.15", label: "Back 15 seconds", id: "timeshift.skipBack") { skip(false) }
                        Button(action: playPause) {
                            Image(systemName: isPaused ? "play.fill" : "pause.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Palette.ground)
                                .frame(width: 32, height: 32)
                                .background(Palette.text, in: Circle())
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(isPaused ? "Play" : "Pause")
                        .accessibilityIdentifier("browse.player.playPause")
                        glyph("goforward.30", label: "Forward 30 seconds", id: "timeshift.skipForward") { skip(true) }
                        startOver
                        ProgressTrack(fraction: progress ?? 0, height: regular ? 4 : 3)
                            .accessibilityElement()
                            .accessibilityLabel("Programme progress")
                            .accessibilityValue(progress.map { "\(Int(($0 * 100).rounded())) percent" } ?? "No programme information")
                            .accessibilityIdentifier("browse.player.progress")
                        if scrub.behind != nil {
                            LiveButton(action: goLive)
                        } else {
                            LiveBadge()
                        }
                        extras
                        FullScreenButton(isFullScreen: isFullScreen, toggle: toggleFullScreen)
                    }
                    .padding(.horizontal, regular ? 12 : 6)
                }
                .foregroundStyle(Palette.text)
                .padding(.vertical, 2)
                .background(Palette.scrimTint.opacity(0.72))
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("browse.player.controls")
            }

            /// Drags move the time shown and seek once on release; VoiceOver
            /// reads it as adjustable, and swiping up and down skips
            /// (timeshift-catch-up-and-start-over/skip-scan-and-drag).
            private var scrubber: some View {
                GeometryReader { proxy in
                    Timeshift.Track(marker: scrub.marker, gaps: scrub.gaps, height: 4, knob: 14)
                        .frame(maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in drag(value.location.x / max(1, proxy.size.width)) }
                                .onEnded { _ in endDrag() })
                }
                .frame(height: 30)
                .accessibilityElement()
                .accessibilityLabel("Position")
                .accessibilityValue([scrub.time, scrub.behind ?? "Live"].joined(separator: ", "))
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: skip(true)
                    case .decrement: skip(false)
                    @unknown default: break
                    }
                }
                .accessibilityIdentifier("timeshift.scrubber")
            }

            private func glyph(_ name: String, label: String, id: String, action: @escaping () -> Void) -> some View {
                Button(action: action) {
                    Image(systemName: name)
                        .font(.system(size: 22, weight: .semibold))
                        .frame(width: 32, height: 32)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(label)
                .accessibilityIdentifier(id)
            }
        }

        /// LIVE while behind live: a muted dot, outlined, and a button that
        /// goes back to live (timeshift-catch-up-and-start-over/back-to-live).
        struct LiveButton: View {
            let action: () -> Void

            var body: some View {
                Button(action: action) {
                    HStack(spacing: 5) {
                        Circle().fill(Palette.textMuted).frame(width: 6, height: 6)
                        Text("LIVE")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(1)
                    }
                    .padding(.vertical, 3)
                    .padding(.horizontal, 7)
                    .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Palette.textMuted, lineWidth: 1))
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Go to live")
                .accessibilityIdentifier("browse.player.live")
                .accessibilityValue("behind")
            }
        }

        /// Start over, shown only when it can work
        /// (timeshift-catch-up-and-start-over/start-over-shows-only-when-it-can-work).
        struct StartOverButton: View {
            let action: () -> Void

            var body: some View {
                Button(action: action) {
                    Image(systemName: "backward.end.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Start over")
                .accessibilityIdentifier("timeshift.startOver")
            }
        }
    }

    #Preview("Timeshift controls, iPhone, paused 12 minutes behind", traits: .fixedLayout(width: 390, height: 90)) {
        Browse.TimeshiftControls(
            scrub: .init(time: "21:22", marker: 0.8, behind: "12 min behind"), isPaused: true, progress: 0.68, clock: "21:34",
            isFullScreen: false, playPause: {}, skip: { _ in }, drag: { _ in }, endDrag: {}, goLive: {}, toggleFullScreen: {}
        ) {
            Browse.StartOverButton {}
        } extras: {
            EmptyView()
        }
    }

    #Preview("Timeshift controls, iPad, at live", traits: .fixedLayout(width: 700, height: 90)) {
        Browse.TimeshiftControls(
            scrub: .init(time: "21:34", marker: 1, behind: nil), isPaused: false, progress: 0.78, clock: "21:34", isFullScreen: false,
            playPause: {}, skip: { _ in }, drag: { _ in }, endDrag: {}, goLive: {}, toggleFullScreen: {}
        ) {
            EmptyView()
        } extras: {
            Browse.PictureInPictureButton(isAvailable: true) {}
        }
        .environment(\.browseMetrics, .regular)
    }
#endif
