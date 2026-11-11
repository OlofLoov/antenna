import AntennaCore
import SwiftUI

/// What the banner's parts share: the title on show, its place among the
/// banner's titles and what the buttons do
/// (movies-and-series-browsing/new-titles-up-front).
struct BannerContext {
    struct State {
        var text: BannerText
        /// The backdrop, else the poster.
        var artURL: URL?
        var isOnMyList: Bool
        var index: Int
        var count: Int
    }

    struct Actions {
        var play: () -> Void
        /// Does nothing until the title detail page exists.
        var moreInfo: () -> Void
        var toggleMyList: () -> Void
        /// Moves by a number of titles, wrapping.
        var page: (Int) -> Void
        /// Shows the title at an index.
        var show: (Int) -> Void
        /// True while a finger, the pointer or focus is on the banner.
        var interacting: (Bool) -> Void
    }

    var state: State
    var actions: Actions
}

extension EnvironmentValues {
    /// Set by the Movies and Series screens around the banner.
    @Entry var shelfBanner: BannerContext?
}

/// The banner at the top of the section, one arrangement per board.
enum ShelfBanner {
    /// The board's sizes for the banner's type and buttons.
    struct Sizes: Equatable {
        var eyebrow: CGFloat
        var title: CGFloat
        var facts: CGFloat
        var badge: CGFloat
        var description: CGFloat
        var button: CGFloat
        var buttonHeight: CGFloat
        var spacing: CGFloat

        static let phone = Sizes(
            eyebrow: 11, title: 30, facts: 13, badge: 10, description: 14, button: 15, buttonHeight: 44,
            spacing: 8)
        static let pad = Sizes(eyebrow: 12, title: 40, facts: 14, badge: 11, description: 15, button: 15, buttonHeight: 44, spacing: 12)
        static let tv = Sizes(eyebrow: 20, title: 76, facts: 24, badge: 17, description: 26, button: 26, buttonHeight: 70, spacing: 22)
    }

    /// The artwork, scaled to fill, on the board's placeholder color.
    struct Art: View {
        @Environment(\.shelfBanner) private var banner
        @Environment(\.posterLoader) private var loader
        @State private var poster: Poster?

        var body: some View {
            ZStack {
                Color(red: 0x22 / 255, green: 0x30 / 255, blue: 0x4A / 255)
                if let image = poster?.image {
                    Image(decorative: image, scale: 1).resizable().scaledToFill()
                }
            }
            .clipped()
            .accessibilityHidden(true)
            .task(id: banner?.state.artURL) {
                poster = nil
                guard let url = banner?.state.artURL, let loader else { return }
                poster = await loader.load(url)
            }
        }
    }

    /// "Recently added · Thriller" in the accent color, uppercase.
    struct Eyebrow: View {
        let type: Sizes
        @Environment(\.shelfBanner) private var banner

        var body: some View {
            if let text = banner?.state.text.eyebrow {
                Text(text.uppercased())
                    .font(.system(size: type.eyebrow, weight: .semibold))
                    .tracking(type.eyebrow / 8)
                    .foregroundStyle(Palette.accent)
                    .lineLimit(1)
            }
        }
    }

    struct Title: View {
        let type: Sizes
        @Environment(\.shelfBanner) private var banner
        @Environment(\.shelfPrefix) private var prefix

        var body: some View {
            if let text = banner?.state.text.title {
                Text(text)
                    .font(.system(size: type.title, weight: .heavy))
                    .foregroundStyle(Palette.text)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("\(prefix).hero.title")
            }
        }
    }

    /// The year and length or seasons between dots, then the outlined badges.
    struct Facts: View {
        let type: Sizes
        @Environment(\.shelfBanner) private var banner

        var body: some View {
            if let text = banner?.state.text, !(text.facts.isEmpty && text.badges.isEmpty) {
                HStack(spacing: type.facts / 2) {
                    ForEach(Array(zip(text.facts.indices, text.facts)), id: \.0) { index, fact in
                        if index > 0 { Dot(size: type.facts / 5) }
                        Text(fact)
                    }
                    ForEach(text.badges, id: \.self) { badge in
                        Badge(text: badge, size: type.badge)
                    }
                }
                .font(.system(size: type.facts))
                .foregroundStyle(Browse.textSecondary)
                .accessibilityElement(children: .combine)
            }
        }
    }

    private struct Dot: View {
        let size: CGFloat

        var body: some View {
            Circle().fill(Palette.textMuted).frame(width: size, height: size).accessibilityHidden(true)
        }
    }

    /// An outlined badge: "4K", an age rating or "SERIES". Up to 2 pt under
    /// the caption floor, as design.md allows.
    struct Badge: View {
        let text: String
        let size: CGFloat

        var body: some View {
            Text(text)
                .font(.system(size: size, weight: .bold))
                .tracking(1)
                .foregroundStyle(Palette.text)
                .padding(.vertical, size / 5)
                .padding(.horizontal, size / 2)
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Palette.textMuted, lineWidth: 1.5))
        }
    }

    struct Description: View {
        let type: Sizes
        let lines: Int
        @Environment(\.shelfBanner) private var banner

        var body: some View {
            if let text = banner?.state.text.description {
                Text(text)
                    .font(.system(size: type.description))
                    .lineSpacing(type.description * 0.3)
                    .foregroundStyle(Browse.textSecondary)
                    .lineLimit(lines)
            }
        }
    }

    /// The white Play button.
    struct PlayButton: View {
        let type: Sizes
        @Environment(\.shelfBanner) private var banner
        @Environment(\.shelfPrefix) private var prefix

        var body: some View {
            Button {
                banner?.actions.play()
            } label: {
                Label("Play", systemImage: "play.fill")
                    .font(.system(size: type.button, weight: .bold))
                    .padding(.horizontal, type.button * 1.3)
                    .frame(maxWidth: .infinity, minHeight: type.buttonHeight)
            }
            .buttonStyle(BannerButtonStyle(fill: .primary))
            .accessibilityIdentifier("\(prefix).hero.play")
        }
    }

    /// More info: shown, but inert until the detail page exists.
    struct InfoButton: View {
        let type: Sizes
        let title: String
        @Environment(\.shelfBanner) private var banner
        @Environment(\.shelfPrefix) private var prefix

        var body: some View {
            Button {
                banner?.actions.moreInfo()
            } label: {
                Text(title)
                    .font(.system(size: type.button, weight: .semibold))
                    .padding(.horizontal, type.button * 1.2)
                    .frame(minHeight: type.buttonHeight)
            }
            .buttonStyle(BannerButtonStyle(fill: .secondary))
            .accessibilityIdentifier("\(prefix).hero.info")
        }
    }

    /// Plus to add, check to remove (movies-and-series-browsing/keep-a-list-for-later).
    struct MyListButton: View {
        let type: Sizes
        @Environment(\.shelfBanner) private var banner
        @Environment(\.shelfPrefix) private var prefix

        var body: some View {
            let added = banner?.state.isOnMyList ?? false
            Button {
                banner?.actions.toggleMyList()
            } label: {
                Image(systemName: added ? "checkmark" : "plus")
                    .font(.system(size: type.button + 2, weight: .bold))
                    .frame(width: type.buttonHeight, height: type.buttonHeight)
            }
            .buttonStyle(BannerButtonStyle(fill: .secondary))
            .accessibilityLabel(added ? "Remove from My list" : "Add to My list")
            .accessibilityValue(added ? "On My list" : "Not on My list")
            .accessibilityIdentifier("\(prefix).hero.myList")
        }
    }

    /// One dot per title, the shown one long. Tapping a dot shows its title.
    struct Dots: View {
        let size: CGFloat
        @Environment(\.shelfBanner) private var banner
        @Environment(\.shelfPrefix) private var prefix

        var body: some View {
            if let banner, banner.state.count > 1 {
                HStack(spacing: 0) {
                    ForEach(0..<banner.state.count, id: \.self) { index in
                        Button {
                            banner.actions.show(index)
                        } label: {
                            Capsule()
                                .fill(index == banner.state.index ? Palette.text : Palette.surface(0.4))
                                .frame(width: index == banner.state.index ? size * 4 : size, height: size)
                                .frame(minWidth: 22, minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .focusable(false)
                        .accessibilityHidden(true)
                    }
                }
                .accessibilityElement()
                .accessibilityLabel("Banner")
                .accessibilityValue("\(banner.state.index + 1) of \(banner.state.count)")
                .accessibilityAdjustableAction { direction in
                    banner.actions.page(direction == .increment ? 1 : -1)
                }
                .accessibilityIdentifier("\(prefix).hero.pager")
            }
        }
    }

    /// The fills of `iPad-Movies`: white with dark text for Play, the 0.14
    /// surface for the others. On Apple TV the focused button takes the
    /// white card (design-system/focus-is-the-lifted-white-card).
    struct BannerButtonStyle: ButtonStyle {
        enum Fill { case primary, secondary }
        let fill: Fill

        func makeBody(configuration: Configuration) -> some View {
            BannerButtonLabel(label: configuration.label, fill: fill, isPressed: configuration.isPressed)
        }
    }

    private struct BannerButtonLabel<Label: View>: View {
        let label: Label
        let fill: BannerButtonStyle.Fill
        let isPressed: Bool
        @Environment(\.isFocused) private var isFocused

        var body: some View {
            let white = fill == .primary || isFocused
            label
                .foregroundStyle(white ? Palette.ground : Palette.text)
                .background(white ? Palette.focus : Palette.surface(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: isFocused ? Palette.focusShadow : .clear, radius: 16, y: 12)
                .scaleEffect(isFocused ? 1.06 : 1)
                .opacity(isPressed ? 0.7 : 1)
                .animation(.easeOut(duration: 0.15), value: isFocused)
        }
    }
}
