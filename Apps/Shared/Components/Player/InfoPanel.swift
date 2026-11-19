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
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("player.panel.segments")
                    accessory
                    Spacer()
                    Text("Menu closes")
                        .font(.boardStyle(22))
                        .foregroundStyle(Palette.textMuted)
                        .accessibilityIdentifier("player.panel.hint")
                }
                content
            }
            .padding(EdgeInsets(top: 60, leading: 80, bottom: 36, trailing: 80))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { OverlayMaterial() }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("player.panel")
        }
    }

    /// Info, Audio or Subtitles, a system chip; the selected one reads
    /// semibold (design-system/controls-use-system-styles).
    struct Segment: View {
        let title: LocalizedStringResource
        let isSelected: Bool
        let select: () -> Void

        var body: some View {
            Button(action: select) {
                Text(title)
                    .font(.boardStyle(26, weight: isSelected ? .semibold : .regular))
            }
            .chipStyle(isPicked: isSelected)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
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
        let badges: [ZapBarBadge]
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
                    .clipShape(cornerShape(.medium))
                    .accessibilityIdentifier("player.panel.logo")
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .firstTextBaseline, spacing: 18) {
                        if let number {
                            ChannelNumberText(number)
                                .font(.boardStyle(26))
                                .monospacedDigit()
                                .foregroundStyle(Palette.textMuted)
                        }
                        Text(channel).font(.boardStyle(36, weight: .bold))
                        Text(source).font(.boardStyle(22)).foregroundStyle(Palette.textMuted)
                    }
                    .foregroundStyle(Palette.text)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("player.panel.channel")
                    if let programme {
                        HStack(alignment: .firstTextBaseline, spacing: 24) {
                            Text(programme.title)
                                .font(.boardStyle(34, weight: .semibold))
                                .lineLimit(1)
                                .accessibilityIdentifier("player.panel.title")
                            Spacer(minLength: 0)
                            Text(programme.times)
                                .font(.boardStyle(24))
                                .monospacedDigit()
                                .foregroundStyle(Palette.textMuted)
                                .accessibilityIdentifier("player.panel.times")
                        }
                        .foregroundStyle(Palette.text)
                        Progress(fraction: programme.progress)
                        if let summary = programme.summary {
                            Text(summary)
                                .font(.boardStyle(24))
                                .lineSpacing(6)
                                .foregroundStyle(PlayerStatus.televisionBody)
                                .lineLimit(3)
                                .frame(maxWidth: 1200, alignment: .leading)
                                .accessibilityIdentifier("player.panel.summary")
                        }
                    } else {
                        Text(message)
                            .font(.boardStyle(30, weight: .semibold))
                            .foregroundStyle(Palette.text)
                            .accessibilityIdentifier("player.panel.title")
                    }
                    HStack(spacing: 24) {
                        HStack(spacing: 10) {
                            ForEach(badges, id: \.self) { badge in
                                if badge.kind == .quality {
                                    Text(badge.text).badge(filled: false)
                                } else {
                                    HStack(spacing: 8) {
                                        Circle().fill(Color(red: 0xFF / 255, green: 0x5F / 255, blue: 0x57 / 255)).frame(
                                            width: 10, height: 10)
                                        Text(badge.text)
                                    }
                                    .badge(filled: true)
                                }
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("player.panel.badges")
                        Text(stream)
                            .font(.boardStyle(22))
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

    /// One track as a bordered row: a tick on the current one, the name,
    /// and the sound format when known. Focused, it takes the light platter
    /// with dark text.
    struct TrackButton: View {
        let name: String
        let detail: String?
        let isSelected: Bool
        let pick: () -> Void

        var body: some View {
            Button(action: pick) {
                HStack(spacing: 20) {
                    Image(systemName: "checkmark")
                        .font(.boardStyle(22, weight: .bold))
                        .frame(width: 26, height: 26)
                        .opacity(isSelected ? 1 : 0)
                    Text(name)
                        .font(.boardStyle(29))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let detail {
                        Text(detail).font(.boardStyle(22)).foregroundStyle(.secondary)
                    }
                }
                .frame(minHeight: 56)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle(radius: 16))
            .frame(width: 900)
            .accessibilityValue(isSelected ? "Selected" : "")
            .accessibilityAddTraits(isSelected ? .isSelected : [])
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
                .font(.boardStyle(26))
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
                message: "", badges: ZapBarBadge.previewBadges(), stream: "MPEG-TS · H.264 1080p · AAC 5.1 · Antenna player"
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
