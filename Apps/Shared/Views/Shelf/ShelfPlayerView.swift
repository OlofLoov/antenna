import AntennaCore
import SwiftUI

/// A movie or episode full screen over the section. Close on iPhone, iPad
/// and Mac, or Menu on Apple TV, saves the place and goes back to the
/// poster that started it (movies-and-series-browsing/resume-where-you-left-off).
/// A tap, or play/pause on the remote, pauses and plays. The audio and
/// subtitle lists sit top right on iPhone, iPad and Mac and in a panel held
/// open from select on Apple TV (`iPhone-Title-Player-Tracks`,
/// `iPad-Title-Player-Tracks`, `TV-Title-Player-Tracks`;
/// player-controls-and-playback-errors/choose-audio-and-subtitles-in-a-movie-or-episode).
struct ShelfPlayerView: View {
    let playback: ShelfPlayback
    let target: ShelfPlayback.Target
    #if os(tvOS)
        @FocusState private var focus: TitlePanelFocus?
    #endif

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()
            PlayerSurfaceView(engine: playback.engine)
                .overlay { PlayerSubtitles(engine: playback.engine) }
                .ignoresSafeArea()
                .accessibilityElement()
                .accessibilityLabel(title)
                .accessibilityIdentifier("\(target.title.kind.prefix).player")
            #if os(tvOS)
                television
            #else
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { Task { await playback.playPause() } }
                    .accessibilityHidden(true)
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
                .keyboardShortcut(.cancelAction)
                .padding(16)
                .accessibilityLabel("Close")
                .accessibilityIdentifier("\(target.title.kind.prefix).player.close")
                if let tracks = playback.tracks {
                    TitleTrackButtons(tracks: tracks)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            #endif
        }
        .overlay {
            #if DEBUG
                UITestingShelf.Probe(engine: playback.engine)
            #endif
        }
    }

    #if os(tvOS)
        /// The picture takes focus so Menu, play/pause and holding select
        /// reach it; the panel takes it while open.
        @ViewBuilder private var television: some View {
            let panel = playback.tracks?.panel
            // A press does nothing; holding select opens the panel.
            Button {
            } label: {
                Color.clear
            }
            .buttonStyle(TitlePictureStyle())
            .simultaneousGesture(LongPressGesture(minimumDuration: 0.5).onEnded { _ in openPanel() })
            .disabled(panel != nil)
            .focused($focus, equals: .picture)
            .task { focus = .picture }
            .onExitCommand { Task { await playback.close() } }
            .onPlayPauseCommand { Task { await playback.playPause() } }
            .accessibilityHidden(true)
            if let tracks = playback.tracks, panel != nil {
                TitleTVPanel(tracks: tracks, focus: $focus)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .onExitCommand { closePanel() }
                    .transition(.move(edge: .top))
            }
        }

        /// Opens the panel on Audio with focus on its tab.
        private func openPanel() {
            guard let tracks = playback.tracks else { return }
            tracks.panel = .audio
            focus = .segment(.audio)
        }

        private func closePanel() {
            playback.tracks?.panel = nil
            focus = .picture
        }
    #endif

    private var title: String {
        switch target {
        case .movie(let movie): movie.name
        case .episode(let episode, let series): "\(series.name), \(ShelfText.episodeCode(episode) ?? episode.title)"
        case .trailer(_, let title): "\(title.name), trailer"
        }
    }
}

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
