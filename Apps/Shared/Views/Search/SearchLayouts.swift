import AntennaCore
import SwiftUI

/// Search's results in each platform's arrangement: Channels, In the guide,
/// and Movies & series in that order, each with its count, empty sections
/// left out (search/results-grouped-best-first). Every layout reads the
/// feed the screen provides.
enum SearchLayout {
    /// iPhone: one list, muted uppercase headers (`iPhone-Search`).
    struct Phone: View {
        @Environment(\.searchFeed) private var feed

        var body: some View {
            if let feed {
                let model = feed.model
                let results = model.results
                LazyVStack(alignment: .leading, spacing: 14) {
                    if showsChannels(model) {
                        section(.channels, model: model) {
                            ForEach(Array(results.shownChannels.enumerated()), id: \.element.id) { index, hit in
                                SearchChannelResult(hit: hit, index: index)
                            }
                            capNote(results)
                        }
                    }
                    if showsGuide(model) {
                        section(.guide, model: model) {
                            ForEach(results.shownProgrammes(model.scope, expanded: model.guideExpanded), id: \.self) { index in
                                SearchProgrammeResult(hit: results.programmes[index], index: index)
                            }
                        }
                    }
                    if showsTitles(model) {
                        section(.titles, model: model) {
                            ScrollView(.horizontal) {
                                LazyHStack(alignment: .top, spacing: 12) { titles(results.shownTitles(model.scope)) }
                                    .padding(.horizontal, 8)
                            }
                            .scrollIndicators(.hidden)
                        }
                    }
                }
                .padding(.vertical, 12)
            }
        }

        private func section<Content: View>(
            _ kind: SearchSectionKind, model: SearchModel, @ViewBuilder content: () -> Content
        ) -> some View {
            VStack(alignment: .leading, spacing: 6) {
                SearchSectionHeader(kind: kind, model: model, uppercase: true)
                    .padding(.horizontal, 16)
                VStack(alignment: .leading, spacing: 0) { content() }
                    .padding(.horizontal, 8)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("search.section.\(kind.identifier)")
        }
    }

    /// iPad and Mac: channels three across, programmes two across, posters
    /// in a row (`iPad-Search`).
    struct Pad: View {
        @Environment(\.searchFeed) private var feed

        var body: some View {
            if let feed {
                let model = feed.model
                let results = model.results
                LazyVStack(alignment: .leading, spacing: 22) {
                    if showsChannels(model) {
                        section(.channels, model: model) {
                            LazyVGrid(columns: columns(3), spacing: 10) {
                                ForEach(Array(results.shownChannels.enumerated()), id: \.element.id) { index, hit in
                                    SearchChannelResult(hit: hit, index: index)
                                }
                            }
                            capNote(results)
                        }
                    }
                    if showsGuide(model) {
                        section(.guide, model: model) {
                            LazyVGrid(columns: columns(2), spacing: 8) {
                                ForEach(results.shownProgrammes(model.scope, expanded: model.guideExpanded), id: \.self) { index in
                                    SearchProgrammeResult(hit: results.programmes[index], index: index)
                                }
                            }
                        }
                    }
                    if showsTitles(model) {
                        section(.titles, model: model) {
                            if model.scope == .all {
                                ScrollView(.horizontal) {
                                    LazyHStack(alignment: .top, spacing: 12) { titles(results.shownTitles(model.scope)) }
                                }
                                .scrollIndicators(.hidden)
                            } else {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 12, alignment: .top)], spacing: 16) {
                                    titles(results.shownTitles(model.scope))
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 4)
            }
        }

        private func columns(_ count: Int) -> [GridItem] {
            Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .top), count: count)
        }

        private func section<Content: View>(
            _ kind: SearchSectionKind, model: SearchModel, @ViewBuilder content: () -> Content
        ) -> some View {
            VStack(alignment: .leading, spacing: 10) {
                SearchSectionHeader(kind: kind, model: model, uppercase: false)
                content()
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("search.section.\(kind.identifier)")
        }
    }
}

/// The three sections.
enum SearchSectionKind {
    case channels, guide, titles

    var title: String {
        switch self {
        case .channels: "Channels"
        case .guide: "In the guide"
        case .titles: "Movies & series"
        }
    }

    var identifier: String {
        switch self {
        case .channels: "channels"
        case .guide: "guide"
        case .titles: "titles"
        }
    }
}

/// A section's header with its count; In the guide adds "Next 7 days",
/// "loading" while the guide loads, and "See all" while capped.
struct SearchSectionHeader: View {
    let kind: SearchSectionKind
    let model: SearchModel
    let uppercase: Bool

    var body: some View {
        let results = model.results
        SearchParts.Header(title: uppercase ? kind.title.uppercased() : kind.title, count: count(results)) {
            if kind == .guide, model.scope == .all, !model.guideExpanded, results.programmes.count > SearchResults.guidePreview {
                SearchParts.SeeAll(count: results.programmes.count) { model.expandGuide() }
            }
        }
    }

    private func count(_ results: SearchResults) -> String? {
        switch kind {
        case .channels: return "\(results.count(.channels))"
        case .guide:
            if results.programmes.isEmpty, model.guideLoading { return "loading" }
            return "\(SearchText.nextSevenDays) · \(results.count(.guide))"
        case .titles: return "\(results.titles.count)"
        }
    }
}

/// The kind chips with their counts, All first (search/narrow-to-one-kind).
struct SearchChips: View {
    let model: SearchModel

    var body: some View {
        Browse.Chips {
            ForEach(model.scopes, id: \.self) { scope in
                let count = model.results.count(scope)
                SearchParts.Chip(
                    title: SearchText.chip(scope, count: count), isSelected: model.scope == scope, isEmpty: count == 0 && scope != .all
                ) {
                    model.scope = scope
                    model.cursor = nil
                }
                .accessibilityIdentifier("search.chip.\(scope.identifier)")
            }
        }
        .accessibilityIdentifier("search.chips")
    }
}

extension SearchScope {
    /// `search.chip.<identifier>`.
    var identifier: String {
        switch self {
        case .all: "all"
        case .channels: "channels"
        case .guide: "guide"
        case .movies: "movies"
        case .series: "series"
        }
    }
}

@MainActor
private func showsChannels(_ model: SearchModel) -> Bool {
    (model.scope == .all || model.scope == .channels) && !model.results.channels.isEmpty
}

/// In the guide shows with matches, or as a header saying it is loading.
@MainActor
private func showsGuide(_ model: SearchModel) -> Bool {
    (model.scope == .all || model.scope == .guide) && (!model.results.programmes.isEmpty || model.guideLoading)
}

@MainActor
private func showsTitles(_ model: SearchModel) -> Bool {
    model.scope != .channels && model.scope != .guide && !model.results.shownTitles(model.scope).isEmpty
}

@MainActor @ViewBuilder
private func capNote(_ results: SearchResults) -> some View {
    if results.isChannelListCapped {
        SearchParts.CapNote(text: SearchText.showing(results.shownChannels.count, of: results.count(.channels)))
    }
}

@MainActor @ViewBuilder
private func titles(_ hits: [SearchResults.TitleHit]) -> some View {
    ForEach(Array(hits.enumerated()), id: \.element.id) { index, hit in
        SearchTitleResult(hit: hit, index: index)
    }
}
