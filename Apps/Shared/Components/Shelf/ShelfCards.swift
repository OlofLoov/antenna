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

        var body: some View {
            Button(action: select) {
                VStack(alignment: .leading, spacing: metrics.headerSpacing * 0.6) {
                    LandscapeArt(name: title.name, url: title.posterURL)
                        .frame(width: metrics.card.width, height: metrics.card.height)
                        .overlay(alignment: .bottom) { bar }
                        .overlay(alignment: .topLeading) {
                            if title.kind == .series {
                                ShelfBanner.Badge(text: "SERIES", size: max(10, metrics.count - 3))
                                    .background(Palette.scrimTint.opacity(0.72), in: RoundedRectangle(cornerRadius: 4))
                                    .padding(metrics.corner * 0.7)
                                    .accessibilityIdentifier("\(prefix).card.\(title.id).badge")
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: metrics.corner, style: .continuous))
                    Text([title.name, caption].compactMap(\.self).joined(separator: " · "))
                        .font(.system(size: metrics.caption))
                        .foregroundStyle(Browse.textSecondary)
                        .lineLimit(1)
                        .frame(width: metrics.card.width, alignment: .leading)
                }
            }
            .buttonStyle(CardStyle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel([title.name, caption].compactMap(\.self).joined(separator: ", "))
            .accessibilityIdentifier("\(prefix).card.\(title.id)")
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
            ZStack {
                Browse.tile
                if let image = poster?.image {
                    Image(decorative: image, scale: 1).resizable().scaledToFill()
                } else {
                    Text(name)
                        .font(.system(size: metrics.caption + 2, weight: .semibold))
                        .foregroundStyle(Palette.text)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(10)
                }
            }
            .clipped()
            .task(id: url) {
                poster = nil
                guard let url, let loader else { return }
                poster = await loader.load(url)
            }
        }
    }

    /// "See all" at the end of the Continue watching header.
    struct SeeAllButton: View {
        let open: () -> Void
        @Environment(\.shelfMetrics) private var metrics
        @Environment(\.shelfPrefix) private var prefix

        var body: some View {
            Button(action: open) {
                Text("See all")
                    .font(.system(size: metrics.count))
                    .foregroundStyle(Palette.textMuted)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("\(prefix).seeAll")
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
