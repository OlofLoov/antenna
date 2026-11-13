import AntennaCore
import SwiftUI

/// A movie or episode full screen over the section. Close on iPhone, iPad
/// and Mac, or Menu on Apple TV, saves the place and goes back to the
/// poster that started it (movies-and-series-browsing/resume-where-you-left-off).
/// The transport shows the time and moves it
/// (player-controls-and-playback-errors/move-around-in-a-movie-or-episode;
/// `iPhone-Title-Player-Transport`, `iPad-Title-Player-Transport`,
/// `TV-Title-Player-Transport`, `TV-Title-Player-Scrub`). The audio and
/// subtitle lists sit top right on iPhone, iPad and Mac and in a panel held
/// open from select on Apple TV (`iPhone-Title-Player-Tracks`,
/// `iPad-Title-Player-Tracks`, `TV-Title-Player-Tracks`;
/// player-controls-and-playback-errors/choose-audio-and-subtitles-in-a-movie-or-episode).
struct ShelfPlayerView: View {
    let playback: ShelfPlayback
    let target: ShelfPlayback.Target

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()
            PlayerSurfaceView(engine: playback.engine)
                .overlay { PlayerSubtitles(engine: playback.engine, raised: raised) }
                .ignoresSafeArea()
                .accessibilityElement()
                .accessibilityLabel(title)
                .accessibilityIdentifier("\(target.title.kind.prefix).player")
            if let failure = playback.failure {
                TitleFailure(failure: failure, title: title, retry: { playback.retry() }, close: { Task { await playback.close() } })
            } else if let transport = playback.transport {
                #if os(tvOS)
                    TitleRemoteLayer(playback: playback, transport: transport, title: title)
                        .id(ObjectIdentifier(transport))
                #else
                    TitleTouchLayer(playback: playback, transport: transport, kind: target.title.kind.prefix)
                        .id(ObjectIdentifier(transport))
                #endif
            }
        }
        .overlay {
            #if DEBUG
                UITestingShelf.Probe(engine: playback.engine)
            #endif
        }
    }

    /// Points the subtitles move up while the controls cover the bottom.
    private var raised: CGFloat {
        guard playback.transport?.controlsShown == true else { return 0 }
        #if os(tvOS)
            return 220
        #else
            return 70
        #endif
    }

    private var title: String {
        switch target {
        case .movie(let movie): movie.name
        case .episode(let episode, let series): "\(series.name), \(ShelfText.episodeCode(episode) ?? episode.title)"
        case .trailer(_, let title): "\(title.name), trailer"
        }
    }
}

/// The error in place of a movie or episode that cannot play, with Try
/// again and a way back to the page
/// (player-controls-and-playback-errors/a-movie-or-episode-that-cannot-play-says-why).
/// Menu on Apple TV and Escape on a Mac go back too.
private struct TitleFailure: View {
    let failure: FailureMessage
    let title: String
    let retry: () -> Void
    let close: () -> Void
    #if os(tvOS)
        @FocusState private var retryFocused: Bool
    #endif

    var body: some View {
        #if os(tvOS)
            PlayerStatus.TelevisionFailure(
                title: failure.title, explanation: failure.explanation, detail: title, hint: "Press Menu to go back"
            ) {
                PlayerStatus.TelevisionButton(title: "Try again", action: retry)
                    .focused($retryFocused)
                    .accessibilityIdentifier("player.retry")
                PlayerStatus.TelevisionButton(title: "Back", action: close)
                    .accessibilityIdentifier("player.error.back")
            }
            .onExitCommand(perform: close)
            .task { retryFocused = true }
            .ignoresSafeArea()
        #else
            PlayerStatus.Failure(channel: title, title: failure.title, explanation: failure.explanation) {
                PlayerStatus.RetryButton(retry: retry)
                Button("Back", action: close)
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("player.error.back")
            }
            .ignoresSafeArea()
        #endif
    }
}

extension TitleTransport {
    /// The times the controls show, at the target while one is set.
    var times: Transport.Times {
        let timeline = timeline
        let shown = shownTime
        return Transport.Times(
            elapsed: timeline.elapsedText(at: shown), remaining: timeline.remainingText(at: shown),
            fraction: timeline.fraction(of: shown), spoken: timeline.spokenText(at: shown))
    }
}

#if os(tvOS)
    /// The Siri Remote over the playing title. The picture takes focus so
    /// select, Menu and play/pause reach it; the panel takes focus while
    /// open. Select and play/pause play and pause, or play from the target
    /// of a slide. Menu puts a target back, or closes the title. Holding
    /// select opens the panel. A hint layer for the remote goes between the
    /// bar and the panel.
    private struct TitleRemoteLayer: View {
        let playback: ShelfPlayback
        let transport: TitleTransport
        let title: String
        @FocusState private var focus: TitlePanelFocus?
        @State private var panelOpenedAt: ContinuousClock.Instant?
        @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver

        var body: some View {
            let panel = playback.tracks?.panel
            ZStack {
                Button {
                    select()
                } label: {
                    Color.clear
                }
                .buttonStyle(TitlePictureStyle())
                .simultaneousGesture(LongPressGesture(minimumDuration: 0.5).onEnded { _ in openPanel() })
                .disabled(panel != nil)
                .focused($focus, equals: .picture)
                .task { focus = .picture }
                .onExitCommand { menu() }
                .onPlayPauseCommand { transport.select() }
                .accessibilityHidden(true)
                if transport.controlsShown, panel == nil {
                    Transport.Bar(title: title, times: transport.times, isPaused: transport.isPaused, target: target)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
                if let notice = transport.notice {
                    Transport.Notice(text: notice)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .padding(.top, 60)
                }
                if let tracks = playback.tracks, panel != nil {
                    TitleTVPanel(tracks: tracks, focus: $focus)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .onExitCommand { closePanel() }
                        .transition(.move(edge: .top))
                }
            }
            .ignoresSafeArea()
            .background {
                TitleRemote(
                    active: panel == nil,
                    click: { transport.click(forward: $0) },
                    slideBegan: { transport.beginSlide() },
                    slid: { transport.slide(by: $0) },
                    slideEnded: { transport.endSlide() }
                )
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .animation(.easeOut(duration: 0.25), value: transport.controlsShown)
            .onChange(of: voiceOver, initial: true) { _, on in
                transport.held = on
            }
        }

        /// The slide's target on the bar and its time, nil when none.
        private var target: (fraction: Double, time: String)? {
            guard let time = transport.target, let fraction = transport.timeline.fraction(of: time) else { return nil }
            return (fraction, transport.timeline.elapsedText(at: time))
        }

        /// A click of select plays from the target, or plays and pauses.
        /// The release of a hold that opened the panel does nothing.
        private func select() {
            if let panelOpenedAt, ContinuousClock.now - panelOpenedAt < .milliseconds(1500) { return }
            transport.select()
        }

        private func menu() {
            if transport.isScrubbing { return transport.cancelScrub() }
            Task { await playback.close() }
        }

        /// Opens the panel on Audio with focus on its tab.
        private func openPanel() {
            guard let tracks = playback.tracks else { return }
            panelOpenedAt = .now
            tracks.panel = .audio
            focus = .segment(.audio)
        }

        private func closePanel() {
            playback.tracks?.panel = nil
            focus = .picture
        }
    }
#else
    /// Touch, pointer and keys over the playing title. A tap shows and
    /// hides the controls, a double tap on either half skips 10 seconds on
    /// iPhone and iPad, and the pointer shows them on a Mac. Left, right and
    /// Space skip and pause from a keyboard; Escape closes.
    private struct TitleTouchLayer: View {
        let playback: ShelfPlayback
        let transport: TitleTransport
        /// "movies" or "series", for the Close button's identifier.
        let kind: String
        @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
        @State private var width: CGFloat = 0

        var body: some View {
            let pickerOpen = playback.tracks?.pickerOpen ?? false
            ZStack(alignment: .topLeading) {
                surface
                if transport.controlsShown {
                    Palette.scrimTint.opacity(0.35)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                    Transport.Controls(
                        times: transport.times, isPaused: transport.isPaused,
                        playPause: { transport.playPause() },
                        skip: { transport.skip(forward: $0) },
                        drag: { transport.drag(to: $0) },
                        endDrag: { transport.endDrag() })
                    close
                    if let tracks = playback.tracks {
                        TitleTrackButtons(tracks: tracks)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                if let notice = transport.notice {
                    Transport.Notice(text: notice)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 72)
                }
            }
            .background { keys(pickerOpen: pickerOpen) }
            .animation(.easeOut(duration: 0.2), value: transport.controlsShown)
            .onChange(of: voiceOver || pickerOpen, initial: true) { _, holds in
                transport.held = holds
            }
        }

        private var surface: some View {
            Color.clear
                .contentShape(Rectangle())
                .onGeometryChange(for: CGFloat.self) {
                    $0.size.width
                } action: {
                    width = $0
                }
                #if os(iOS)
                    .onTapGesture(count: 2) { location in
                        transport.skip(forward: location.x > width / 2)
                    }
                #endif
                .onTapGesture { transport.toggle() }
                .onContinuousHover { phase in
                    switch phase {
                    case .active: transport.show(after: .touch)
                    case .ended: transport.show(after: .pointerLeft)
                    }
                }
                .accessibilityHidden(true)
        }

        private var close: some View {
            Button {
                Task { await playback.close() }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Palette.text)
                    .frame(width: 44, height: 44)
                    .background(Palette.scrimTint.opacity(0.6), in: Circle())
            }
            .buttonStyle(.plain)
            .padding(16)
            .accessibilityLabel("Close")
            .accessibilityIdentifier("\(kind).player.close")
        }

        /// Left and right skip, Space plays and pauses, Escape closes. They
        /// work while the controls are hidden.
        private func keys(pickerOpen: Bool) -> some View {
            ZStack {
                Group {
                    Button("Back 10 seconds") { transport.skip(forward: false) }
                        .keyboardShortcut(.leftArrow, modifiers: [])
                    Button("Forward 10 seconds") { transport.skip(forward: true) }
                        .keyboardShortcut(.rightArrow, modifiers: [])
                    Button("Play or pause") { transport.playPause() }
                        .keyboardShortcut(.space, modifiers: [])
                }
                .disabled(pickerOpen)
                Button("Close") { Task { await playback.close() } }
                    .keyboardShortcut(.cancelAction)
            }
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
        }
    }
#endif

#if os(tvOS)
    /// Where focus is in the Apple TV movie player.
    enum TitlePanelFocus: Hashable {
        case picture
        case segment(PanelTab)
        /// A track row by its id, or `TrackMenu.offID`.
        case track(String)
        /// The Subtitles On/Off switch after the tabs.
        case subtitles
    }

    /// The picture as a button that draws nothing, focused or not.
    private struct TitlePictureStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
        }
    }

    /// The panel over the playing title: Audio and Subtitles, with the
    /// Subtitles switch when the title has full subtitles. A title has no
    /// Info tab; its page already shows the details.
    struct TitleTVPanel: View {
        let tracks: TitleTracks
        let focus: FocusState<TitlePanelFocus?>.Binding

        static let tabs: [PanelTab] = [.audio, .subtitles]

        var body: some View {
            let tab = tracks.panel ?? .audio
            InfoPanel.Frame {
                ForEach(Self.tabs, id: \.self) { item in
                    InfoPanel.Segment(title: item.title, isSelected: item == tab) { tracks.panel = item }
                        .focused(focus, equals: .segment(item))
                        .accessibilityIdentifier("player.panel.segment.\(item.identifier)")
                }
            } accessory: {
                if tracks.canSwitchSubtitles {
                    InfoPanel.SubtitlesSwitch(isOn: tracks.subtitlesOn) { tracks.switchSubtitles() }
                        .focused(focus, equals: .subtitles)
                }
            } content: {
                switch tab {
                case .subtitles:
                    rows(tracks.subtitleRows, empty: TrackMenu.noSubtitles) { tracks.selectSubtitle($0) }
                default:
                    rows(tracks.audioRows, empty: nil) { tracks.selectAudio($0) }
                }
            }
        }

        @ViewBuilder
        private func rows(_ rows: [TrackRow], empty: String?, pick: @escaping (String) -> Void) -> some View {
            if rows.isEmpty, let empty {
                InfoPanel.Empty(text: empty)
            } else {
                InfoPanel.Tracks {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        InfoPanel.TrackButton(name: row.name, detail: row.detail, isSelected: row.isSelected) { pick(row.id) }
                            .focused(focus, equals: .track(row.id))
                            .accessibilityIdentifier("player.panel.track.\(index)")
                    }
                }
            }
        }
    }
#else
    /// The audio-and-subtitles button and the subtitles switch over the top
    /// right of the playing title. The list opens as a sheet at compact
    /// width and as a popover above the button otherwise, as in Live.
    struct TitleTrackButtons: View {
        let tracks: TitleTracks
        #if os(iOS)
            @Environment(\.horizontalSizeClass) private var sizeClass
        #endif

        var body: some View {
            @Bindable var tracks = tracks
            HStack(spacing: 0) {
                TrackPicker.OpenButton(isAvailable: tracks.hasTrackChoices) { tracks.openPicker() }
                    .popover(isPresented: $tracks.pickerOpen, arrowEdge: .bottom) {
                        if isCompact {
                            TrackPicker.Sheet(lists: lists) { tracks.closePicker() }
                                .presentationDetents([.medium, .large])
                                .presentationDragIndicator(.visible)
                        } else {
                            TrackPicker.Popover(lists: lists)
                                .presentationCompactAdaptation(.popover)
                        }
                    }
                TrackPicker.SubtitlesButton(isOn: tracks.subtitlesOn, isAvailable: tracks.canSwitchSubtitles) {
                    tracks.switchSubtitles()
                }
            }
            .padding(.horizontal, 4)
            .background(Palette.scrimTint.opacity(0.6), in: Capsule())
        }

        /// True at compact width on iPhone and iPad, never on a Mac.
        private var isCompact: Bool {
            #if os(iOS)
                sizeClass == .compact
            #else
                false
            #endif
        }

        private var lists: TrackPicker.Lists {
            TrackPicker.Lists(
                audio: tracks.audioRows, subtitles: tracks.subtitleRows,
                footer: [tracks.streamLine] + (tracks.route == .demuxer ? [LivePicture.noAirPlay] : []),
                pickAudio: { tracks.selectAudio($0) }, pickSubtitle: { tracks.selectSubtitle($0) })
        }
    }
#endif
