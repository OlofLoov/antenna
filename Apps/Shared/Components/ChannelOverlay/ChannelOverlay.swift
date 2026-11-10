import SwiftUI

/// The Apple TV channel overlay over live video (tv-channel-overlay
/// capability; `Main`, `Main-Favorites`, `Main-FavoritesEmpty`,
/// `Main-Empty`). Groups 320 wide, channels 700 wide, the now-and-next
/// panel in the rest of a 1600 wide scrim, and the clock top right.
/// Compiles on every platform so the snapshot job renders its previews.
enum ChannelOverlay {
    /// Muted text on the focused white card (design.md deviation "Text muted on focus").
    static let mutedOnFocus = Color(red: 0x4B / 255, green: 0x55 / 255, blue: 0x63 / 255)
    static let tile = Color(red: 0x26 / 255, green: 0x34 / 255, blue: 0x4A / 255)
    static let tileOnFocus = Color(red: 0x1E / 255, green: 0x3A / 255, blue: 0x5F / 255)
    static let tileText = Color(red: 0xD7 / 255, green: 0xDE / 255, blue: 0xE8 / 255)

    /// The three columns over the scrim, with the clock at the top right.
    struct Layout<Groups: View, Channels: View, Panel: View, Clock: View>: View {
        @ViewBuilder var groups: Groups
        @ViewBuilder var channels: Channels
        @ViewBuilder var panel: Panel
        @ViewBuilder var clock: Clock

        var body: some View {
            ZStack(alignment: .topLeading) {
                HStack(spacing: 0) {
                    groups
                        .frame(width: 320)
                    Rectangle()
                        .fill(Palette.surface(0.08))
                        .frame(width: 1)
                    channels
                        .frame(width: 700)
                    panel
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .frame(width: 1600)
                .frame(maxHeight: .infinity)
                .background(Palette.scrimTint.opacity(0.88))
                clock
                    .padding(.top, 44)
                    .padding(.trailing, 64)
                    .frame(maxWidth: .infinity, alignment: .topTrailing)
            }
            .foregroundStyle(Palette.text)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("overlay.root")
        }
    }

    // MARK: Groups

    /// The "Groups" eyebrow, the group rows, and Search at the bottom.
    struct GroupColumn<Rows: View, Search: View>: View {
        @ViewBuilder var rows: Rows
        @ViewBuilder var search: Search

        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                Eyebrow(text: "Groups")
                    .padding(.horizontal, 16)
                    .padding(.bottom, 18)
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) { rows }
                }
                .accessibilityIdentifier("overlay.groups")
                Spacer(minLength: 0)
                search
            }
            .padding(EdgeInsets(top: 48, leading: 40, bottom: 48, trailing: 20))
        }
    }

    /// The 20 pt uppercase muted label over a column.
    struct Eyebrow: View {
        let text: String

        var body: some View {
            Text(text.uppercased())
                .font(.system(size: 20, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(Palette.textMuted)
        }
    }

    /// How a group row looks when it does not have focus.
    enum GroupLook: Equatable, Sendable {
        case plain
        /// The group whose channels the middle column shows: 0.12 surface, weight 600.
        case selected
    }

    /// One group: optional glyph, name, and how many channels it holds.
    struct GroupRow: View {
        let title: String
        var systemImage: String?
        let count: Int
        let look: GroupLook
        let select: () -> Void

        var body: some View {
            Button(action: select) {
                HStack(spacing: 14) {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .font(.system(size: 24))
                            .accessibilityHidden(true)
                    }
                    Text(title)
                        .lineLimit(1)
                    Spacer(minLength: 12)
                    CountText(count: count)
                }
            }
            .buttonStyle(GroupStyle(look: look, size: 29))
            .accessibilityAddTraits(look == .selected ? .isSelected : [])
            .accessibilityValue(String(count))
        }
    }

    /// The Search entry at the bottom of the group column.
    struct SearchRow: View {
        let open: () -> Void

        var body: some View {
            Button(action: open) {
                HStack(spacing: 14) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 24))
                        .accessibilityHidden(true)
                    Text("Search")
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(GroupStyle(look: .plain, size: 26, muted: true))
        }
    }

    private struct CountText: View {
        let count: Int
        @Environment(\.isFocused) private var isFocused

        var body: some View {
            Text(String(count))
                .font(.system(size: 22))
                .monospacedDigit()
                .foregroundStyle(isFocused ? ChannelOverlay.mutedOnFocus : Palette.textMuted)
        }
    }

    private struct GroupStyle: ButtonStyle {
        let look: GroupLook
        let size: CGFloat
        var muted = false

        func makeBody(configuration: Configuration) -> some View {
            GroupLabel(label: configuration.label, look: look, size: size, muted: muted)
        }
    }

    private struct GroupLabel<Label: View>: View {
        let label: Label
        let look: GroupLook
        let size: CGFloat
        let muted: Bool
        @Environment(\.isFocused) private var isFocused

        var body: some View {
            label
                .font(.system(size: size, weight: isFocused || look == .selected ? .semibold : .regular))
                .foregroundStyle(isFocused ? Palette.ground : muted ? Palette.textMuted : Palette.text)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                .background(fill, in: RoundedRectangle(cornerRadius: 12))
                .shadow(color: isFocused ? Palette.focusShadow : .clear, radius: 16, y: 12)
        }

        private var fill: Color {
            if isFocused { return Palette.focus }
            return look == .selected ? Palette.surface(0.12) : .clear
        }
    }

    // MARK: Channels

    /// The group's name over its sort order, then the rows.
    struct ChannelColumn<Rows: View>: View {
        let title: String
        let order: String
        @ViewBuilder var rows: Rows

        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Eyebrow(text: title)
                    Spacer(minLength: 12)
                    Text(order)
                        .font(.system(size: 20))
                        .foregroundStyle(Palette.textMuted)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("overlay.channelsHeader")
                rows
            }
            .padding(.vertical, 48)
            .padding(.horizontal, 24)
        }
    }

    /// Number, logo tile, name, and the programme part under it (one row
    /// anatomy, design-system/channel-rows-share-one-anatomy). 92 tall, 100
    /// when focused.
    struct ChannelRow<Logo: View, Programme: View>: View {
        let number: Int?
        let name: String
        let select: () -> Void
        @ViewBuilder var logo: Logo
        @ViewBuilder var programme: Programme

        var body: some View {
            Button(action: select) {
                HStack(spacing: 20) {
                    NumberText(number: number)
                    logo
                        .frame(width: 76, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(name)
                            .font(.system(size: 29))
                            .lineLimit(1)
                            .layoutPriority(1)
                        programme
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .buttonStyle(RowStyle())
        }
    }

    private struct NumberText: View {
        let number: Int?
        @Environment(\.isFocused) private var isFocused

        var body: some View {
            Text(number.map(String.init) ?? "")
                .font(.system(size: 24))
                .monospacedDigit()
                .foregroundStyle(isFocused ? ChannelOverlay.mutedOnFocus : Palette.textMuted)
                .frame(width: 52, alignment: .leading)
        }
    }

    private struct RowStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            RowLabel(label: configuration.label)
        }
    }

    private struct RowLabel<Label: View>: View {
        let label: Label
        @Environment(\.isFocused) private var isFocused

        var body: some View {
            label
                .fontWeight(isFocused ? .semibold : .regular)
                .foregroundStyle(isFocused ? Palette.ground : Palette.text)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity, minHeight: isFocused ? 100 : 92, alignment: .leading)
                .background(isFocused ? Palette.focus : .clear, in: RoundedRectangle(cornerRadius: 14))
                .shadow(color: isFocused ? Palette.focusShadow : .clear, radius: 16, y: 12)
        }
    }

    /// The tile drawn while a logo is missing, loading or failed
    /// (design-system/channels-without-a-logo-show-initials).
    struct Initials: View {
        let text: String
        @Environment(\.isFocused) private var isFocused

        var body: some View {
            ZStack {
                isFocused ? ChannelOverlay.tileOnFocus : ChannelOverlay.tile
                Text(text)
                    .font(.system(size: 16, weight: .bold))
                    .kerning(1)
                    .foregroundStyle(isFocused ? Palette.text : ChannelOverlay.tileText)
            }
            .accessibilityValue(text)
        }
    }
}

// MARK: Previews

private struct OverlayPreview: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(red: 0x1A / 255, green: 0x25 / 255, blue: 0x35 / 255)
            ChannelOverlay.Layout {
                ChannelOverlay.GroupColumn {
                    ChannelOverlay.GroupRow(title: "Favorites", systemImage: "star", count: 3, look: .plain) {}
                    ChannelOverlay.GroupRow(title: "All channels", count: 369, look: .plain) {}
                    ChannelOverlay.GroupRow(title: "Sport", count: 42, look: .selected) {}
                    ChannelOverlay.GroupRow(title: "News", count: 36, look: .plain) {}
                    ChannelOverlay.GroupRow(title: "Kids", count: 27, look: .plain) {}
                } search: {
                    ChannelOverlay.SearchRow {}
                }
            } channels: {
                ChannelOverlay.ChannelColumn(title: "Sport", order: "Sorted by number") {
                    ForEach(Array(["Eurosport 1", "Eurosport 2", "Sport One", "Sport Two"].enumerated()), id: \.offset) { index, name in
                        ChannelOverlay.ChannelRow(number: 101 + index, name: name, select: {}) {
                            ChannelOverlay.Initials(text: String(name.prefix(2)).uppercased())
                        } programme: {
                            EmptyView()
                        }
                    }
                }
            } panel: {
                EmptyView()
            } clock: {
                ShellTabBar.Clock(date: Date(timeIntervalSince1970: 1_800_000_000))
            }
        }
    }
}

#Preview("Channel overlay, a group selected", traits: .fixedLayout(width: 1920, height: 1080)) {
    OverlayPreview()
}

#Preview("Channel overlay, Favorites in your order", traits: .fixedLayout(width: 1920, height: 1080)) {
    ZStack(alignment: .topLeading) {
        Color(red: 0x1A / 255, green: 0x25 / 255, blue: 0x35 / 255)
        ChannelOverlay.Layout {
            ChannelOverlay.GroupColumn {
                ChannelOverlay.GroupRow(title: "Favorites", systemImage: "star", count: 2, look: .selected) {}
                ChannelOverlay.GroupRow(title: "All channels", count: 12, look: .plain) {}
            } search: {
                ChannelOverlay.SearchRow {}
            }
        } channels: {
            ChannelOverlay.ChannelColumn(title: "Favorites", order: "Your order") {
                ChannelOverlay.ChannelRow(number: 7, name: "News 24", select: {}) {
                    ChannelOverlay.Initials(text: "N2")
                } programme: {
                    EmptyView()
                }
            }
        } panel: {
            EmptyView()
        } clock: {
            ShellTabBar.Clock(date: Date(timeIntervalSince1970: 1_800_000_000))
        }
    }
}
