import AntennaCore
import SwiftUI

/// Loads posters before their cards come into view. The screens provide
/// the app's poster cache; previews leave it out and load nothing ahead.
struct PosterPrefetcher: Sendable {
    /// Loads the posters at the addresses for the frame, for a group such as a row.
    var prefetch: @Sendable ([URL], PosterFit, String) async -> Void
    /// Stops what a group asked for that no card waits for.
    var stop: @Sendable (String) async -> Void
}

extension EnvironmentValues {
    /// Set by the screens to the app's poster cache.
    @Entry var posterPrefetcher: PosterPrefetcher?
}

/// What Movies and Series load ahead, on every platform
/// (movies-and-series-browsing/browsing-stays-responsive): when a poster
/// in a row shows, the next posters along that row, and when a row shows,
/// the first posters of the two rows under it. Continue watching, My list
/// and Recently watched are short and load as they show; under them the
/// first category rows load ahead. Once a row scrolls away, what it asked
/// for that no card waits for stops loading.
extension View {
    func prefetchesAlongTheRow(_ title: ShelfTitle) -> some View {
        modifier(PrefetchAlong(title: title))
    }

    func prefetchesTheRowsBelow(_ identifier: String) -> some View {
        modifier(PrefetchBelow(identifier: identifier))
    }
}

/// The frame posters in rows decode for, as `PosterLoading` works it out
/// for a card of the poster size, so a prefetched poster is the one the
/// card asks for.
private struct RowPosterFit {
    let metrics: ShelfView.Metrics
    let scale: CGFloat

    var fit: PosterFit? {
        PosterFit(width: metrics.poster.width, height: metrics.poster.height, scale: scale)
    }
}

private struct PrefetchAlong: ViewModifier {
    let title: ShelfTitle
    @Environment(ShelfLibrary.self) private var library
    @Environment(\.posterPrefetcher) private var prefetcher
    @Environment(\.shelfRow) private var row
    @Environment(\.shelfPrefix) private var prefix
    @Environment(\.shelfMetrics) private var metrics
    @Environment(\.displayScale) private var scale

    func body(content: Content) -> some View {
        content.onAppear {
            // Read here, not in the body, so a change to the rows does not redraw the poster.
            guard let prefetcher, let fit = RowPosterFit(metrics: metrics, scale: scale).fit,
                let titles = library.model(title.kind).rows.first(where: { $0.identifier == row })?.titles,
                let index = titles.firstIndex(where: { $0.id == title.id })
            else { return }
            let urls = PosterPrefetch.ahead(of: index, count: titles.count).compactMap { titles[$0].posterURL }
            let group = PrefetchGroup.along(prefix, row)
            Task { await prefetcher.prefetch(urls, fit, group) }
        }
    }
}

private struct PrefetchBelow: ViewModifier {
    /// The viewer's own rows, above the category rows.
    static let ownRows: Set<String> = ["continueWatching", "myList", "recentlyWatched"]
    let identifier: String
    @Environment(ShelfLibrary.self) private var library
    @Environment(\.posterPrefetcher) private var prefetcher
    @Environment(\.shelfPrefix) private var prefix
    @Environment(\.shelfMetrics) private var metrics
    @Environment(\.displayScale) private var scale

    func body(content: Content) -> some View {
        content.onAppear {
            guard let prefetcher, let fit = RowPosterFit(metrics: metrics, scale: scale).fit else { return }
            let rows = library.model(prefix == ShelfTitle.Kind.series.prefix ? .series : .movie).rows
            // A row of the viewer's own, above the category rows, has the first category rows under it.
            let below: Range<Int>
            if let position = rows.firstIndex(where: { $0.identifier == identifier }) {
                below = PosterPrefetch.below(row: position, rowCount: rows.count)
            } else if Self.ownRows.contains(identifier) {
                below = PosterPrefetch.start(count: rows.count, rowStart: PosterPrefetch.rowsBelow)
            } else {
                return
            }
            let urls = below.flatMap { row in
                PosterPrefetch.start(count: rows[row].titles.count).compactMap { rows[row].titles[$0].posterURL }
            }
            let group = PrefetchGroup.below(prefix, identifier)
            Task { await prefetcher.prefetch(urls, fit, group) }
        }
        .onDisappear {
            guard let prefetcher else { return }
            let groups = [PrefetchGroup.below(prefix, identifier), PrefetchGroup.along(prefix, identifier)]
            Task { for group in groups { await prefetcher.stop(group) } }
        }
    }
}

/// The names rows prefetch under: a row's own posters along it, and the
/// starts of the rows under it.
private enum PrefetchGroup {
    static func along(_ prefix: String, _ row: String) -> String { "along.\(prefix).\(row)" }
    static func below(_ prefix: String, _ row: String) -> String { "below.\(prefix).\(row)" }
}
