import AntennaCore
import SwiftUI

/// The audio and subtitles list on iPhone, iPad and Mac
/// (`iPhone-Player-Tracks`, `iPad-Player-Tracks`;
/// player-controls-and-playback-errors/choose-audio-and-subtitles).
enum TrackPicker {
    /// The speech-bubble button in the player controls, grayed out when
    /// the stream has one sound and no subtitles.
    struct OpenButton: View {
        let isAvailable: Bool
        let open: () -> Void

        var body: some View {
            Button(action: open) {
                Image(systemName: "text.bubble")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Palette.text)
            .disabled(!isAvailable)
            .opacity(isAvailable ? 1 : 0.4)
            .accessibilityLabel("Audio and subtitles")
            .accessibilityIdentifier("player.tracks")
        }
    }

    /// Subtitles on or off in one press, filled while full subtitles are on,
    /// grayed out when the stream has none (`iPhone-FullScreen-Subtitles`,
    /// `iPad-Player`; player-controls-and-playback-errors/turn-subtitles-on-or-off-in-one-step).
    struct SubtitlesButton: View {
        let isOn: Bool
        let isAvailable: Bool
        let toggle: () -> Void

        var body: some View {
            Button(action: toggle) {
                Image(systemName: isOn ? "captions.bubble.fill" : "captions.bubble")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Palette.text)
            .disabled(!isAvailable)
            .opacity(isAvailable ? 1 : 0.4)
            .accessibilityLabel("Subtitles")
            .accessibilityValue(isOn ? "On" : "Off")
            .accessibilityIdentifier("player.subtitles")
        }
    }

    /// The Audio section, the Subtitles section with Off first or a line
    /// saying there are none, and footer lines such as the stream line.
    struct Lists: View {
        let audio: [TrackRow]
        let subtitles: [TrackRow]
        let footer: [String]
        let pickAudio: (String) -> Void
        let pickSubtitle: (String) -> Void

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    Header(text: "Audio")
                    ForEach(Array(audio.enumerated()), id: \.element.id) { index, row in
                        Row(row: row) { pickAudio(row.id) }
                            .accessibilityIdentifier("player.trackPicker.audio.\(index)")
                    }
                    Header(text: "Subtitles")
                        .padding(.top, 12)
                    if subtitles.isEmpty {
                        Text(TrackMenu.noSubtitles)
                            .font(.subheadline)
                            .foregroundStyle(Palette.textMuted)
                            .frame(minHeight: 44)
                            .padding(.horizontal, 12)
                            .accessibilityIdentifier("player.trackPicker.subtitles.none")
                    }
                    ForEach(Array(subtitles.enumerated()), id: \.element.id) { index, row in
                        Row(row: row) { pickSubtitle(row.id) }
                            .accessibilityIdentifier(
                                row.id == TrackMenu.offID ? "player.trackPicker.subtitles.off" : "player.trackPicker.subtitles.\(index - 1)"
                            )
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(footer, id: \.self) { line in
                            Text(line)
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(Palette.textMuted)
                    .padding(EdgeInsets(top: 14, leading: 12, bottom: 4, trailing: 12))
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("player.trackPicker.stream")
                }
                .padding(12)
            }
        }
    }

    /// The sheet at compact width: a grabber, "Audio & Subtitles" with
    /// Done, then the lists. Swiping down closes it too.
    struct Sheet: View {
        let lists: Lists
        let done: () -> Void

        var body: some View {
            VStack(spacing: 0) {
                HStack {
                    Text("Audio & Subtitles").font(.headline)
                    Spacer()
                    Button("Done", action: done)
                        .font(.headline)
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("player.trackPicker.done")
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                lists
            }
            .foregroundStyle(Palette.text)
            .background(Palette.tabBar)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("player.trackPicker")
        }
    }

    /// The popover above the button at regular width and on Mac.
    struct Popover: View {
        let lists: Lists

        var body: some View {
            lists
                .frame(width: 320)
                .frame(maxHeight: 480)
                .foregroundStyle(Palette.text)
                .background(Palette.tabBar)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("player.trackPicker")
        }
    }

    /// A 13 pt uppercase muted section title.
    private struct Header: View {
        let text: String

        var body: some View {
            Text(text.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.textMuted)
                .padding(.horizontal, 12)
                .padding(.bottom, 2)
                .accessibilityAddTraits(.isHeader)
        }
    }

    /// One 44 pt row, radius 10: a tick on the current track, the name and
    /// the sound format when known.
    struct Row: View {
        let row: TrackRow
        let pick: () -> Void

        var body: some View {
            Button(action: pick) {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Palette.accent)
                        .frame(width: 18)
                        .opacity(row.isSelected ? 1 : 0)
                    Text(row.name)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let detail = row.detail {
                        Text(detail)
                            .font(.footnote)
                            .foregroundStyle(Palette.textMuted)
                    }
                }
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(row.isSelected ? Palette.surface(0.08) : .clear, in: RoundedRectangle(cornerRadius: 10))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(row.name)
            .accessibilityValue(row.isSelected ? "Selected" : "")
            .accessibilityAddTraits(row.isSelected ? .isSelected : [])
        }
    }
}

extension TrackPicker {
    @MainActor static let previewLists = Lists(
        audio: [
            TrackRow(id: "audio-0", name: "English", detail: "AAC 5.1", isSelected: true),
            TrackRow(id: "audio-1", name: "English (audio description)", detail: nil, isSelected: false),
            TrackRow(id: "audio-2", name: "Español", detail: nil, isSelected: false),
        ],
        subtitles: [
            TrackRow(id: "off", name: "Off", detail: nil, isSelected: true),
            TrackRow(id: "subtitle-0", name: "English", detail: nil, isSelected: false),
            TrackRow(id: "subtitle-1", name: "Forced", detail: nil, isSelected: false),
        ],
        footer: ["MPEG-TS · H.264 1080p · AAC 5.1 · Antenna player"], pickAudio: { _ in }, pickSubtitle: { _ in })
}

#Preview("Track picker, iPhone sheet", traits: .fixedLayout(width: 390, height: 560)) {
    TrackPicker.Sheet(lists: TrackPicker.previewLists) {}
}

#Preview("Track picker, iPad popover", traits: .fixedLayout(width: 320, height: 480)) {
    TrackPicker.Popover(lists: TrackPicker.previewLists)
}

#Preview("Track picker, no subtitles", traits: .fixedLayout(width: 320, height: 360)) {
    TrackPicker.Popover(
        lists: TrackPicker.Lists(
            audio: [TrackRow(id: "audio-0", name: "English", detail: "AAC Stereo", isSelected: true)], subtitles: [],
            footer: ["HLS · H.264 720p · AAC Stereo · Apple player"], pickAudio: { _ in }, pickSubtitle: { _ in }))
}

#Preview("Subtitles button, on and off", traits: .fixedLayout(width: 160, height: 60)) {
    HStack {
        TrackPicker.SubtitlesButton(isOn: true, isAvailable: true) {}
        TrackPicker.SubtitlesButton(isOn: false, isAvailable: true) {}
        TrackPicker.SubtitlesButton(isOn: false, isAvailable: false) {}
    }
    .background(Palette.ground)
}

#Preview("Tracks button, grayed out", traits: .fixedLayout(width: 60, height: 60)) {
    TrackPicker.OpenButton(isAvailable: false) {}
        .background(Palette.ground)
}
