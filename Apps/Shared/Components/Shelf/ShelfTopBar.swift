#if os(iOS) || os(macOS)
    import AntennaCore
    import SwiftUI

    /// The bar pinned at the top of Movies and Series on iPhone and in a
    /// narrow iPad window (`iPhone-Movies`;
    /// movies-and-series-browsing/a-pinned-top-bar-on-iphone): the section's
    /// name, the genre button and the profile button in one 44 pt row. It
    /// draws nothing behind them. The screen sets it as the scroll view's top
    /// bar, where the system's scroll edge effect blurs the rows passing
    /// under it, so the bar needs no glass or fill of its own
    /// (design-system/liquid-glass-stays-on-the-navigation-layer).
    struct ShelfTopBar<Genres: View, ProfileButton: View>: View {
        let title: LocalizedStringResource
        @ViewBuilder var genres: Genres
        @ViewBuilder var profile: ProfileButton
        @Environment(\.shelfPrefix) private var prefix

        var body: some View {
            HStack(spacing: 8) {
                Text(title)
                    .font(.boardStyle(28, weight: .bold))
                    .foregroundStyle(Palette.text)
                    .lineLimit(1)
                    .fixedSize()
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("\(prefix).title")
                genres
                Spacer(minLength: 0)
                profile
            }
            .frame(minHeight: 44)
            .padding(.leading, 16)
            .padding(.trailing, 12)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("\(prefix).bar")
        }
    }

    /// The open list in the top bar: its name, its count and a chevron on a
    /// glass capsule, the system glass button style with no fill, outline or
    /// shadow of its own (design-system/liquid-glass-stays-on-the-navigation-layer).
    /// The name gives way before the count and the chevron.
    struct ShelfCategoryButton: View {
        let name: String
        let count: Int
        let open: () -> Void

        var body: some View {
            Button(action: open) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(verbatim: name)
                        .font(.headline)
                        .foregroundStyle(Palette.text)
                        .lineLimit(1)
                    Group {
                        Text(verbatim: "·")
                        Text(count, format: .number)
                            .monospacedDigit()
                        Image(systemName: "chevron.down")
                            .font(.footnote.weight(.semibold))
                    }
                    .font(.subheadline)
                    .foregroundStyle(Palette.textMuted)
                    .fixedSize()
                }
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
        }
    }

    #Preview("Top bar, iPhone", traits: .fixedLayout(width: 390, height: 60)) {
        ShelfTopBar(title: "Movies") {
            ShelfCategoryButton(name: "All movies", count: 214) {}
        } profile: {
            ProfileCornerLabel(tile: ProfileTile(id: Profile.mainID, name: "Kids", initial: "K", color: Profile.colors[5]))
        }
        .frame(maxHeight: .infinity)
        .background(Palette.ground)
    }

    #Preview("Top bar, iPhone, long genre", traits: .fixedLayout(width: 320, height: 60)) {
        ShelfTopBar(title: "Series") {
            ShelfCategoryButton(name: "EN | Action & Adventure", count: 1_284) {}
        } profile: {
            ProfileCornerLabel(tile: nil)
        }
        .environment(\.shelfPrefix, "series")
        .frame(maxHeight: .infinity)
        .background(Palette.ground)
    }

    #Preview("Top bar, iPhone, Arabic", traits: .fixedLayout(width: 390, height: 60)) {
        ShelfTopBar(title: "Movies") {
            ShelfCategoryButton(name: "كل الأفلام", count: 214) {}
        } profile: {
            ProfileCornerLabel(tile: nil)
        }
        .frame(maxHeight: .infinity)
        .background(Palette.ground)
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.locale, Locale(identifier: "ar"))
    }
#endif
