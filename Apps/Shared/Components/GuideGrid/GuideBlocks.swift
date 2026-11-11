import AntennaCore
import SwiftUI

extension GuideGrid {
    /// What a block holds.
    enum BlockContent: Equatable, Sendable {
        case programme(title: String, timing: GuideTiming, startedEarlier: Bool)
        /// Time with no programme: an unlabeled block.
        case gap
        /// A row with no programmes to show: "Loading guide…" and the like.
        case placeholder(String)
    }

    /// A block without the highlight: 0.06 surface and muted text when past,
    /// a gap or a placeholder, 0.08 otherwise; "◂" before a programme that
    /// started earlier. Radius 8.
    struct Block: View {
        let content: BlockContent
        let width: Double

        var body: some View {
            HStack(spacing: 10) {
                if case .programme(_, _, true) = content {
                    Text("◂").font(.system(size: 18)).accessibilityHidden(true)
                }
                if let title {
                    Text(title)
                        .font(.system(size: 24))
                        .lineLimit(1)
                }
            }
            .foregroundStyle(muted ? Palette.textMuted : Palette.text)
            .padding(.horizontal, 16)
            .frame(width: width, height: GuideRowLayout.rowHeight, alignment: .leading)
            .background(Palette.surface(muted ? 0.06 : 0.08), in: RoundedRectangle(cornerRadius: 8))
        }

        private var title: String? {
            switch content {
            case .programme(let title, _, _): title
            case .gap: nil
            case .placeholder(let text): text
            }
        }

        private var muted: Bool {
            switch content {
            case .programme(_, let timing, _): timing == .past
            case .gap, .placeholder: true
            }
        }
    }

    /// The highlighted block: the white focus card with a tighter shadow
    /// (design.md deviation), the title over its times, "20:00 – 22:00 · Live"
    /// when it is on now. A gap shows its times only.
    struct HighlightedBlock: View {
        let content: BlockContent
        /// "20:00 – 22:00", nil for a placeholder.
        let times: String?
        let width: Double

        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                if let title {
                    Text(title)
                        .font(.system(size: 24, weight: .semibold))
                        .lineLimit(1)
                }
                if let line {
                    Text(line)
                        .font(.system(size: 18))
                        .foregroundStyle(GuideGrid.mutedOnFocus)
                        .lineLimit(1)
                }
            }
            .foregroundStyle(Palette.ground)
            .padding(.horizontal, 16)
            .frame(width: width, height: GuideRowLayout.rowHeight, alignment: .leading)
            .background(Palette.focus, in: RoundedRectangle(cornerRadius: 8))
            .shadow(color: Color.black.opacity(0.5), radius: 14, y: 10)
        }

        private var title: String? {
            switch content {
            case .programme(let title, _, _): title
            case .gap: nil
            case .placeholder(let text): text
            }
        }

        private var line: String? {
            guard let times else { return nil }
            if case .programme(_, .now, _) = content { return "\(times) · Live" }
            return times
        }
    }
}

// MARK: Previews

private struct PreviewBlock {
    let title: String
    let width: Double
    let timing: GuideTiming
}

private let previewTitles: [[PreviewBlock]] = [
    [
        .init(title: "Snooker: UK Championship", width: 736, timing: .past),
        .init(title: "Cycling: Tour Down Under, Stage 4", width: 736, timing: .now),
    ],
    [
        .init(title: "Ski Jumping: World Cup", width: 551, timing: .past),
        .init(title: "Alpine Skiing: Night slalom", width: 551, timing: .now),
        .init(title: "Sports News", width: 366, timing: .future),
    ],
    [.init(title: "La Liga: Pre-match", width: 736, timing: .past), .init(title: "La Liga: Sevilla v Betis", width: 736, timing: .now)],
]

private struct GridPreview: View {
    var body: some View {
        GuideGrid.Screen {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 14).fill(Color(red: 0x1A / 255, green: 0x25 / 255, blue: 0x35 / 255))
                GuidePanel.PictureCaption(caption: "104 Sport One", look: .playing)
            }
        } panel: {
            GuidePanel.Panel(
                date: Date(timeIntervalSince1970: 77_640),
                details: .init(
                    eyebrow: "Now · Sport One", look: .now, title: "Premier League: Arsenal v Liverpool",
                    meta: "20:00 – 22:00 · 2 h · Football · 1080p", progress: 0.783,
                    summary: "Second half from the Emirates. Commentary by the studio team, with analysis at full time.")
            ) {
                GuidePanel.WatchButton {}
            }
        } grid: {
            GuideGrid.Grid(columns: ["20:00", "20:30", "21:00", "21:30"], now: .init(offset: 1159, time: "21:34")) {
                HStack(spacing: 10) {
                    GuideGrid.DayChip(title: "Today", look: .selected) {}
                    GuideGrid.DayChip(title: "Tue", look: .plain) {}
                    GuideGrid.DayChip(title: "Wed", look: .plain) {}
                }
            } rows: {
                ForEach(Array(zip(previewTitles.indices, previewTitles)), id: \.0) { index, blocks in
                    previewRow(number: 101 + index, name: ["Eurosport 1", "Eurosport 2", "Sport Two"][index], blocks: blocks)
                }
                GuideGrid.Row {
                    GuideGrid.ChannelCell(number: 104, name: "Sport One", look: .playing) {
                        GuideGrid.Initials(text: "S1", look: .playing)
                    }
                } blocks: {
                    GuideGrid.HighlightedBlock(
                        content: .programme(title: "Premier League: Arsenal v Liverpool", timing: .now, startedEarlier: false),
                        times: "20:00 – 22:00", width: 1476)
                }
            }
        }
        .background(Palette.ground)
    }

    private func previewRow(number: Int, name: String, blocks: [PreviewBlock]) -> some View {
        GuideGrid.Row {
            GuideGrid.ChannelCell(number: number, name: name, look: .plain) {
                GuideGrid.Initials(text: Channel.initials(for: name), look: .plain)
            }
        } blocks: {
            ForEach(Array(zip(blocks.indices, blocks)), id: \.0) { index, block in
                let leading = blocks.prefix(index).reduce(0) { $0 + $1.width + GuideRowLayout.gap }
                GuideGrid.Block(
                    content: .programme(title: block.title, timing: block.timing, startedEarlier: number == 101 && index == 0),
                    width: block.width
                )
                .offset(x: leading)
            }
        }
    }
}

#Preview("Guide grid, a programme on now", traits: .fixedLayout(width: 1920, height: 1080)) {
    GridPreview()
}

#Preview("Guide grid, placeholders and a highlighted gap", traits: .fixedLayout(width: 1920, height: 400)) {
    VStack(alignment: .leading, spacing: GuideGrid.rowSpacing) {
        GuideGrid.Row {
            GuideGrid.ChannelCell(number: 101, name: "Eurosport 1", look: .plain) { GuideGrid.Initials(text: "E1", look: .plain) }
        } blocks: {
            GuideGrid.Block(content: .placeholder(GuideLine.loading), width: 1476)
        }
        GuideGrid.Row {
            GuideGrid.ChannelCell(number: 106, name: "Arena HD", look: .plain) { GuideGrid.Initials(text: "AH", look: .plain) }
        } blocks: {
            GuideGrid.Block(content: .programme(title: "Handball Weekly", timing: .past, startedEarlier: false), width: 366)
            GuideGrid.Block(
                content: .programme(title: "Handball: EHF Champions League", timing: .past, startedEarlier: false), width: 366
            )
            .offset(x: 370)
            GuideGrid.HighlightedBlock(content: .gap, times: "21:00 – 21:30", width: 366).offset(x: 740)
            GuideGrid.Block(content: .gap, width: 366).offset(x: 1110)
        }
        GuideGrid.Row {
            GuideGrid.ChannelCell(number: 108, name: "Golf Channel", look: .plain) { GuideGrid.Initials(text: "GC", look: .plain) }
        } blocks: {
            GuideGrid.Block(content: .placeholder(ZapBarText.guideUnavailable), width: 1476)
        }
    }
    .padding(64)
    .background(Palette.ground)
}

#Preview("Guide grid, an empty group", traits: .fixedLayout(width: 1920, height: 1080)) {
    GuideGrid.Screen {
        GuidePanel.PictureCaption(caption: "104 Sport One", look: .waiting)
    } panel: {
        GuidePanel.ClockOnly(date: Date(timeIntervalSince1970: 77_640))
    } grid: {
        GuideGrid.Grid(columns: ["20:00", "20:30", "21:00", "21:30"], now: .init(offset: 1159, time: "21:34")) {
            GuideGrid.DayChip(title: "Today", look: .selected) {}
        } rows: {
            GuideGrid.Empty(text: "No channels in Favorites")
        }
    }
    .background(Palette.ground)
}
