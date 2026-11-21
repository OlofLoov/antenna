import AntennaCore
import SwiftUI

/// The Movies and Series sections' parts (movies-and-series-browsing
/// capability; boards `iPhone-Movies`, `iPad-Movies`, `TV-Movies` and their
/// Rows and Grid boards). Sizes come from `ShelfView.Metrics` in the
/// environment, which the screen sets per platform. Identifiers start with
/// the section's prefix, `movies` or `series`, from the environment.
enum ShelfView {
    /// Card, type and spacing sizes, which differ between the boards.
    struct Metrics: Equatable, Sendable {
        /// A poster in a row or grid.
        var poster: CGSize
        /// A Continue watching card.
        var card: CGSize
        var corner: CGFloat
        /// The page's side margin.
        var gutter: CGFloat
        /// Between cards in a row.
        var gap: CGFloat
        /// Between rows, and between a row's header and its cards.
        var rowSpacing: CGFloat
        var headerSpacing: CGFloat
        var header: CGFloat
        var count: CGFloat
        var caption: CGFloat
        var progress: CGFloat
        /// Posters per line in a grid.
        var columns: Int

        /// `iPhone-Movies`: 110 by 165 posters, 168 by 94 cards.
        static let phone = Metrics(
            poster: CGSize(width: 110, height: 165), card: CGSize(width: 168, height: 94), corner: 8, gutter: 16, gap: 10,
            rowSpacing: 16, headerSpacing: 8, header: 17, count: 13, caption: 13, progress: 3, columns: 3)
        /// `iPad-Movies`: 132 by 198 posters, 212 by 119 cards.
        static let pad = Metrics(
            poster: CGSize(width: 132, height: 198), card: CGSize(width: 212, height: 119), corner: 10, gutter: 24, gap: 12,
            rowSpacing: 22, headerSpacing: 10, header: 18, count: 13, caption: 14, progress: 4, columns: 5)
        /// `TV-Movies`: 212 by 318 posters, 352 by 198 cards, and the 80 pt
        /// side margin of the safe area (design-system/apple-tv-content-stays-in-the-safe-area).
        static let tv = Metrics(
            poster: CGSize(width: 212, height: 318), card: CGSize(width: 352, height: 198), corner: 12, gutter: 80, gap: 20,
            rowSpacing: 40, headerSpacing: 16, header: 28, count: 20, caption: 22, progress: 6, columns: 6)
    }

    /// Fetches a poster image. The screen provides the app's poster cache;
    /// previews leave it out and show the name tiles.
    struct PosterLoader: Sendable {
        var load: @Sendable (URL, PosterFit?) async -> Poster?
    }

    /// The poster, or the name tile while it is missing, loading or broken.
    /// Fetches only once the card is on screen.
    struct PosterArt: View {
        let name: String
        let url: URL?

        @Environment(\.shelfMetrics) private var metrics
        @State private var poster: Poster?

        var body: some View {
            PosterTile(name: name, image: poster?.image, cornerRadius: metrics.corner, nameSize: metrics.caption + 2)
                .loadsPoster(url, into: $poster)
        }
    }

    /// A poster in a row or grid. VoiceOver reads `label`
    /// (movies-and-series-browsing/rows-in-a-predictable-order). A title
    /// whose kind is in `badged` wears SERIES at the top corner, as on a
    /// Continue watching card, where a row mixes movies and series.
    /// `identifier` defaults to `<prefix>.card.<id>`.
    struct PosterCard: View {
        let title: ShelfTitle
        let label: String
        var badged: Set<ShelfTitle.Kind> = []
        var identifier: String?
        let select: () -> Void
        @Environment(\.shelfMetrics) private var metrics
        @Environment(\.shelfPrefix) private var prefix

        var body: some View {
            Button(action: select) {
                PosterArt(name: title.name, url: title.posterURL)
                    .frame(width: metrics.poster.width, height: metrics.poster.height)
                    .overlay(alignment: .topLeading) {
                        if title.kind == .series, badged.contains(.series) {
                            ShelfBanner.Badge(text: "SERIES", size: max(10, metrics.count - 3))
                                .background(Palette.scrimTint.opacity(0.72), in: cornerShape(.small))
                                .padding(metrics.corner * 0.7)
                        }
                    }
            }
            .posterButtonStyle()
            .accessibilityLabel(label)
            .accessibilityIdentifier(identifier ?? "\(prefix).card.\(title.id)")
        }
    }

    /// A row's name and count, with anything trailing such as See all.
    struct RowHeader<Trailing: View>: View {
        let title: LocalizedStringResource
        let count: String?
        @ViewBuilder var trailing: Trailing
        @Environment(\.shelfMetrics) private var metrics

        var body: some View {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.boardStyle(metrics.header, weight: .bold))
                    .foregroundStyle(Palette.text)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 12)
                if let count {
                    Text(count)
                        .font(.boardStyle(metrics.count))
                        .foregroundStyle(Palette.textMuted)
                }
                trailing
            }
            .padding(.horizontal, metrics.gutter)
        }
    }

    /// A header over one line of cards that scrolls sideways. Cards build
    /// only as they scroll into view.
    struct Row<Header: View, Cards: View>: View {
        @ViewBuilder var header: Header
        @ViewBuilder var cards: Cards
        @Environment(\.shelfMetrics) private var metrics

        var body: some View {
            VStack(alignment: .leading, spacing: metrics.headerSpacing) {
                header
                ScrollView(.horizontal) {
                    LazyHStack(alignment: .top, spacing: metrics.gap) {
                        cards
                    }
                    .padding(.horizontal, metrics.gutter)
                    .padding(.vertical, metrics.corner)
                }
                .scrollIndicators(.hidden)
                .scrollClipDisabled()
            }
        }
    }
}

extension EnvironmentValues {
    /// Set by the Movies and Series screens per platform.
    @Entry var shelfMetrics = ShelfView.Metrics.phone
    /// `movies` or `series`, the first part of every identifier in the section.
    @Entry var shelfPrefix = "movies"
    /// Set by the screens to the app's poster cache.
    @Entry var posterLoader: ShelfView.PosterLoader?
    /// The row or grid a poster sits in, `recentlyAdded` or a category's
    /// slug, so a page can return to the poster that opened it.
    @Entry var shelfRow = ""
}

extension ShelfTitle.Kind {
    /// The section's identifier prefix and name.
    var prefix: String { self == .movie ? "movies" : "series" }
    var sectionTitle: LocalizedStringResource { self == .movie ? "Movies" : "Series" }
}

/// Titles for previews and UI test fixtures. No artwork, so every poster
/// shows its name tile.
enum ShelfFixtures {
    static let source = UUID(uuidString: "00000000-0000-0000-0000-0000000000F1") ?? UUID()
    static let names = [
        "The Long Harbor", "Second Act", "Salt Road", "Paper Cities", "Quiet Engines", "Northern Lights", "Glass Orchard",
        "Night Ferry",
    ]

    static func movie(_ index: Int, category: String? = "Thriller") -> ShelfTitle {
        ShelfTitle(
            id: "xtream#fixture#vod#\(index)", kind: .movie, sourceID: source, name: names[index % names.count], category: category)
    }

    static func series(_ index: Int, category: String? = "Drama") -> ShelfTitle {
        ShelfTitle(
            id: "xtream#fixture#series#\(index)", kind: .series, sourceID: source, name: names[(index + 5) % names.count],
            category: category)
    }
}

#Preview("Row of posters, iPhone", traits: .fixedLayout(width: 390, height: 240)) {
    ShelfView.Row {
        ShelfView.RowHeader(title: "Recently added", count: "214 titles") { EmptyView() }
    } cards: {
        ForEach(0..<4, id: \.self) { index in
            ShelfView.PosterCard(title: ShelfFixtures.movie(index), label: ShelfFixtures.movie(index).name) {}
        }
    }
    .background(Palette.ground)
}

#Preview("Row of posters, iPad", traits: .fixedLayout(width: 960, height: 280)) {
    ShelfView.Row {
        ShelfView.RowHeader(title: "Thriller", count: "187 titles") { EmptyView() }
    } cards: {
        ForEach(0..<7, id: \.self) { index in
            ShelfView.PosterCard(title: ShelfFixtures.movie(index), label: ShelfFixtures.movie(index).name) {}
        }
    }
    .environment(\.shelfMetrics, .pad)
    .background(Palette.ground)
}

#Preview("Row of posters, Apple TV", traits: .fixedLayout(width: 1920, height: 420)) {
    ShelfView.Row {
        ShelfView.RowHeader(title: "Recently added", count: "214 titles") { EmptyView() }
    } cards: {
        ForEach(0..<8, id: \.self) { index in
            ShelfView.PosterCard(title: ShelfFixtures.movie(index), label: ShelfFixtures.movie(index).name) {}
        }
    }
    .environment(\.shelfMetrics, .tv)
    .background(Palette.ground)
}
