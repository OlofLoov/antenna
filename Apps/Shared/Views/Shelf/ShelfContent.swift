import AntennaCore
import SwiftUI

/// What a poster or the banner does, given by the screen that hosts the section.
struct ShelfActions {
    var play: @MainActor (ShelfTitle) -> Void
    /// Opens the title's page (title-detail-and-episode-picker).
    var open: @MainActor (ShelfTitle, TitleRoute.Origin) -> Void
    var toggleMyList: @MainActor (ShelfTitle) -> Void
    var isOnMyList: @MainActor (ShelfTitle) -> Bool

    /// The section `kind`'s actions: playing through `playback`, pages
    /// through `library` and My list through `activity`.
    @MainActor static func section(
        _ kind: ShelfTitle.Kind, library: ShelfLibrary, activity: ShelfActivity, playback: ShelfPlayback
    ) -> ShelfActions {
        ShelfActions(
            play: { playback.play($0, library: library, activity: activity) },
            open: { library.openPage($0, from: $1, in: kind) },
            toggleMyList: { activity.toggleMyList($0) }, isOnMyList: { activity.isOnMyList($0) })
    }

    /// What selecting a poster in `row` does: a movie plays, a series
    /// opens its page (title-detail-and-episode-picker/open-a-series-page).
    @MainActor func select(_ title: ShelfTitle, in row: String) {
        switch title.kind {
        case .movie: play(title)
        case .series: open(title, .poster(row: row))
        }
    }
}

/// Shows the banner's title, moves on every eight seconds while nobody
/// interacts with it and Reduce Motion is off, and loads the shown title's
/// details (movies-and-series-browsing/new-titles-up-front).
struct ShelfBannerHost<Content: View>: View {
    let model: ShelfModel
    let actions: ShelfActions
    @ViewBuilder var content: Content
    @State private var index = 0
    @State private var interacting = false
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    var body: some View {
        let titles = model.banner
        let shown = titles.isEmpty ? nil : titles[min(index, titles.count - 1)]
        let rotates = BannerPager.rotates(count: titles.count, interacting: interacting, reduceMotion: reduceMotion)
        content
            .environment(\.shelfBanner, shown.map { context($0, count: titles.count) })
            .task(id: Rotation(index: index, rotates: rotates)) {
                guard rotates else { return }
                try? await Task.sleep(for: BannerPager.interval)
                guard !Task.isCancelled else { return }
                page(1, count: titles.count)
            }
            .task(id: shown?.id) {
                guard let shown else { return }
                await model.loadDetails(shown)
                // The next title's details are ready before it shows.
                let next = ((titles.firstIndex(of: shown) ?? 0) + 1) % titles.count
                if next < titles.count { await model.loadDetails(titles[next]) }
            }
    }

    private struct Rotation: Hashable {
        var index: Int
        var rotates: Bool
    }

    private var reduceMotion: Bool {
        #if DEBUG
            if UITestingShelf.reduceMotion { return true }
        #endif
        return systemReduceMotion
    }

    private func page(_ steps: Int, count: Int) {
        var pager = BannerPager(count: count)
        pager.show(index)
        pager.page(steps)
        index = pager.index
    }

    private func context(_ title: ShelfTitle, count: Int) -> BannerContext {
        let details = model.details[title.id]
        return BannerContext(
            state: .init(
                text: BannerText(title, details: details), artURL: details?.backdropURL ?? title.posterURL,
                isOnMyList: actions.isOnMyList(title), index: min(index, count - 1), count: count),
            actions: .init(
                play: { actions.play(title) }, moreInfo: { actions.open(title, .banner) },
                toggleMyList: { actions.toggleMyList(title) },
                page: { page($0, count: count) },
                show: { target in
                    var pager = BannerPager(count: count)
                    pager.show(target)
                    index = pager.index
                },
                interacting: { interacting = $0 }))
    }
}

/// Continue watching, My list and Recently watched when they have titles,
/// then Recently added and a row per category. Rows and their posters build
/// as they scroll into view, so only visible posters load
/// (movies-and-series-browsing/rows-in-a-predictable-order).
struct ShelfRowsContent: View {
    let model: ShelfModel
    let actions: ShelfActions
    /// Opens the Continue watching or Recently added grid.
    let seeAll: (ShelfList) -> Void
    @Environment(ShelfLibrary.self) private var library
    @Environment(ShelfActivity.self) private var activity
    @Environment(\.shelfPrefix) private var prefix

    var body: some View {
        let watching = activity.continueWatching(library)
        if !watching.isEmpty {
            ShelfView.Row {
                ShelfView.RowHeader(title: "Continue watching", count: nil) {
                    ShelfView.SeeAllButton { seeAll(.continueWatching) }
                }
            } cards: {
                ForEach(watching) { item in
                    ShelfContinueCard(item: item, actions: actions)
                }
            }
            .environment(\.shelfRow, "continueWatching")
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("\(prefix).row.continueWatching")
        }
        let listed = activity.myList(model)
        if !listed.isEmpty {
            ShelfView.Row {
                ShelfView.RowHeader(title: "My list", count: ShelfText.titles(listed.count)) { EmptyView() }
            } cards: {
                ForEach(listed) { title in
                    ShelfPoster(title: title, actions: actions)
                }
            }
            .environment(\.shelfRow, "myList")
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("\(prefix).row.myList")
        }
        let watched = activity.recentlyWatched(model)
        if !watched.isEmpty {
            ShelfView.Row {
                ShelfView.RowHeader(title: "Recently watched", count: ShelfText.titles(watched.count)) { EmptyView() }
            } cards: {
                ForEach(watched) { title in
                    ShelfPoster(title: title, actions: actions)
                }
            }
            .environment(\.shelfRow, "recentlyWatched")
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("\(prefix).row.recentlyWatched")
        }
        ForEach(model.rows) { row in
            if row.id == .recentlyAdded {
                recentlyAdded(row)
            } else {
                ShelfView.Row {
                    ShelfView.RowHeader(title: row.name, count: ShelfText.titles(row.count)) { EmptyView() }
                } cards: {
                    ForEach(row.titles) { title in
                        ShelfPoster(title: title, actions: actions)
                    }
                }
                .environment(\.shelfRow, row.identifier)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("\(prefix).row.\(row.identifier)")
            }
        }
    }

    /// Recently added with See all, in the header on iPhone, iPad and Mac
    /// and as a tile after the last poster on Apple TV
    /// (movies-and-series-browsing/see-everything-new).
    private func recentlyAdded(_ row: ShelfRow) -> some View {
        let seeAllID = "\(prefix).row.\(row.identifier).seeAll"
        return ShelfView.Row {
            ShelfView.RowHeader(title: row.name, count: ShelfText.titles(row.count)) {
                #if !os(tvOS)
                    ShelfView.SeeAllButton(identifier: seeAllID) { seeAll(.recentlyAdded) }
                #endif
            }
        } cards: {
            ForEach(row.titles) { title in
                ShelfPoster(title: title, actions: actions)
            }
            #if os(tvOS)
                ShelfView.SeeAllTile { seeAll(.recentlyAdded) }
                    .accessibilityIdentifier(seeAllID)
            #endif
        }
        .environment(\.shelfRow, row.identifier)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("\(prefix).row.\(row.identifier)")
    }
}

/// A poster that plays a movie or opens a series' page on select, and
/// offers More info for a movie and My list in its menu, a long press on
/// Apple TV (movies-and-series-browsing/keep-a-list-for-later,
/// title-detail-and-episode-picker/open-a-movie-s-page).
struct ShelfPoster: View {
    let title: ShelfTitle
    let actions: ShelfActions
    @Environment(ShelfActivity.self) private var activity
    @Environment(ShelfPlayback.self) private var playback
    @Environment(\.shelfPrefix) private var prefix
    @Environment(\.shelfRow) private var row

    var body: some View {
        ShelfView.PosterCard(title: title, label: ShelfText.posterLabel(title, progress: activity.progress(of: title))) {
            actions.select(title, in: row)
        }
        .modifier(ReturnFocus(title: title, origin: .poster(row: row)))
        // A series' poster shows it is working while its episode list loads
        // (movies-and-series-browsing/play-a-series-from-the-next-episode).
        .overlay {
            if playback.working == title.id {
                ProgressView()
                    .controlSize(.large)
                    .tint(Palette.text)
                    .accessibilityLabel("Loading episodes")
                    .accessibilityIdentifier("\(prefix).card.\(title.id).working")
            }
        }
        .contextMenu {
            if title.kind == .movie {
                ShelfView.MoreInfoMenuItem { actions.open(title, .poster(row: row)) }
            }
            ShelfView.MyListMenuItem(isOnMyList: actions.isOnMyList(title)) { actions.toggleMyList(title) }
        }
    }
}

/// A Continue watching card with its caption. It plays straight away, a
/// series from the episode its page's Play would start
/// (title-detail-and-episode-picker/open-a-series-page). A series' card
/// loads its episode list once it shows, for the season and episode.
struct ShelfContinueCard: View {
    let item: ContinueWatching.Item
    let actions: ShelfActions
    @Environment(ShelfLibrary.self) private var library
    @Environment(\.shelfRow) private var row

    var body: some View {
        let episode = library.series.episodes[item.title.id]?.first { $0.id == item.progress.titleID }
        let length = item.progress.knownDuration ?? 1
        ShelfView.ProgressCard(
            title: item.title, caption: ShelfText.continueCaption(item, episode: episode),
            fraction: item.isNextEpisode ? 1 : item.progress.position / length
        ) {
            actions.play(item.title)
        }
        .contextMenu {
            if item.title.kind == .movie {
                ShelfView.MoreInfoMenuItem { actions.open(item.title, .poster(row: row)) }
            }
            ShelfView.MyListMenuItem(isOnMyList: actions.isOnMyList(item.title)) { actions.toggleMyList(item.title) }
        }
        .modifier(ReturnFocus(title: item.title, origin: .poster(row: row)))
        .task(id: item.id) {
            if item.title.kind == .series { await library.series.prefetchEpisodes(item.title) }
        }
    }
}

/// Takes focus back when the page this poster opened closes, so Apple TV
/// lands where the user started
/// (title-detail-and-episode-picker/back-to-where-you-were). Elsewhere the
/// poster is still where it was, since the section stays under the page.
struct ReturnFocus: ViewModifier {
    let title: ShelfTitle
    let origin: TitleRoute.Origin
    @Environment(ShelfLibrary.self) private var library
    @FocusState private var focused: Bool

    func body(content: Content) -> some View {
        #if os(tvOS)
            content
                .focused($focused)
                .task(id: library.returning?.title) {
                    guard let back = library.returning, back.title == title, back.origin == origin else { return }
                    await Task.yield()
                    focused = true
                    library.returned()
                }
        #else
            content
        #endif
    }
}

extension ShelfRow {
    /// `recentlyAdded`, or the category name as a slug.
    var identifier: String {
        switch id {
        case .recentlyAdded: "recentlyAdded"
        case .category(let name): ShelfText.slug(name)
        }
    }
}

/// The failed-source banner and a note per source waiting for its login,
/// above the rows (movies-and-series-browsing/when-sources-fail).
struct ShelfNotices: View {
    let model: ShelfModel
    let banner: String?
    let waiting: [ShelfSource]
    @Environment(\.shelfMetrics) private var metrics
    @Environment(\.shelfPrefix) private var prefix

    var body: some View {
        if banner != nil || !waiting.isEmpty {
            VStack(spacing: 8) {
                if let banner {
                    Browse.FailureBanner(text: banner, identifier: "\(prefix).failure", retry: model.retry, dismiss: model.dismissBanner)
                }
                ForEach(waiting) { source in
                    ShelfView.WaitingNote(source: source)
                }
            }
            .padding(.horizontal, metrics.gutter)
        }
    }
}

/// The section's place while no title can show: each source loading, or a
/// message with Retry for the failed sources.
struct ShelfStatusContent: View {
    let model: ShelfModel
    let status: ShelfStatus
    @Environment(\.shelfPrefix) private var prefix

    var body: some View {
        switch status {
        case .loading(let sources):
            ShelfView.Loading(sources: sources)
        case .offline(let waiting):
            ShelfView.Message(title: ShelfStatus.offlineTitle, lines: [ShelfStatus.offlineLine] + waiting) {
                ShelfView.RetryButton(retry: model.retry)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("\(prefix).error")
        case .failed(let waiting):
            ShelfView.Message(title: ShelfStatus.failedTitle(model.kind), lines: waiting) {
                ShelfView.RetryButton(retry: model.retry)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("\(prefix).error")
        case .empty(let lines):
            ShelfView.Message(title: ShelfStatus.emptyTitle, lines: lines) { EmptyView() }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("\(prefix).empty")
        case .titles:
            EmptyView()
        }
    }
}

extension ShelfStatus {
    /// True once titles show instead of loading or a message.
    var showsTitles: Bool {
        if case .titles = self { return true }
        return false
    }
}
