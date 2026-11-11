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
    /// Four half-hour columns.
    static let window = GuideTimeline.columnWidth * Double(GuideTimeline.visibleColumns)
    static let rowSpacing = 6.0
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
                .padding(.top, 48)
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
        /// The four column labels, "20:00" to "21:30".
        let columns: [String]
        let now: NowMark?
        @ViewBuilder var days: Days
        @ViewBuilder var rows: Rows

        var body: some View {
            VStack(alignment: .leading, spacing: rowSpacing) {
                HStack(spacing: 0) {
                    days
                        .frame(width: channelColumn + GuideRowLayout.gap, alignment: .leading)
                    ForEach(Array(zip(columns.indices, columns)), id: \.0) { _, label in
                        ColumnLabel(text: label)
                    }
                }
                .frame(height: 52)
                rows
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .overlay(alignment: .topLeading) {
                if let now {
                    NowLine(time: now.time)
                        .offset(x: channelColumn + GuideRowLayout.gap + now.offset)
                }
            }
            .clipped()
        }
    }

    private struct ColumnLabel: View {
        let text: String

        var body: some View {
            Text(text)
                .font(.system(size: 22))
                .monospacedDigit()
                .foregroundStyle(Palette.textMuted)
                .padding(.leading, 12)
                .frame(width: GuideTimeline.columnWidth, height: 52, alignment: .leading)
                .overlay(alignment: .leading) {
                    Rectangle().fill(Palette.surface(0.12)).frame(width: 1)
                }
                .accessibilityIdentifier("guide.column")
        }
    }

    /// The 3 pt accent line with the time on a tag at its top.
    private struct NowLine: View {
        let time: String

        var body: some View {
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Palette.accent)
                    .frame(width: 3)
                    .frame(maxHeight: .infinity)
                Text(time)
                    .font(.system(size: 18, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Palette.ground)
                    .fixedSize()
                    .padding(.vertical, 4)
                    .padding(.horizontal, 10)
                    .background(Palette.accent, in: RoundedRectangle(cornerRadius: 6))
                    .padding(.top, 8)
            }
            .frame(width: 3)
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
            Button(title, action: pick)
                .buttonStyle(DayStyle(look: look))
                .accessibilityAddTraits(look == .selected ? .isSelected : [])
        }
    }

    private struct DayStyle: ButtonStyle {
        let look: DayLook

        func makeBody(configuration: Configuration) -> some View {
            DayLabel(label: configuration.label, look: look)
        }
    }

    private struct DayLabel<Label: View>: View {
        let label: Label
        let look: DayLook
        @Environment(\.isFocused) private var isFocused

        var body: some View {
            label
                .font(.system(size: 20, weight: isFocused || look == .selected ? .semibold : .regular))
                .foregroundStyle(isFocused ? Palette.ground : look == .selected ? Palette.text : Palette.textMuted)
                .lineLimit(1)
                .fixedSize()
                .padding(.vertical, 6)
                .padding(.horizontal, 14)
                .background(background, in: RoundedRectangle(cornerRadius: 8))
                .shadow(color: isFocused ? Palette.focusShadow : .clear, radius: 16, y: 12)
        }

        private var background: Color {
            if isFocused { return Palette.focus }
            return look == .selected ? Palette.surface(0.12) : .clear
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
        let number: Int?
        let name: String
        let look: ChannelLook
        @ViewBuilder var logo: Logo

        var body: some View {
            HStack(spacing: 16) {
                Text(number.map(String.init) ?? "")
                    .font(.system(size: 20))
                    .monospacedDigit()
                    .foregroundStyle(Palette.textMuted)
                    .frame(width: 44, alignment: .leading)
                logo
                    .frame(width: 64, height: 42)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                Text(name)
                    .font(.system(size: 24, weight: look == .playing ? .semibold : .regular))
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
                    .font(.system(size: 14, weight: .bold))
                    .kerning(1)
                    .foregroundStyle(look == .playing ? Palette.text : ChannelOverlay.tileText)
            }
        }
    }

    /// The muted line in place of the rows when the group has no channels.
    struct Empty: View {
        let text: String

        var body: some View {
            Text(text)
                .font(.system(size: 24))
                .foregroundStyle(Palette.textMuted)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("guide.empty")
        }
    }
}
