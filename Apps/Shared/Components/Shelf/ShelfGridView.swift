import AntennaCore
import SwiftUI

extension ShelfView {
    /// A list's name and count over its posters in a grid (boards
    /// `iPhone-Movies-Grid`, `iPad-Movies-Grid`, `TV-Movies-Grid`): three
    /// across on iPhone, six on Apple TV, as many as fit on iPad and Mac.
    /// Posters build as they scroll into view.
    struct Grid<Cards: View>: View {
        let title: String
        let count: String
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
            let size = metrics.poster.width
            guard metrics != .pad else {
                return [GridItem(.adaptive(minimum: size, maximum: size), spacing: metrics.gap, alignment: .top)]
            }
            return Array(repeating: GridItem(.fixed(size), spacing: metrics.gap, alignment: .top), count: metrics.columns)
        }
    }

    /// A genre chip: the selected one takes the white fill, and on Apple TV
    /// the focused one the white card.
    struct Chip: View {
        let title: String
        let isSelected: Bool
        let select: () -> Void
        @Environment(\.shelfMetrics) private var metrics

        var body: some View {
            Button(action: select) {
                Text(title)
                    .font(.system(size: metrics.count, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
                    .padding(.horizontal, metrics.count)
                    .padding(.vertical, metrics.count / 2)
                    .frame(minHeight: 30)
            }
            .buttonStyle(ChipStyle(isSelected: isSelected))
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
    }

    private struct ChipStyle: ButtonStyle {
        let isSelected: Bool

        func makeBody(configuration: Configuration) -> some View {
            ChipLabel(label: configuration.label, isSelected: isSelected, isPressed: configuration.isPressed)
        }
    }

    private struct ChipLabel<Label: View>: View {
        let label: Label
        let isSelected: Bool
        let isPressed: Bool
        @Environment(\.isFocused) private var isFocused

        var body: some View {
            let white = isSelected || isFocused
            label
                .foregroundStyle(white ? Palette.ground : Palette.text)
                .background(white ? Palette.focus : Palette.scrimTint.opacity(0.6), in: Capsule())
                .contentShape(Capsule())
                .shadow(color: isFocused ? Palette.focusShadow : .clear, radius: 16, y: 12)
                .scaleEffect(isFocused ? 1.06 : 1)
                .opacity(isPressed ? 0.7 : 1)
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
