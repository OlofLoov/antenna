import AntennaCore
import SwiftUI

/// The Apple TV guide grid (tv-guide-grid capability; `TV-Guide`,
/// `TV-Guide-Future`, `TV-Guide-Placeholders`, `TV-Guide-Empty`): the small
/// picture and the panel on top, then the day chips, the time header and
/// one row per channel, with the now line over them. Compiles on every
/// platform so the snapshot job renders its previews.
enum GuideGrid {
    /// The channel column; with the 4 pt gap it is the board's 300 pt.
    static let channelColumn = 296.0
    /// The width the half-hour columns share, whatever the Guide window.
    static let window = GuideTimeline.windowWidth
    static let rowSpacing = 6.0
    /// The small picture's top edge: below the tab bar's band, so the bar
    /// sits where it does on every other tab when it shows over the guide.
    static let pictureTop = SystemTabBar.bottom + 16
    /// Muted text on the white focus card.
    static let mutedOnFocus = ChannelOverlay.mutedOnFocus

    /// The picture and panel on top, the grid below.
    struct Screen<Picture: View, Panel: View, Grid: View>: View {
        @ViewBuilder var picture: Picture
        @ViewBuilder var panel: Panel
        @ViewBuilder var grid: Grid

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 40) {
                    picture
                        .frame(width: 480, height: 270)
                    panel
                        .padding(.top, 6)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .padding(.top, pictureTop)
                .padding(.bottom, 28)
                grid
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.bottom, 40)
            }
            .padding(.horizontal, 64)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .foregroundStyle(Palette.text)
        }
    }

    /// Where the now line is drawn and the time on its label.
    struct NowMark: Equatable {
        /// Points from the window's left edge.
        let offset: Double
        let time: String
    }

    /// The day chips and time header over the rows, with the now line on top.
    struct Grid<Days: View, Rows: View>: View {
        /// The column labels, "20:00" to "21:30" at two hours. They share
        /// the window's width, so more hours make each column narrower.
        let columns: [String]
        let now: NowMark?
        @ViewBuilder var days: Days
        @ViewBuilder var rows: Rows
        /// The drawn width of each label's text and of the now tag, so a
        /// label under the tag can be left out.
        @State private var labelWidths: [Int: Double] = [:]
        @State private var tagWidth = 0.0

        private var columnWidth: Double { window / Double(max(1, columns.count)) }

        /// The labels the now tag covers (tv-guide-grid/the-grid-opens-around-now-and-keeps-time).
        private var covered: Set<Int> {
            guard let now, tagWidth > 0 else { return [] }
            return GuideTimeline.labelsUnderTag(
                line: now.offset + NowLine.width / 2, tagWidth: tagWidth, columnWidth: columnWidth,
                labelWidths: columns.indices.map { labelWidths[$0] ?? 0 }, inset: ColumnLabel.inset, gap: 8)
        }

        var body: some View {
            VStack(alignment: .leading, spacing: rowSpacing) {
                HStack(spacing: 0) {
                    days
                        .frame(width: channelColumn + GuideRowLayout.gap, alignment: .leading)
                    ForEach(Array(zip(columns.indices, columns)), id: \.0) { index, label in
                        ColumnLabel(text: label, width: columnWidth, isCovered: covered.contains(index)) {
                            labelWidths[index] = $0
                        }
                    }
                }
                .frame(height: 52)
                rows
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .overlay(alignment: .topLeading) {
                if let now {
                    NowLine(time: now.time) { tagWidth = $0 }
                        .offset(x: channelColumn + GuideRowLayout.gap + now.offset)
                }
            }
            .clipped()
        }
    }

    private struct ColumnLabel: View {
        /// From the column's rule to the start of its text.
        static let inset = 12.0

        let text: String
        let width: Double
        /// True while the now tag sits over the text. The label keeps its
        /// place and what VoiceOver reads, and draws no text.
        let isCovered: Bool
        let measured: (Double) -> Void

        var body: some View {
            Text(text)
                .font(.boardStyle(22))
                .monospacedDigit()
                .foregroundStyle(isCovered ? Color.clear : Palette.textMuted)
                .lineLimit(1)
                .onGeometryChange(for: Double.self, of: { $0.size.width }, action: measured)
                .padding(.leading, Self.inset)
                .frame(width: width, height: 52, alignment: .leading)
                .overlay(alignment: .leading) {
                    Rectangle().fill(Palette.surface(0.12)).frame(width: 1)
                }
                .accessibilityIdentifier("guide.column")
        }
    }

    /// The 3 pt accent line with the time on a tag at its top.
    private struct NowLine: View {
        static let width = 3.0

        let time: String
        let measured: (Double) -> Void

        var body: some View {
            ZStack(alignment: .top) {
                cornerShape(.small)
                    .fill(Palette.accent)
                    .frame(width: Self.width)
                    .frame(maxHeight: .infinity)
                Text(time)
                    .font(.boardStyle(18, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Palette.ground)
                    .fixedSize()
                    .padding(.vertical, 4)
                    .padding(.horizontal, 10)
                    .background(Palette.accent, in: cornerShape(.small))
                    .onGeometryChange(for: Double.self, of: { $0.size.width }, action: measured)
                    .padding(.top, 8)
            }
            .frame(width: Self.width)
            .accessibilityElement()
            .accessibilityLabel("Now, \(time)")
            .accessibilityIdentifier("guide.nowLine")
            .allowsHitTesting(false)
        }
    }

    /// How a day chip looks when it does not have focus.
    enum DayLook: Equatable, Sendable {
        case plain
        /// The day the window shows.
        case selected
    }

    /// One day in the list along the top: "Today", "Tue".
    struct DayChip: View {
        let title: String
        let look: DayLook
        let pick: () -> Void

        var body: some View {
            Button(action: pick) {
                Text(verbatim: title)
                    .font(.boardStyle(20, weight: look == .selected ? .semibold : .regular))
                    .lineLimit(1)
                    .fixedSize()
            }
            .chipStyle(isPicked: look == .selected)
            .accessibilityAddTraits(look == .selected ? .isSelected : [])
        }
    }

    /// One channel's row: its cell, then the blocks the caller places in
    /// the window by their leading edge. The window clips what overhangs.
    struct Row<Cell: View, Blocks: View>: View {
        @ViewBuilder var cell: Cell
        @ViewBuilder var blocks: Blocks

        var body: some View {
            HStack(spacing: GuideRowLayout.gap) {
                cell
                    .frame(width: channelColumn, alignment: .leading)
                ZStack(alignment: .topLeading) {
                    blocks
                }
                .frame(width: window, height: GuideRowLayout.rowHeight, alignment: .topLeading)
                .clipped()
            }
            .frame(height: GuideRowLayout.rowHeight)
            .accessibilityElement(children: .contain)
        }
    }

    /// How a channel cell looks.
    enum ChannelLook: Equatable, Sendable {
        case plain
        /// The channel in the small picture: bold name, brighter tile.
        case playing
    }

    /// The channel's number, logo or initials, and name. Takes no focus.
    struct ChannelCell<Logo: View>: View {
        let number: ChannelNumber?
        let name: String
        let look: ChannelLook
        @ViewBuilder var logo: Logo

        var body: some View {
            HStack(spacing: 16) {
                ChannelNumberText(number)
                    .font(.boardStyle(20))
                    .monospacedDigit()
                    .foregroundStyle(Palette.textMuted)
                    .frame(width: 44, alignment: .leading)
                logo
                    .frame(width: 64, height: 42)
                    .clipShape(cornerShape(.small))
                Text(name)
                    .font(.boardStyle(24, weight: look == .playing ? .semibold : .regular))
                    .lineLimit(1)
            }
            .padding(.trailing, 16)
            .accessibilityElement(children: .combine)
            .accessibilityValue(look == .playing ? "playing" : "")
        }
    }

    /// The tile drawn in place of a missing logo (design-system/channels-without-a-logo-show-initials).
    struct Initials: View {
        let text: String
        let look: ChannelLook

        var body: some View {
            ZStack {
                look == .playing ? ChannelOverlay.tileOnFocus : ChannelOverlay.tile
                Text(text)
                    .font(.boardStyle(14, weight: .bold))
                    .letterSpacing(1)
                    .foregroundStyle(look == .playing ? Palette.text : ChannelOverlay.tileText)
            }
        }
    }

    /// The muted line in place of the rows when the group has no channels.
    struct Empty: View {
        let text: LocalizedStringResource

        var body: some View {
            Text(text)
                .font(.boardStyle(24))
                .foregroundStyle(Palette.textMuted)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("guide.empty")
        }
    }
}
