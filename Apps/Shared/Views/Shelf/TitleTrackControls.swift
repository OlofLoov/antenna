import AntennaCore
import SwiftUI

#if os(tvOS)
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
                    rows(tracks.subtitleRows, empty: TrackMenu.noSubtitles()) { tracks.selectSubtitle($0) }
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
                footer: [.verbatim(tracks.streamLine)] + (tracks.route == .demuxer ? [LivePicture.noAirPlay] : []),
                pickAudio: { tracks.selectAudio($0) }, pickSubtitle: { tracks.selectSubtitle($0) })
        }
    }
#endif
