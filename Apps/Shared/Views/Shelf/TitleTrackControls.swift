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
    /// The audio-and-subtitles button over the top right of the playing
    /// title, on a glass capsule as in Live
    /// (design-system/liquid-glass-stays-on-the-navigation-layer;
    /// player-controls-and-playback-errors/one-button-for-audio-and-subtitles).
    struct TitleTrackButtons: View {
        let tracks: TitleTracks

        var body: some View {
            TrackPicker.MenuButton(
                audio: tracks.audioRows, subtitles: tracks.subtitleRows,
                footer: [.verbatim(tracks.streamLine)] + (tracks.route == .demuxer ? [LivePicture.noAirPlay] : []),
                subtitlesOn: tracks.subtitlesOn, isAvailable: tracks.hasTrackChoices,
                pickAudio: { tracks.selectAudio($0) }, pickSubtitle: { tracks.selectSubtitle($0) },
                shown: { $0 ? tracks.openPicker() : tracks.closePicker() }
            )
            .foregroundStyle(Palette.text)
            .tint(Palette.text)
            .padding(.horizontal, 4)
            .glassEffect(.regular, in: Capsule())
        }
    }
#endif
