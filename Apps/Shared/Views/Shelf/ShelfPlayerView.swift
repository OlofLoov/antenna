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
/// Near the end of an episode the Next episode button and the Up next card
/// sit bottom right (up-next capability).
struct ShelfPlayerView: View {
    let playback: ShelfPlayback
    let target: ShelfPlayback.Target
    @Environment(\.locale) private var locale

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
        case .trailer(_, let title): Words(locale)("\(title.name), trailer")
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
                Button("Try again", action: retry)
                    .focused($retryFocused)
                    .accessibilityIdentifier("player.retry")
                Button("Back", action: close)
                    .accessibilityIdentifier("player.error.back")
            }
            .onExitCommand(perform: close)
            .task { retryFocused = true }
            .ignoresSafeArea()
        #else
            PlayerStatus.Failure(channel: title, title: failure.title, explanation: failure.explanation) {
                Button("Try again", action: retry)
                    .accessibilityIdentifier("player.retry")
                Button("Back", action: close)
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("player.error.back")
            }
            .ignoresSafeArea()
        #endif
    }
}

extension ShelfPlayback.UpNextShown {
    /// The card's words, nil while only the button shows.
    var card: NextEpisode.Content? {
        guard let heading = UpNextText.heading(offer) else { return nil }
        return NextEpisode.Content(
            title: UpNextText.title(episode), heading: heading, spoken: UpNextText.spoken(episode, offer: offer),
            picture: episode.thumbnailURL, number: episode.number)
    }

    var isButton: Bool { offer == .button }

    var isAsking: Bool { offer == .asking }

    /// Play now, or Keep watching for "Still watching?".
    var primary: String { isAsking ? UpNextText.keepWatching() : UpNextText.playNow() }
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
        @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
        @Environment(\.locale) private var locale
        @Environment(\.layoutDirection) private var direction

        var body: some View {
            let panel = playback.tracks?.panel
            let upNext = panel == nil ? playback.upNext : nil
            let card = transport.isScrubbing ? nil : upNext?.card
            ZStack {
                HoldButton(click: transport.select, hold: openPanel) {
                    Color.clear
                }
                .buttonStyle(FocusHolderStyle())
                .disabled(panel != nil || card != nil)
                .focused($focus, equals: .picture)
                .controlHints(.titlePlayer(scrubbing: transport.isScrubbing, nextEpisode: upNext?.isButton == true))
                .task { focus = .picture }
                .onExitCommand { menu() }
                .onPlayPauseCommand { transport.select() }
                // Down reaches the Next episode button; left and right stay skips
                // (up-next/up-next-on-the-siri-remote).
                .onMoveCommand { direction in
                    if direction == .down, upNext?.isButton == true {
                        playback.noteInput()
                        focus = .nextEpisode
                    }
                }
                .accessibilityHidden(true)
                if transport.controlsShown, panel == nil {
                    Transport.Bar(title: title, times: transport.times, isPaused: transport.isPaused, target: target)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
                if let notice = transport.notice {
                    Transport.Notice(text: Words(locale)(notice))
                        .frame(maxHeight: .infinity, alignment: .top)
                        .padding(.top, 60)
                }
                if let upNext {
                    nextEpisode(upNext, card: card)
                        .padding(.trailing, 80)
                        .padding(.bottom, transport.controlsShown ? 230 : 60)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .transition(.opacity)
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
                    click: { transport.click(forward: direction.isTrailing(right: $0)) },
                    slideBegan: { transport.beginSlide() },
                    slid: { transport.slide(by: direction.towardTrailing($0)) },
                    slideEnded: { transport.endSlide() }
                )
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .animation(.easeOut(duration: 0.25), value: transport.controlsShown)
            .animation(.easeOut(duration: 0.25), value: upNext)
            .onChange(of: voiceOver, initial: true) { _, on in
                transport.held = on
            }
            // The card takes focus on Play now; when it or the button goes,
            // focus goes back to the picture.
            .onChange(of: card != nil) { _, shows in
                if shows {
                    focus = .nextEpisode
                } else if focus == .nextEpisode, upNext?.isButton != true {
                    focus = .picture
                }
            }
            .onChange(of: upNext == nil) { _, gone in
                if gone, focus == .nextEpisode { focus = .picture }
            }
        }

        /// The button in the last 30 seconds, the card in the last 15.
        @ViewBuilder
        private func nextEpisode(_ upNext: ShelfPlayback.UpNextShown, card: NextEpisode.Content?) -> some View {
            if let card {
                NextEpisode.Card(content: card) {
                    NextEpisode.PlayNow(title: upNext.primary) { playback.playNext() }
                        .focused($focus, equals: .nextEpisode)
                }
                .controlHints(.upNext(asking: upNext.isAsking))
                .onExitCommand {
                    playback.cancelUpNext()
                    focus = .picture
                }
                .onPlayPauseCommand { transport.playPause() }
            } else if upNext.isButton {
                NextEpisode.Button { playback.playNext() }
                    .focused($focus, equals: .nextEpisode)
                    .controlHints(.nextEpisodeButton)
                    .onExitCommand { focus = .picture }
                    .onPlayPauseCommand { transport.playPause() }
                    .onMoveCommand { direction in
                        if direction == .up { focus = .picture }
                    }
            }
        }

        /// The slide's target on the bar and its time, nil when none.
        private var target: (fraction: Double, time: String)? {
            guard let time = transport.target, let fraction = transport.timeline.fraction(of: time) else { return nil }
            return (fraction, transport.timeline.elapsedText(at: time))
        }

        private func menu() {
            if transport.isScrubbing { return transport.cancelScrub() }
            Task { await playback.close() }
        }

        /// Opens the panel on Audio with focus on its tab.
        private func openPanel() {
            guard let tracks = playback.tracks else { return }
            playback.noteInput()
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
        @Environment(\.locale) private var locale
        @Environment(\.layoutDirection) private var direction
        @Environment(\.publishesMenuCommands) private var inMenus
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
                    Transport.Notice(text: Words(locale)(notice))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 72)
                }
                if let upNext = playback.upNext {
                    nextEpisode(upNext)
                        .padding(.trailing, 16)
                        .padding(.bottom, transport.controlsShown ? 76 : 24)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .transition(.opacity)
                }
            }
            .background { keys(pickerOpen: pickerOpen, cardShows: playback.upNext?.card != nil) }
            .menuCommand(\.playbackCommands, menuCommands(pickerOpen: pickerOpen))
            .animation(.easeOut(duration: 0.2), value: playback.upNext)
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
                        transport.skip(forward: direction.isTrailing(right: location.x > width / 2))
                    }
                #endif
                .onTapGesture { transport.toggle() }
                .onContinuousHover { phase in
                    playback.noteInput()
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
                    .font(.boardStyle(17, weight: .semibold))
                    .foregroundStyle(Palette.text)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .controlSize(.large)
            .padding(16)
            .accessibilityLabel("Close")
            .accessibilityIdentifier("\(kind).player.close")
        }

        /// The button in the last 30 seconds, the card with Play now and
        /// Cancel in the last 15 (up-next/up-next-counts-down).
        @ViewBuilder
        private func nextEpisode(_ upNext: ShelfPlayback.UpNextShown) -> some View {
            if let card = upNext.card {
                NextEpisode.Card(content: card) {
                    NextEpisode.Cancel { playback.cancelUpNext() }
                    NextEpisode.PlayNow(title: upNext.primary) { playback.playNext() }
                }
            } else if upNext.isButton {
                NextEpisode.Button { playback.playNext() }
            }
        }

        /// The Playback menu's first items on iPad and Mac: Space, and Left
        /// and Right by 10 seconds, off while the track list is open
        /// (keyboard-commands/menu-items-follow-the-screen-in-front).
        private func menuCommands(pickerOpen: Bool) -> PlaybackCommands {
            PlaybackCommands(
                playPause: MenuCommand(title: KeyCommand.pauseTitle(paused: transport.isPaused), isEnabled: !pickerOpen) {
                    transport.playPause()
                },
                skipBack: MenuCommand(title: KeyCommand.skipTitle(forward: false, seconds: 10), isEnabled: !pickerOpen) {
                    transport.skip(forward: false)
                },
                skipForward: MenuCommand(title: KeyCommand.skipTitle(forward: true, seconds: 10), isEnabled: !pickerOpen) {
                    transport.skip(forward: true)
                })
        }

        /// Left and right skip, Space plays and pauses, Escape closes. In a
        /// right-to-left language the arrows swap with the mirrored bar:
        /// Right goes back, Left forward. They
        /// work while the controls are hidden. While the Up next card shows,
        /// Escape is the card's Cancel instead. Where the menus have the
        /// first three, only Escape is here.
        private func keys(pickerOpen: Bool, cardShows: Bool) -> some View {
            ZStack {
                if !inMenus {
                    Group {
                        Button("Back 10 seconds") { transport.skip(forward: false) }
                            .keyboardShortcut(direction.leadingArrow, modifiers: [])
                        Button("Forward 10 seconds") { transport.skip(forward: true) }
                            .keyboardShortcut(direction.trailingArrow, modifiers: [])
                        Button("Play or pause") { transport.playPause() }
                            .keyboardShortcut(.space, modifiers: [])
                    }
                    .disabled(pickerOpen)
                }
                if !cardShows {
                    Button("Close") { Task { await playback.close() } }
                        .keyboardShortcut(.cancelAction)
                }
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
        /// The Next episode button, or Play now on the Up next card.
        case nextEpisode
        case segment(PanelTab)
        /// A track row by its id, or `TrackMenu.offID`.
        case track(String)
        /// The Subtitles On/Off switch after the tabs.
        case subtitles
    }

#endif
