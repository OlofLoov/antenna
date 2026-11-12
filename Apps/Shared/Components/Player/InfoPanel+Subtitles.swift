import AntennaCore
import SwiftUI

extension InfoPanel.Frame where Accessory == EmptyView {
    /// The panel with nothing after the segments.
    init(@ViewBuilder segments: () -> Segments, @ViewBuilder content: () -> Content) {
        self.init(segments: segments, accessory: { EmptyView() }, content: content)
    }
}

extension InfoPanel {
    /// "Subtitles On" or "Subtitles Off" after the tabs, in the segment
    /// style: select flips it and the panel stays (`TV-Player-Subtitles`;
    /// player-controls-and-playback-errors/turn-subtitles-on-or-off-in-one-step).
    struct SubtitlesSwitch: View {
        let isOn: Bool
        let toggle: () -> Void

        var body: some View {
            Button(action: toggle) {
                Label(isOn ? "Subtitles On" : "Subtitles Off", systemImage: isOn ? "captions.bubble.fill" : "captions.bubble")
            }
            .buttonStyle(SegmentStyle(isSelected: false))
            .accessibilityLabel("Subtitles")
            .accessibilityValue(isOn ? "On" : "Off")
            .accessibilityIdentifier("player.panel.subtitles")
        }
    }
}

#Preview("Info panel, subtitles with the switch", traits: .fixedLayout(width: 1920, height: 1080)) {
    ZStack(alignment: .top) {
        Color(red: 0x1A / 255, green: 0x25 / 255, blue: 0x35 / 255)
        InfoPanel.Frame {
            InfoPanel.Segment(title: "Info", isSelected: false) {}
            InfoPanel.Segment(title: "Audio", isSelected: false) {}
            InfoPanel.Segment(title: "Subtitles", isSelected: true) {}
        } accessory: {
            InfoPanel.SubtitlesSwitch(isOn: true) {}
        } content: {
            InfoPanel.Tracks {
                InfoPanel.TrackButton(name: "Off", detail: nil, isSelected: false) {}
                InfoPanel.TrackButton(name: "English", detail: nil, isSelected: true) {}
                InfoPanel.TrackButton(name: "English (Forced)", detail: nil, isSelected: false) {}
                InfoPanel.TrackButton(name: "German", detail: nil, isSelected: false) {}
            }
        }
    }
}
