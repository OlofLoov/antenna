import AntennaCore
import SwiftUI

/// The guide grid on iPad and Mac (guide-on-iphone-ipad-and-mac capability;
/// `iPad-Guide`, `iPad-Guide-Placeholders`, `iPad-Guide-Empty`): channel
/// cells, programme blocks, the time header and the now line. The screen
/// places them; each part draws one thing the board names.
enum GuideBoard {
    /// Rows are 56 pt with a 4 pt gap at the default text size.
    static let rowHeight = 56.0
    static let rowGap = GuideRowLayout.gap
    static let headerHeight = 36.0

    /// How a channel cell reads.
    enum ChannelLook: Equatable {
        case plain
        /// The channel playing in Live: its name at weight 600 on the selected tile.
        case playing
    }

    /// Number, logo and name in the 196 pt column. The number is muted and
    /// tabular; the name of the playing channel is semibold.
    struct ChannelCell<Logo: View>: View {
        let number: ChannelNumber?
        let name: String
        let look: ChannelLook
        @ViewBuilder var logo: Logo
        @ScaledMetric(relativeTo: .subheadline) private var nameSize: CGFloat = 15
        @ScaledMetric(relativeTo: .footnote) private var numberSize: CGFloat = 13

        var body: some View {
            HStack(spacing: 10) {
                Text(number.map(\.description) ?? "")
                    .font(.system(size: numberSize))
                    .monospacedDigit()
                    .foregroundStyle(Palette.textMuted)
                    .frame(width: 32, alignment: .trailing)
                logo
                    .frame(width: 56, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                Text(name)
                    .font(.system(size: nameSize, weight: look == .playing ? .semibold : .regular))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .foregroundStyle(Palette.text)
            .padding(.trailing, 10)
            .frame(width: GuideZoom.channelColumn - rowGap, alignment: .leading)
            .frame(maxHeight: .infinity)
            .background(Palette.ground)
            .contentShape(Rectangle())
        }
    }

    /// A channel's tile with its initials, for a channel without a logo
    /// (design-system/channels-without-a-logo-show-initials).
    struct Initials: View {
        let text: String
        let look: ChannelLook

        var body: some View {
            Text(text)
                .font(.system(size: 12, weight: .bold))
                .kerning(1)
                .foregroundStyle(look == .playing ? Palette.text : Browse.textSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(look == .playing ? Browse.tileSelected : Browse.tile)
        }
    }

    /// What a block holds.
    enum BlockContent: Equatable {
        /// A programme's title. `startedEarlier` puts a ◂ before it.
        case programme(title: String, timing: GuideTiming, startedEarlier: Bool)
        /// Empty space between two programmes.
        case gap
        /// "Loading guide…", "No programme information" or "Guide unavailable" across the row.
        case placeholder(String)
    }

    /// One programme, gap or placeholder, as wide as the layout says. Past
    /// programmes and placeholders are dimmer; the selected block is lighter.
    struct Block: View {
        let content: BlockContent
        let width: Double
        let isSelected: Bool
        /// Points the title moves right so it stays on screen while the
        /// block's start is scrolled off to the left.
        var titleInset: Double = 0
        @ScaledMetric(relativeTo: .subheadline) private var size: CGFloat = 14

        var body: some View {
            HStack(spacing: 6) {
                switch content {
                case .programme(let title, _, let startedEarlier):
                    HStack(spacing: 4) {
                        if startedEarlier {
                            Text("◂").font(.system(size: size - 3)).accessibilityHidden(true)
                        }
                        Text(title).lineLimit(1)
                    }
                    .padding(.leading, titleInset)
                case .gap:
                    EmptyView()
                case .placeholder(let text):
                    Text(text).lineLimit(1)
                }
            }
            .font(.system(size: size))
            .foregroundStyle(isDim ? Palette.textMuted : Palette.text)
            .padding(.horizontal, content == .gap ? 0 : 12)
            .frame(width: width, alignment: .leading)
            .frame(maxHeight: .infinity)
            .background(fill, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8).strokeBorder(Palette.accent, lineWidth: 2)
                }
            }
            .clipped()
            .contentShape(Rectangle())
        }

        private var isDim: Bool {
            switch content {
            case .programme(_, let timing, _): timing == .past
            case .gap, .placeholder: true
            }
        }

        private var fill: Color {
            switch content {
            case .gap: .clear
            case .placeholder: Palette.surface(0.06)
            case .programme(_, let timing, _):
                Palette.surface(isSelected ? 0.12 : timing == .past ? 0.06 : 0.08)
            }
        }
    }

    /// The group's name and channel count over the channel column.
    struct GroupTitle: View {
        let title: String
        let count: Int

        var body: some View {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
                Text("\(count)")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.textMuted)
            }
            .foregroundStyle(Palette.text)
            .padding(.trailing, 12)
            .frame(width: GuideZoom.channelColumn, height: headerHeight, alignment: .leading)
            .background(Palette.ground)
            .accessibilityElement(children: .combine)
        }
    }

    /// A half-hour label in the header, with the column's left rule.
    struct ColumnLabel: View {
        let text: String
        let width: Double

        var body: some View {
            Text(text)
                .font(.system(size: 13))
                .monospacedDigit()
                .foregroundStyle(Palette.textMuted)
                .padding(.leading, 8)
                .frame(width: width, height: headerHeight, alignment: .leading)
                .overlay(alignment: .leading) {
                    Rectangle().fill(Palette.surface(0.12)).frame(width: 1)
                }
        }
    }

    /// The accent tag with the time, at the top of the now line.
    struct NowPill: View {
        let time: String

        var body: some View {
            Text(time)
                .font(.system(size: 12, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Palette.ground)
                .fixedSize()
                .padding(.vertical, 3)
                .padding(.horizontal, 7)
                .background(Palette.accent, in: RoundedRectangle(cornerRadius: 6))
        }
    }

    /// The 2 pt accent line at the current time.
    struct NowLine: View {
        var body: some View {
            RoundedRectangle(cornerRadius: 1)
                .fill(Palette.accent)
                .frame(width: 2)
                .frame(maxHeight: .infinity)
                .allowsHitTesting(false)
        }
    }

    /// "No channels in Favorites", muted and centered where the rows go.
    struct Empty: View {
        let text: String

        var body: some View {
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(Palette.textMuted)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview("Guide blocks") {
    VStack(alignment: .leading, spacing: 4) {
        GuideBoard.GroupTitle(title: "Sport", count: 42)
        HStack(spacing: 4) {
            GuideBoard.ChannelCell(number: 104, name: "Sport One", look: .playing) {
                GuideBoard.Initials(text: "S1", look: .playing)
            }
            GuideBoard.Block(
                content: .programme(title: "Premier League: Arsenal v Liverpool", timing: .now, startedEarlier: true), width: 356,
                isSelected: true)
            GuideBoard.Block(
                content: .programme(title: "Match of the Day", timing: .future, startedEarlier: false), width: 266, isSelected: false)
        }
        .frame(height: GuideBoard.rowHeight)
        HStack(spacing: 4) {
            GuideBoard.ChannelCell(number: 105, name: "Sport Two", look: .plain) {
                GuideBoard.Initials(text: "S2", look: .plain)
            }
            GuideBoard.Block(
                content: .programme(title: "La Liga: Pre-match", timing: .past, startedEarlier: false), width: 86, isSelected: false)
            GuideBoard.Block(content: .gap, width: 86, isSelected: false)
            GuideBoard.Block(content: .placeholder(GuideLine.loading), width: 440, isSelected: false)
        }
        .frame(height: GuideBoard.rowHeight)
        HStack(spacing: 0) {
            GuideBoard.ColumnLabel(text: "21:00", width: 180)
            GuideBoard.ColumnLabel(text: "21:30", width: 180)
            GuideBoard.NowPill(time: "21:34")
        }
    }
    .padding()
    .background(Palette.ground)
}
