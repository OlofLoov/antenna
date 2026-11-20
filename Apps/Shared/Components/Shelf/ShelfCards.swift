import AntennaCore
import SwiftUI

extension ShelfView {
    /// A Continue watching card (`iPhone-Movies`, `iPad-Movies`, `TV-Movies`):
    /// the art at 16:9 with the progress bar along its foot and, for a series,
    /// the SERIES badge, then the name and the caption under it
    /// (movies-and-series-browsing/continue-watching).
    struct ProgressCard: View {
        let title: ShelfTitle
        /// "52 min left", "S2 E4" or "Next episode".
        let caption: String?
        /// How far into the movie or episode, 0 to 1.
        let fraction: Double
        let select: () -> Void
        @Environment(\.shelfMetrics) private var metrics
        @Environment(\.shelfPrefix) private var prefix
        @Environment(\.locale) private var locale

        var body: some View {
            #if os(tvOS)
                // The card style draws its platter behind the whole label,
                // so the name sits under the button, as `TV-Movies` draws it.
                VStack(alignment: .leading, spacing: metrics.headerSpacing * 0.6) {
                    Button(action: select) { art }
                        .posterButtonStyle()
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(spokenLabel)
                        .accessibilityIdentifier("\(prefix).card.\(title.id)")
                    name
                        .accessibilityHidden(true)
                }
            #else
                Button(action: select) {
                    VStack(alignment: .leading, spacing: metrics.headerSpacing * 0.6) {
                        art
                        name
                    }
                }
                .posterButtonStyle()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(spokenLabel)
                .accessibilityIdentifier("\(prefix).card.\(title.id)")
            #endif
        }

        private var spokenLabel: String {
            [title.name, caption].compactMap(\.self).joined(separator: ", ")
        }

        private var art: some View {
            LandscapeArt(name: title.name, url: title.posterURL)
                .frame(width: metrics.card.width, height: metrics.card.height)
                .overlay(alignment: .bottom) { bar }
                .overlay(alignment: .topLeading) {
                    if title.kind == .series {
                        ShelfBanner.Badge(text: "SERIES", size: max(10, metrics.count - 3))
                            .background(Palette.scrimTint.opacity(0.72), in: cornerShape(.small))
                            .padding(metrics.corner * 0.7)
                            .accessibilityIdentifier("\(prefix).card.\(title.id).badge")
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: metrics.corner, style: .continuous))
        }

        private var name: some View {
            Text([title.name, caption].compactMap(\.self).joinedAsDetail(locale))
                .font(.boardStyle(metrics.caption))
                .foregroundStyle(Browse.textSecondary)
                .lineLimit(1)
                .frame(width: metrics.card.width, alignment: .leading)
        }

        private var bar: some View {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Palette.surface(0.22))
                    Rectangle().fill(Palette.accent).frame(width: proxy.size.width * min(1, max(0, fraction)))
                }
            }
            .frame(height: metrics.progress)
            .accessibilityHidden(true)
        }
    }

    /// The poster scaled to fill a wide frame, or the name on the plain tile.
    struct LandscapeArt: View {
        let name: String
        let url: URL?
        @Environment(\.posterLoader) private var loader
        @Environment(\.shelfMetrics) private var metrics
        @State private var poster: Poster?

        var body: some View {
            FilledArt(image: poster?.image, background: Browse.tile) {
                Text(name)
                    .font(.boardStyle(metrics.caption + 2, weight: .semibold))
                    .foregroundStyle(Palette.text)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(10)
            }
            .task(id: url) {
                poster = nil
                guard let url, let loader else { return }
                poster = await loader.load(url)
            }
        }
    }

    /// "See all" at the end of a row's header. `identifier` defaults to
    /// Continue watching's `<prefix>.seeAll`. The tap area reaches past the
    /// text without making the header taller: a 44-point frame in the
    /// baseline-aligned header froze the app when a poster's menu removed
    /// the row above it.
    struct SeeAllButton: View {
        var identifier: String?
        let open: () -> Void
        @Environment(\.shelfMetrics) private var metrics
        @Environment(\.shelfPrefix) private var prefix

        var body: some View {
            Button(action: open) {
                Text("See all")
                    .font(.boardStyle(metrics.count))
                    .foregroundStyle(Palette.textMuted)
                    .padding(.vertical, Self.reach)
                    .contentShape(Rectangle())
                    .padding(.vertical, -Self.reach)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(identifier ?? "\(prefix).seeAll")
        }

        private static let reach: CGFloat = 14
    }

    /// "See all" as a poster-sized tile after a row's last poster, where
    /// focus can reach it on Apple TV (`TV-Movies-Discover`).
    struct SeeAllTile: View {
        let open: () -> Void
        @Environment(\.shelfMetrics) private var metrics

        var body: some View {
            Button(action: open) {
                Text("See all")
                    .font(.boardStyle(metrics.header, weight: .semibold))
                    .foregroundStyle(Palette.text)
                    .frame(width: metrics.poster.width, height: metrics.poster.height)
                    .background(Palette.surface(0.08), in: RoundedRectangle(cornerRadius: metrics.corner, style: .continuous))
            }
            .posterButtonStyle()
        }
    }

    /// The poster menu's More info item, which opens a movie's page
    /// (title-detail-and-episode-picker/open-a-movie-s-page).
    struct MoreInfoMenuItem: View {
        let open: () -> Void
        @Environment(\.shelfPrefix) private var prefix

        var body: some View {
            Button(action: open) {
                Label("More info", systemImage: "info.circle")
            }
            .accessibilityIdentifier("\(prefix).menu.info")
        }
    }

    /// The poster menu's item: add to My list, or remove once added
    /// (movies-and-series-browsing/keep-a-list-for-later).
    struct MyListMenuItem: View {
        let isOnMyList: Bool
        let toggle: () -> Void
        @Environment(\.shelfPrefix) private var prefix

        var body: some View {
            Button(action: toggle) {
                Label(isOnMyList ? "Remove from My list" : "Add to My list", systemImage: isOnMyList ? "checkmark" : "plus")
            }
            .accessibilityIdentifier("\(prefix).menu.myList")
        }
    }
}

#Preview("Continue watching, iPhone", traits: .fixedLayout(width: 390, height: 140)) {
    ShelfView.Row {
        EmptyView()
    } cards: {
        ShelfView.ProgressCard(title: ShelfFixtures.movie(1), caption: "52 min left", fraction: 0.42) {}
        ShelfView.ProgressCard(title: ShelfFixtures.series(0), caption: "S2 E4", fraction: 0.78) {}
        ShelfView.ProgressCard(title: ShelfFixtures.movie(2), caption: nil, fraction: 0.15) {}
    }
    .background(Palette.ground)
}

#Preview("Recently added with See all, Apple TV", traits: .fixedLayout(width: 1920, height: 420)) {
    ShelfView.Row {
        ShelfView.RowHeader(title: "Recently added", count: "214 titles") { EmptyView() }
    } cards: {
        ForEach(0..<6, id: \.self) { index in
            ShelfView.PosterCard(title: ShelfFixtures.movie(index), label: ShelfFixtures.movie(index).name) {}
        }
        ShelfView.SeeAllTile {}
    }
    .environment(\.shelfMetrics, .tv)
    .background(Palette.ground)
}

#Preview("Recently added with See all, iPhone", traits: .fixedLayout(width: 390, height: 240)) {
    ShelfView.Row {
        ShelfView.RowHeader(title: "Recently added", count: "214 titles") {
            ShelfView.SeeAllButton(identifier: "movies.row.recentlyAdded.seeAll") {}
        }
    } cards: {
        ForEach(0..<4, id: \.self) { index in
            ShelfView.PosterCard(title: ShelfFixtures.movie(index), label: ShelfFixtures.movie(index).name) {}
        }
    }
    .background(Palette.ground)
}

#Preview("Continue watching, Apple TV", traits: .fixedLayout(width: 1920, height: 300)) {
    ShelfView.Row {
        ShelfView.RowHeader(title: "Continue watching", count: nil) {
            ShelfView.SeeAllButton {}
        }
    } cards: {
        ShelfView.ProgressCard(title: ShelfFixtures.movie(1), caption: "52 min left", fraction: 0.42) {}
        ShelfView.ProgressCard(title: ShelfFixtures.series(0), caption: "Next episode", fraction: 1) {}
    }
    .environment(\.shelfMetrics, .tv)
    .background(Palette.ground)
}
