import SwiftUI

/// The guide's top row beside the small picture
/// (tv-guide-grid/the-panel-describes-the-highlighted-programme): when the
/// highlighted programme is on and on which channel, the clock, the title,
/// times and length with category and quality, progress when on now, the
/// description, and Watch. Start over and Remind me stay hidden.
enum GuidePanel {
    /// The eyebrow is accent for "Now" only (design.md deviation).
    enum EyebrowLook: Equatable, Sendable {
        case now
        case other
    }

    /// The panel's words for one highlighted block.
    struct Details: Equatable, Sendable {
        /// "Now · Sport One" or "Today 22:00 · Sport One".
        var eyebrow: String
        var look: EyebrowLook
        var title: String
        /// "20:00 – 22:00 · 2 h · Football · 1080p"; nil for a placeholder.
        var meta: String?
        /// How far in, 0 to 1, when on now.
        var progress: Double?
        var summary: String?
    }

    /// The full panel, with the buttons in a row under the text.
    struct Panel<Buttons: View>: View {
        let date: Date
        let details: Details
        @ViewBuilder var buttons: Buttons

        var body: some View {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline, spacing: 24) {
                    Text(details.eyebrow)
                        .font(.system(size: 20, weight: .semibold))
                        .kerning(1.5)
                        .textCase(.uppercase)
                        .lineLimit(1)
                        .foregroundStyle(details.look == .now ? Palette.accent : Palette.textMuted)
                        .accessibilityIdentifier("guide.panel.eyebrow")
                    Spacer(minLength: 0)
                    Clock(date: date)
                }
                Text(details.title)
                    .font(.system(size: 40, weight: .bold))
                    .lineLimit(2)
                    .accessibilityIdentifier("guide.panel.title")
                if let meta = details.meta {
                    Text(meta)
                        .font(.system(size: 24))
                        .foregroundStyle(Palette.textMuted)
                        .lineLimit(1)
                        .accessibilityIdentifier("guide.panel.meta")
                }
                if let progress = details.progress {
                    Progress(fraction: progress)
                }
                if let summary = details.summary {
                    Text(summary)
                        .font(.system(size: 24))
                        .lineSpacing(6)
                        .foregroundStyle(ChannelOverlay.tileText)
                        .lineLimit(2)
                        .frame(maxWidth: 1100, alignment: .leading)
                        .accessibilityIdentifier("guide.panel.summary")
                }
                HStack(spacing: 14) {
                    buttons
                }
                .padding(.top, 6)
            }
        }
    }

    /// The panel with no block highlighted, as in an empty group: the clock only.
    struct ClockOnly: View {
        let date: Date

        var body: some View {
            Clock(date: date)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    struct Clock: View {
        let date: Date

        var body: some View {
            Text(date, format: .dateTime.hour().minute())
                .font(.system(size: 34, weight: .semibold))
                .tracking(0.5)
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize()
                .accessibilityIdentifier("guide.clock")
        }
    }

    /// The 4 pt accent bar, at most 1100 pt wide.
    private struct Progress: View {
        let fraction: Double

        var body: some View {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.surface(0.12))
                    Capsule().fill(Palette.accent).frame(width: proxy.size.width * min(1, max(0, fraction)))
                }
            }
            .frame(maxWidth: 1100)
            .frame(height: 4)
            .accessibilityElement()
            .accessibilityValue("\(Int((fraction * 100).rounded())) percent")
            .accessibilityIdentifier("guide.panel.progress")
        }
    }

    /// Watch: on the 0.12 surface, the white card with focus (design.md deviation).
    struct WatchButton: View {
        let watch: () -> Void

        var body: some View {
            Button("Watch", action: watch)
                .buttonStyle(WatchStyle())
        }
    }

    private struct WatchStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            WatchLabel(label: configuration.label)
        }
    }

    private struct WatchLabel<Label: View>: View {
        let label: Label
        @Environment(\.isFocused) private var isFocused

        var body: some View {
            label
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(isFocused ? Palette.ground : Palette.text)
                .padding(.vertical, 12)
                .padding(.horizontal, 24)
                .background(isFocused ? Palette.focus : Palette.surface(0.12), in: RoundedRectangle(cornerRadius: 10))
                .shadow(color: isFocused ? Palette.focusShadow : .clear, radius: 16, y: 12)
        }
    }

    /// What the small picture shows besides the video.
    enum PictureLook: Equatable, Sendable {
        /// Video plays: the caption with a red live dot.
        case playing
        /// Loading or failed: the background color under the caption.
        case waiting
        /// Nothing tuned since launch: the background color only.
        case nothing
    }

    /// The caption and background laid over the 480 by 270 picture.
    struct PictureCaption: View {
        /// "104 Sport One".
        let caption: String
        let look: PictureLook

        var body: some View {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(look == .playing ? Color.clear : Palette.ground)
                    .overlay {
                        RoundedRectangle(cornerRadius: 14).stroke(Palette.surface(look == .playing ? 0 : 0.08), lineWidth: 1)
                    }
                if look != .nothing {
                    HStack(spacing: 10) {
                        if look == .playing {
                            Circle()
                                .fill(Color(red: 0xFF / 255, green: 0x5F / 255, blue: 0x57 / 255))
                                .frame(width: 10, height: 10)
                        }
                        Text(caption)
                            .font(.system(size: 18))
                            .lineLimit(1)
                    }
                    .foregroundStyle(ChannelOverlay.tileText)
                    .padding(.leading, 16)
                    .padding(.bottom, 14)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("guide.pip")
        }
    }
}

#Preview("Guide panel, a future programme", traits: .fixedLayout(width: 1300, height: 400)) {
    GuidePanel.Panel(
        date: Date(timeIntervalSince1970: 77_640),
        details: .init(
            eyebrow: "Today 22:00 · Sport One", look: .other, title: "Premier League: Post-match", meta: "22:00 – 23:00 · 1 h · Football",
            summary: "Reaction from the Emirates, with the managers and the goals again.")
    ) {
        GuidePanel.WatchButton {}
    }
    .padding(40)
    .background(Palette.ground)
    .foregroundStyle(Palette.text)
}

#Preview("Guide small picture, loading", traits: .fixedLayout(width: 560, height: 350)) {
    GuidePanel.PictureCaption(caption: "104 Sport One", look: .waiting)
        .frame(width: 480, height: 270)
        .padding(40)
        .background(Palette.ground)
}
