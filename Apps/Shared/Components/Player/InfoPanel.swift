import AntennaCore
import SwiftUI

/// The Apple TV info panel over the top of the playing picture
/// (`TV-Player`, `TV-Player-Tracks`;
/// player-controls-and-playback-errors/see-what-s-on-without-stopping-the-picture-on-apple-tv).
enum InfoPanel {
    /// The 0.88 scrim across the top: the segments and "Menu closes", then
    /// the open tab's content.
    struct Frame<Segments: View, Accessory: View, Content: View>: View {
        @ViewBuilder var segments: Segments
        /// What sits after the segments, such as the subtitles switch.
        @ViewBuilder var accessory: Accessory
        @ViewBuilder var content: Content

        var body: some View {
            VStack(alignment: .leading, spacing: 30) {
                HStack(spacing: 24) {
                    HStack(spacing: 6) { segments }
                        .padding(6)
                        .background(Palette.surface(0.08), in: Capsule())
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("player.panel.segments")
                    accessory
                    Spacer()
                    Text("Menu closes")
                        .font(.system(size: 22))
                        .foregroundStyle(Palette.textMuted)
                        .accessibilityIdentifier("player.panel.hint")
                }
                content
            }
            .padding(EdgeInsets(top: 40, leading: 64, bottom: 36, trailing: 64))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.scrimTint.opacity(0.88))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("player.panel")
        }
    }

    /// Info, Audio or Subtitles. Focused it is the white card; selected
    /// while focus is in the list, the 0.12 surface at weight 600.
    struct Segment: View {
        let title: String
        let isSelected: Bool
        let select: () -> Void

        var body: some View {
            Button(title, action: select)
                .buttonStyle(SegmentStyle(isSelected: isSelected))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
    }

    struct SegmentStyle: ButtonStyle {
        let isSelected: Bool

        func makeBody(configuration: Configuration) -> some View {
            SegmentLabel(label: configuration.label, isSelected: isSelected)
        }
    }

    private struct SegmentLabel<Label: View>: View {
        let label: Label
        let isSelected: Bool
        @Environment(\.isFocused) private var isFocused

        var body: some View {
            label
                .font(.system(size: 26, weight: isFocused || isSelected ? .semibold : .regular))
                .padding(.vertical, 10)
                .padding(.horizontal, 26)
                .foregroundStyle(isFocused ? Palette.ground : Palette.text)
                .background(isFocused ? Palette.focus : isSelected ? Palette.surface(0.12) : .clear, in: Capsule())
                .shadow(color: isFocused ? Palette.focusShadow : .clear, radius: 16, y: 12)
        }
    }

    /// What is on: the logo, the channel, the programme with its times,
    /// time left, progress and summary, the badges and the stream line.
    struct Info<Logo: View>: View {
        /// The channel's number, name and source, as in "104", "Sport One", "Acme TV".
        let number: ChannelNumber?
        let channel: String
        let source: String
        let programme: Programme?
        /// The guide's status text in place of the programme when there is none.
        let message: String
        let badges: [String]
        let stream: String
        @ViewBuilder var logo: Logo

        /// The programme on now as the panel draws it.
        struct Programme: Equatable {
            var title: String
            /// "20:00 – 22:00 · 26 min left".
            var times: String
            var progress: Double
            var summary: String?
        }

        var body: some View {
            HStack(alignment: .top, spacing: 40) {
                logo
                    .frame(width: 132, height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .accessibilityIdentifier("player.panel.logo")
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .firstTextBaseline, spacing: 18) {
                        if let number {
                            Text(number.description)
                                .font(.system(size: 26))
                                .monospacedDigit()
                                .foregroundStyle(Palette.textMuted)
                        }
                        Text(channel).font(.system(size: 36, weight: .bold))
                        Text(source).font(.system(size: 22)).foregroundStyle(Palette.textMuted)
                    }
                    .foregroundStyle(Palette.text)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("player.panel.channel")
                    if let programme {
                        HStack(alignment: .firstTextBaseline, spacing: 24) {
                            Text(programme.title)
                                .font(.system(size: 34, weight: .semibold))
                                .lineLimit(1)
                                .accessibilityIdentifier("player.panel.title")
                            Spacer(minLength: 0)
                            Text(programme.times)
                                .font(.system(size: 24))
                                .monospacedDigit()
                                .foregroundStyle(Palette.textMuted)
                                .accessibilityIdentifier("player.panel.times")
                        }
                        .foregroundStyle(Palette.text)
                        Progress(fraction: programme.progress)
                        if let summary = programme.summary {
                            Text(summary)
                                .font(.system(size: 24))
                                .lineSpacing(6)
                                .foregroundStyle(PlayerStatus.televisionBody)
                                .lineLimit(3)
                                .frame(maxWidth: 1200, alignment: .leading)
                                .accessibilityIdentifier("player.panel.summary")
                        }
                    } else {
                        Text(message)
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(Palette.text)
                            .accessibilityIdentifier("player.panel.title")
                    }
                    HStack(spacing: 24) {
                        HStack(spacing: 10) {
                            ForEach(badges, id: \.self) { badge in
                                if badge == "LIVE" {
                                    HStack(spacing: 8) {
                                        Circle().fill(Color(red: 0xFF / 255, green: 0x5F / 255, blue: 0x57 / 255)).frame(
                                            width: 10, height: 10)
                                        Text(badge)
                                    }
                                    .badge(filled: true)
                                } else {
                                    Text(badge).badge(filled: false)
                                }
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("player.panel.badges")
                        Text(stream)
                            .font(.system(size: 22))
                            .foregroundStyle(Palette.textMuted)
                            .accessibilityIdentifier("player.panel.stream")
                    }
                    .padding(.top, 4)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("player.panel.info")
        }
    }

    /// The 6 pt accent bar (design-system/a-current-programme-always-shows-its-progress).
    private struct Progress: View {
        let fraction: Double

        var body: some View {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.surface(0.16))
                    Capsule().fill(Palette.accent).frame(width: proxy.size.width * min(1, max(0, fraction)))
                }
            }
            .frame(height: 6)
            .accessibilityElement()
            .accessibilityLabel("Programme progress")
            .accessibilityValue("\(Int((fraction * 100).rounded())) percent")
            .accessibilityIdentifier("player.panel.progress")
        }
    }

    /// One track, 72 pt tall, radius 14: a tick on the current one, the
    /// name, and the sound format when known.
    struct TrackButton: View {
        let name: String
        let detail: String?
        let isSelected: Bool
        let pick: () -> Void

        var body: some View {
            Button(action: pick) {
                HStack(spacing: 20) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 22, weight: .bold))
                        .frame(width: 26, height: 26)
                        .opacity(isSelected ? 1 : 0)
                    Text(name)
                        .font(.system(size: 29))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let detail {
                        Text(detail).font(.system(size: 22))
                    }
                }
            }
            .buttonStyle(TrackStyle())
            .frame(width: 900)
            .accessibilityValue(isSelected ? "Selected" : "")
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
    }

    private struct TrackStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            TrackLabel(label: configuration.label)
        }
    }

    private struct TrackLabel<Label: View>: View {
        let label: Label
        @Environment(\.isFocused) private var isFocused

        var body: some View {
            label
                .padding(.horizontal, 24)
                .frame(height: 72)
                .foregroundStyle(isFocused ? Palette.ground : Palette.text)
                .background(isFocused ? Palette.focus : Palette.surface(0.06), in: RoundedRectangle(cornerRadius: 14))
                .shadow(color: isFocused ? Palette.focusShadow : .clear, radius: 16, y: 12)
        }
    }

    /// The tracks of the open tab, one under the other.
    struct Tracks<Rows: View>: View {
        @ViewBuilder var rows: Rows

        var body: some View {
            VStack(alignment: .leading, spacing: 6) { rows }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("player.panel.tracks")
        }
    }

    /// "No subtitles in this stream" in place of the list.
    struct Empty: View {
        let text: String

        var body: some View {
            Text(text)
                .font(.system(size: 26))
                .foregroundStyle(Palette.textMuted)
                .frame(height: 72)
                .accessibilityIdentifier("player.panel.empty")
        }
    }
}

#Preview("Info panel", traits: .fixedLayout(width: 1920, height: 1080)) {
    ZStack(alignment: .top) {
        Color(red: 0x1A / 255, green: 0x25 / 255, blue: 0x35 / 255)
        InfoPanel.Frame {
            InfoPanel.Segment(title: "Info", isSelected: true) {}
            InfoPanel.Segment(title: "Audio", isSelected: false) {}
            InfoPanel.Segment(title: "Subtitles", isSelected: false) {}
        } content: {
            InfoPanel.Info(
                number: 104, channel: "Sport One", source: "Acme TV",
                programme: .init(
                    title: "Premier League: Arsenal v Liverpool", times: "20:00 – 22:00 · 26 min left", progress: 0.78,
                    summary: "Second half from the Emirates. Commentary by the studio team, with analysis at full time."),
                message: "", badges: ["LIVE", "1080p", "AAC 5.1"], stream: "MPEG-TS · H.264 1080p · AAC 5.1 · Antenna player"
            ) {
                ZapBar.Initials(text: "S1")
            }
        }
    }
}

#Preview("Info panel, no guide data", traits: .fixedLayout(width: 1920, height: 1080)) {
    ZStack(alignment: .top) {
        Color(red: 0x1A / 255, green: 0x25 / 255, blue: 0x35 / 255)
        InfoPanel.Frame {
            InfoPanel.Segment(title: "Info", isSelected: true) {}
            InfoPanel.Segment(title: "Audio", isSelected: false) {}
            InfoPanel.Segment(title: "Subtitles", isSelected: false) {}
        } content: {
            InfoPanel.Info(
                number: 104, channel: "Sport One", source: "Acme TV", programme: nil, message: "No guide for this channel",
                badges: [], stream: "Stream details not available yet"
            ) {
                ZapBar.Initials(text: "S1")
            }
        }
    }
}

#Preview("Info panel, audio", traits: .fixedLayout(width: 1920, height: 1080)) {
    ZStack(alignment: .top) {
        Color(red: 0x1A / 255, green: 0x25 / 255, blue: 0x35 / 255)
        InfoPanel.Frame {
            InfoPanel.Segment(title: "Info", isSelected: false) {}
            InfoPanel.Segment(title: "Audio", isSelected: true) {}
            InfoPanel.Segment(title: "Subtitles", isSelected: false) {}
        } content: {
            InfoPanel.Tracks {
                InfoPanel.TrackButton(name: "English", detail: "AAC 5.1", isSelected: true) {}
                InfoPanel.TrackButton(name: "English (audio description)", detail: nil, isSelected: false) {}
                InfoPanel.TrackButton(name: "Track 3", detail: nil, isSelected: false) {}
            }
        }
    }
}

#Preview("Info panel, no subtitles", traits: .fixedLayout(width: 1920, height: 1080)) {
    ZStack(alignment: .top) {
        Color(red: 0x1A / 255, green: 0x25 / 255, blue: 0x35 / 255)
        InfoPanel.Frame {
            InfoPanel.Segment(title: "Info", isSelected: false) {}
            InfoPanel.Segment(title: "Audio", isSelected: false) {}
            InfoPanel.Segment(title: "Subtitles", isSelected: true) {}
        } content: {
            InfoPanel.Empty(text: "No subtitles in this stream")
        }
    }
}
