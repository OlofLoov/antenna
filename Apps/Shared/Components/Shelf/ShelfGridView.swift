import AntennaCore
import SwiftUI

extension ShelfView {
    /// A list's name and count over its posters in a grid (boards
    /// `iPhone-Movies-Grid`, `iPad-Movies-Grid`, `TV-Movies-Grid`): three
    /// across on iPhone, six on Apple TV, as many as fit on iPad and Mac.
    /// Posters build as they scroll into view.
    struct Grid<Cards: View>: View {
        let title: LocalizedStringResource
        let count: String
        /// The width of a wide card, for a grid of Continue watching cards;
        /// nil for posters.
        var cardWidth: CGFloat?
        @ViewBuilder var cards: Cards
        @Environment(\.shelfMetrics) private var metrics
        @Environment(\.shelfPrefix) private var prefix

        var body: some View {
            VStack(alignment: .leading, spacing: metrics.headerSpacing) {
                RowHeader(title: title, count: count) { EmptyView() }
                LazyVGrid(columns: columns, alignment: .leading, spacing: metrics.gap * 1.2) {
                    cards
                }
                .padding(.horizontal, metrics.gutter)
                .padding(.vertical, metrics.corner)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("\(prefix).grid")
        }

        private var columns: [GridItem] {
            let size = cardWidth ?? metrics.poster.width
            guard metrics != .pad, cardWidth == nil else {
                return [GridItem(.adaptive(minimum: size, maximum: size), spacing: metrics.gap, alignment: .top)]
            }
            return Array(repeating: GridItem(.fixed(size), spacing: metrics.gap, alignment: .top), count: metrics.columns)
        }
    }

    /// A genre chip over the art: glass on iPhone, iPad and Mac, prominent
    /// when selected; bordered on Apple TV (design-system/controls-use-system-styles).
    struct Chip: View {
        let title: LocalizedStringResource
        let isSelected: Bool
        let select: () -> Void
        @Environment(\.shelfMetrics) private var metrics

        var body: some View {
            Button(action: select) {
                Text(title)
                    .font(.boardStyle(metrics.count, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
            }
            .chipStyle(isPicked: isSelected, on: .art)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
    }

    /// Chips in one line that scrolls sideways.
    struct Chips<Content: View>: View {
        @ViewBuilder var content: Content
        @Environment(\.shelfMetrics) private var metrics
        @Environment(\.shelfPrefix) private var prefix

        var body: some View {
            ScrollView(.horizontal) {
                HStack(spacing: metrics.gap * 0.8) { content }
                    .padding(.horizontal, metrics.gutter)
                    .padding(.vertical, metrics.corner)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("\(prefix).genres")
        }
    }
}

#Preview("Grid, iPhone", traits: .fixedLayout(width: 390, height: 600)) {
    ShelfView.Grid(title: "Thriller", count: "187 titles") {
        ForEach(0..<7, id: \.self) { index in
            ShelfView.PosterCard(title: ShelfFixtures.movie(index), label: ShelfFixtures.movie(index).name) {}
        }
    }
    .background(Palette.ground)
}

#Preview("Grid, iPad", traits: .fixedLayout(width: 914, height: 600)) {
    ShelfView.Grid(title: "All movies", count: "1 240 titles") {
        ForEach(0..<12, id: \.self) { index in
            ShelfView.PosterCard(title: ShelfFixtures.movie(index), label: ShelfFixtures.movie(index).name) {}
        }
    }
    .environment(\.shelfMetrics, .pad)
    .background(Palette.ground)
}

#Preview("Grid, Apple TV", traits: .fixedLayout(width: 1920, height: 1080)) {
    ShelfView.Grid(title: "Thriller", count: "187 titles") {
        ForEach(0..<12, id: \.self) { index in
            ShelfView.PosterCard(title: ShelfFixtures.movie(index), label: ShelfFixtures.movie(index).name) {}
        }
    }
    .environment(\.shelfMetrics, .tv)
    .background(Palette.ground)
}

#Preview("Genre chips", traits: .fixedLayout(width: 390, height: 60)) {
    ShelfView.Chips {
        ShelfView.Chip(title: "All", isSelected: true) {}
        ShelfView.Chip(title: "My list", isSelected: false) {}
        ShelfView.Chip(title: "Action", isSelected: false) {}
        ShelfView.Chip(title: "Comedy", isSelected: false) {}
    }
    .background(Color(red: 0x22 / 255, green: 0x30 / 255, blue: 0x4A / 255))
}
