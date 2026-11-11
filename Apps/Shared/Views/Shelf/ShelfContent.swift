import AntennaCore
import SwiftUI

/// What a poster or the banner does, given by the screen that hosts the section.
struct ShelfActions {
    var play: (ShelfTitle) -> Void
    var toggleMyList: (ShelfTitle) -> Void
    var isOnMyList: (ShelfTitle) -> Bool

    static var none: ShelfActions { ShelfActions(play: { _ in }, toggleMyList: { _ in }, isOnMyList: { _ in false }) }
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
                play: { actions.play(title) }, moreInfo: {}, toggleMyList: { actions.toggleMyList(title) },
                page: { page($0, count: count) },
                show: { target in
                    var pager = BannerPager(count: count)
                    pager.show(target)
                    index = pager.index
                },
                interacting: { interacting = $0 }))
    }
}

/// Recently added and a row per category. Rows and their posters build as
/// they scroll into view, so only visible posters load
/// (movies-and-series-browsing/rows-in-a-predictable-order).
struct ShelfRowsContent: View {
    let model: ShelfModel
    let actions: ShelfActions
    @Environment(\.shelfPrefix) private var prefix

    var body: some View {
        ForEach(model.rows) { row in
            ShelfView.Row {
                ShelfView.RowHeader(title: row.name, count: ShelfText.titles(row.count)) { EmptyView() }
            } cards: {
                ForEach(row.titles) { title in
                    ShelfView.PosterCard(title: title, label: title.name) { actions.play(title) }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("\(prefix).row.\(row.identifier)")
        }
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
