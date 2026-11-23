import AntennaCore
import SwiftUI

/// The one audio-and-subtitles button on iPhone, iPad and Mac, as in
/// Apple's TV app (`iPhone-Player-Tracks`, `iPad-Player-Tracks`;
/// player-controls-and-playback-errors/one-button-for-audio-and-subtitles).
enum TrackPicker {
    /// The captions bubble, filled while full subtitles are on, opening a
    /// system menu: Audio, Subtitles with Off first or a line saying there
    /// are none, then the stream line. Grayed out when the stream has one
    /// sound and no subtitles. The order is fixed: opened near the bottom
    /// of the screen, iOS 26 otherwise reverses it, Subtitles above Audio
    /// and Off under the tracks. The system menu drops SwiftUI identifiers
    /// on its rows; UI tests find them by label.
    struct MenuButton: View {
        let audio: [TrackRow]
        let subtitles: [TrackRow]
        let footer: [LocalizedStringResource]
        let subtitlesOn: Bool
        let isAvailable: Bool
        let pickAudio: (String) -> Void
        let pickSubtitle: (String) -> Void
        /// True when the menu opens and false when it closes, so the
        /// controls stay up behind it.
        let shown: (Bool) -> Void

        var body: some View {
            Menu {
                Section("Audio") {
                    ForEach(audio) { row in
                        Item(row: row) { pickAudio(row.id) }
                    }
                }
                Section("Subtitles") {
                    if subtitles.isEmpty {
                        Text(TrackMenu.noSubtitles())
                    }
                    ForEach(subtitles) { row in
                        Item(row: row) { pickSubtitle(row.id) }
                    }
                }
                Section {
                    ForEach(Array(footer.enumerated()), id: \.offset) { _, line in
                        Text(line)
                    }
                }
                #if os(iOS)
                    .onAppear { shown(true) }
                    .onDisappear { shown(false) }
                #endif
            } label: {
                Image(systemName: subtitlesOn ? "captions.bubble.fill" : "captions.bubble")
                    .font(.boardStyle(16, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .menuOrder(.fixed)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .foregroundStyle(Palette.text)
            .disabled(!isAvailable)
            .opacity(isAvailable ? 1 : 0.4)
            .accessibilityLabel("Audio and Subtitles")
            .accessibilityValue(subtitlesOn ? "Subtitles On" : "Subtitles Off")
            .accessibilityIdentifier("player.tracks")
        }
    }

    /// One menu row: a check on the current track, the name and the sound
    /// format under it when known.
    private struct Item: View {
        let row: TrackRow
        let pick: () -> Void

        var body: some View {
            Toggle(isOn: Binding(get: { row.isSelected }, set: { _ in pick() })) {
                Text(row.name)
                if let detail = row.detail {
                    Text(detail)
                }
            }
        }
    }
}

extension TrackPicker {
    @MainActor static func preview(subtitlesOn: Bool, isAvailable: Bool) -> MenuButton {
        MenuButton(
            audio: [
                TrackRow(id: "audio-0", name: "English", detail: "AAC 5.1", isSelected: true),
                TrackRow(id: "audio-1", name: "English (audio description)", detail: nil, isSelected: false),
            ],
            subtitles: [
                TrackRow(id: "off", name: "Off", detail: nil, isSelected: !subtitlesOn),
                TrackRow(id: "subtitle-0", name: "English", detail: nil, isSelected: subtitlesOn),
            ],
            footer: [.verbatim("MPEG-TS · H.264 1080p · AAC 5.1 · Antuna player")], subtitlesOn: subtitlesOn,
            isAvailable: isAvailable, pickAudio: { _ in }, pickSubtitle: { _ in }, shown: { _ in })
    }
}

#Preview("Tracks button: subtitles on, off, grayed out", traits: .fixedLayout(width: 160, height: 60)) {
    HStack {
        TrackPicker.preview(subtitlesOn: true, isAvailable: true)
        TrackPicker.preview(subtitlesOn: false, isAvailable: true)
        TrackPicker.preview(subtitlesOn: false, isAvailable: false)
    }
    .background(Palette.ground)
}
