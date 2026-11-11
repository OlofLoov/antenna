import AntennaCore
import Foundation
import Observation
import SwiftData

/// How far the user's sources have loaded, as Search reports it
/// (search/nothing-found).
enum SearchSources: Sendable, Equatable {
    /// No source has finished: "Channels are still loading".
    case loading
    /// Some have finished and some have not: the no-results message adds
    /// "Some sources are still loading."
    case partial
    /// Every source has finished, with or without channels.
    case loaded

    /// From each source's state: true once it finished, loaded or failed.
    init(finished: [Bool]) {
        if finished.allSatisfy(\.self) {
            self = .loaded
        } else if finished.contains(true) {
            self = .partial
        } else {
            self = .loading
        }
    }
}

/// What Search searches, handed over by the screen that shows it.
struct SearchCorpus: Sendable {
    var catalogue: Catalogue<PersistentIdentifier>
    /// Each source's place in the source list.
    var sourceOrder: [UUID: Int]
    var guide: GuideIndex
    var titles: [ShelfTitle]
    /// True when the Movies and Series sections exist, so their chips show.
    var hasTitles: Bool
    var sources: SearchSources

    /// Changes whenever what the index holds would: a source loading, a
    /// guide arriving or titles loading.
    struct Signature: Hashable {
        var channels: Int
        var rows: [RowKey]
        var programmes: Int
        var settledGuides: Int
        var horizon: DateInterval?
        var titles: Int
        var hasTitles: Bool
        var sources: SearchSources
        /// The day the index was built, so a long-open screen builds again daily.
        var day: Int
    }

    func signature(now: Date) -> Signature {
        let all = catalogue.rows(in: .all)
        return Signature(
            channels: all.count, rows: [all.first, all.last].compactMap(\.self), programmes: guide.programmeCount,
            settledGuides: guide.settledSourceCount,
            horizon: guide.horizon, titles: titles.count, hasTitles: hasTitles, sources: sources,
            day: Int(now.timeIntervalSinceReferenceDate / 86_400))
    }
}

/// One result row, in the order the arrow keys move through them.
enum SearchItem: Hashable {
    case channel(RowKey)
    case programme(SearchResults.ProgrammeHit.Identity)
    case title(String)
}

/// State and rules of Search on every platform (search capability): the
/// field, the chips, the results of the last settled query, and the index
/// they come from. The screens own the field's focus and what picking does.
@MainActor @Observable
final class SearchModel {
    struct Dependencies {
        /// How long after the last keystroke the results follow.
        var debounce = Duration.milliseconds(300)
        var sleep: @MainActor (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
        var now: @MainActor () -> Date = { .now }
    }

    /// What the field holds.
    private(set) var query = ""
    /// The chip that narrows the results (search/narrow-to-one-kind).
    var scope: SearchScope = .all
    /// In the guide lists every match after "See all".
    private(set) var guideExpanded = false
    /// The results of the last settled query.
    private(set) var results = SearchResults.none(SearchQuery(""))
    /// When those results were worked out, for the NOW and day labels.
    private(set) var searchedAt = Date.distantPast
    private(set) var sources: SearchSources = .loaded
    /// Some channel's guide is still loading.
    private(set) var guideLoading = false
    private(set) var hasTitles = false
    /// Grows each time the field should take the cursor.
    private(set) var focusRequests = 0
    /// The row the arrow keys are on, nil while in the field
    /// (search/search-with-a-keyboard).
    var cursor: SearchItem?
    /// The recent search the arrow keys are on after Escape, nil otherwise.
    var recentCursor: Int?

    @ObservationIgnored private let dependencies: Dependencies
    @ObservationIgnored private var index = SearchIndex()
    @ObservationIgnored private var typing: Task<Void, Never>?

    init(_ dependencies: Dependencies = Dependencies()) {
        self.dependencies = dependencies
    }

    /// The scopes with a chip: Movies and Series only with those sections.
    var scopes: [SearchScope] {
        SearchScope.allCases.filter { hasTitles || ($0 != .movies && $0 != .series) }
    }

    /// The field changed. The results follow once typing pauses; a field
    /// emptied or cut to one letter shows nothing at once.
    func type(_ text: String) {
        guard text != query else { return }
        query = text
        recentCursor = nil
        typing?.cancel()
        guard SearchQuery(text).isSearchable else {
            settle()
            return
        }
        let debounce = dependencies.debounce
        let sleep = dependencies.sleep
        typing = Task { [weak self] in
            do {
                try await sleep(debounce)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            self?.settle()
        }
    }

    /// Opens set to `scope` with `text` in the field and the cursor in it,
    /// as the Movies and Series sections ask
    /// (movies-and-series-browsing/search-from-the-section).
    func start(_ scope: SearchScope, text: String) {
        self.scope = scope
        type(text)
        focus()
    }

    /// Searches for `text` straight away, as picking a recent search does.
    func run(_ text: String) {
        typing?.cancel()
        recentCursor = nil
        query = text
        settle()
    }

    /// Return in the field: no need to wait for the pause.
    func submit() {
        typing?.cancel()
        settle()
    }

    /// Empties the field and asks for the cursor (search/clear-the-field).
    func clear() {
        typing?.cancel()
        query = ""
        settle()
        focus()
    }

    /// Asks the screen to put the cursor in the field.
    func focus() {
        recentCursor = nil
        focusRequests += 1
    }

    /// Escape in an empty field: the arrow keys move through the recent searches.
    func cursorOnRecents() {
        cursor = nil
        recentCursor = 0
    }

    /// The rows on screen for the current chip, in order.
    var items: [SearchItem] {
        var items: [SearchItem] = []
        if scope == .all || scope == .channels { items += results.shownChannels.map { .channel($0.id) } }
        if scope == .all || scope == .guide {
            items += results.shownProgrammes(scope, expanded: guideExpanded).map { .programme(results.programmes[$0].id) }
        }
        if scope != .channels, scope != .guide { items += results.shownTitles(scope).map { .title($0.id) } }
        return items
    }

    /// Moves the cursor by `step` rows, from the field into the first row.
    func moveCursor(_ step: Int) {
        let items = items
        guard !items.isEmpty else { return }
        guard let cursor, let index = items.firstIndex(of: cursor) else {
            self.cursor = step > 0 ? items.first : nil
            return
        }
        let next = index + step
        self.cursor = next < 0 ? nil : items[min(next, items.count - 1)]
        if next < 0 { focus() }
    }

    func expandGuide() {
        guideExpanded = true
    }

    /// Searches the last query again at the current time, so a programme
    /// that started or ended updates (search/seven-days-of-guide).
    func refresh() {
        guard SearchQuery(query).isSearchable, typing == nil else { return }
        settle()
    }

    /// Builds the index from `corpus` away from the main actor, then
    /// searches the current query against it, so a source that finished
    /// loading shows up (search/nothing-found).
    func load(_ corpus: SearchCorpus) async {
        let now = dependencies.now()
        let built = await Task.detached(priority: .userInitiated) {
            let channels = SearchChannel.all(in: corpus.catalogue, sourceOrder: corpus.sourceOrder)
            let index = SearchIndex(channels: channels, guide: corpus.guide, titles: corpus.titles, now: now)
            let guideLoading = channels.contains { channel in
                channel.guideKey.map { corpus.guide.loadingState(for: $0) == .loading } ?? false
            }
            return (index, guideLoading)
        }.value
        guard !Task.isCancelled else { return }
        index = built.0
        guideLoading = built.1
        sources = corpus.sources
        hasTitles = corpus.hasTitles
        if !hasTitles, scope == .movies || scope == .series { scope = .all }
        settle()
    }

    private func settle() {
        typing = nil
        let parsed = SearchQuery(query)
        if parsed.text != results.query.text { guideExpanded = false }
        searchedAt = dependencies.now()
        results = index.results(for: parsed, now: searchedAt)
        if let cursor, !items.contains(cursor) { self.cursor = nil }
    }
}
