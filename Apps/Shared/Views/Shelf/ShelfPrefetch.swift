import AntennaCore
import SwiftUI

/// Loads posters before their cards come into view. The screens provide
/// the app's poster cache; previews leave it out and load nothing ahead.
struct PosterPrefetcher: Sendable {
    /// Loads the posters at the addresses for the frame, for a group such as a row.
    var prefetch: @Sendable ([URL], PosterFit, String) async -> Void
    /// Stops what a group asked for that no card waits for.
    var stop: @Sendable (String) async -> Void
    /// Which way each row is scrolling.
    let trail = PrefetchTrail()
}

/// The last poster each row showed, read and written on the main actor
/// as posters show. Not observed, so it redraws nothing.
@MainActor
final class PrefetchTrail {
    private var trail = PosterPrefetch.Trail()

    nonisolated init() {}

    func shown(_ index: Int, in line: String, count: Int, along: Int = PosterPrefetch.along) -> Range<Int> {
        trail.shown(index, in: line, count: count, along: along)
    }

    func forget(_ line: String) {
        trail.forget(line)
    }
}

extension EnvironmentValues {
    /// Set by the screens to the app's poster cache.
    @Entry var posterPrefetcher: PosterPrefetcher?
    /// The widest the window has been, in points, which a row spans. Set
    /// by the screens; 0 loads no row ahead.
    @Entry var shelfWindowWidth: CGFloat = 0
}

/// What Movies and Series load ahead, on every platform
/// (movies-and-series-browsing/browsing-stays-responsive): when a poster
/// in a row shows, the next three in the direction the row is scrolling,
/// and when a row shows, the posters the next row in the direction of the
/// scroll shows first: the row under it on the way down, the row above on
/// the way up. Continue watching, My list and Recently watched are short
/// and load as they show; under them the first category row loads ahead. Once a row
/// scrolls away, what it asked for that no card waits for stops loading.
/// Every poster decodes at its card's size on screen, the frame the card
/// asks for, so the 50 MB of posters in memory hold what is on screen and
/// this much more.
extension View {
    func prefetchesAlongTheRow(_ title: ShelfTitle) -> some View {
        modifier(PrefetchAlong(title: title))
    }

    func prefetchesTheNextRow(_ identifier: String) -> some View {
        modifier(PrefetchNextRow(identifier: identifier))
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
        content.task {
            // Read here, not in the body, so a change to the rows does not redraw the poster.
            guard let prefetcher, let fit = RowPosterFit(metrics: metrics, scale: scale).fit,
                let titles = library.model(title.kind).rows.first(where: { $0.identifier == row })?.titles,
                let index = titles.firstIndex(where: { $0.id == title.id })
            else { return }
            let group = PrefetchGroup.along(prefix, row)
            let urls = prefetcher.trail.shown(index, in: group, count: titles.count).compactMap { titles[$0].posterURL }
            await prefetcher.prefetch(urls, fit, group)
        }
    }
}

private struct PrefetchNextRow: ViewModifier {
    /// The viewer's own rows, above the category rows.
    static let ownRows: Set<String> = ["continueWatching", "myList", "recentlyWatched"]
    let identifier: String
    @Environment(ShelfLibrary.self) private var library
    @Environment(\.posterPrefetcher) private var prefetcher
    @Environment(\.shelfPrefix) private var prefix
    @Environment(\.shelfMetrics) private var metrics
    @Environment(\.displayScale) private var scale
    @Environment(\.shelfWindowWidth) private var width

    func body(content: Content) -> some View {
        content
            // The window's width, not the row's: a geometry reader on every
            // row cost frames on each scroll.
            .task {
                guard width > 0, let prefetcher, let fit = RowPosterFit(metrics: metrics, scale: scale).fit else { return }
                let visible = PosterPrefetch.visible(width: width, poster: metrics.poster.width, gap: metrics.gap, gutter: metrics.gutter)
                let rows = library.model(prefix == ShelfTitle.Kind.series.prefix ? .series : .movie).rows
                // A row of the viewer's own, above the category rows, has the first category row under it.
                let next: Range<Int>
                if let position = rows.firstIndex(where: { $0.identifier == identifier }) {
                    next = prefetcher.trail.shown(position, in: "rows.\(prefix)", count: rows.count, along: PosterPrefetch.rowsAhead)
                } else if Self.ownRows.contains(identifier) {
                    next = PosterPrefetch.start(count: rows.count, visible: PosterPrefetch.rowsAhead)
                } else {
                    return
                }
                let urls = next.flatMap { row in
                    PosterPrefetch.start(count: rows[row].titles.count, visible: visible).compactMap { rows[row].titles[$0].posterURL }
                }
                await prefetcher.prefetch(urls, fit, PrefetchGroup.below(prefix, identifier))
            }
            .onDisappear {
                guard let prefetcher else { return }
                let groups = [PrefetchGroup.below(prefix, identifier), PrefetchGroup.along(prefix, identifier)]
                prefetcher.trail.forget(PrefetchGroup.along(prefix, identifier))
                Task { for group in groups { await prefetcher.stop(group) } }
            }
    }
}

/// The names rows prefetch under: a row's own posters along it, and the
/// start of the next row.
private enum PrefetchGroup {
    static func along(_ prefix: String, _ row: String) -> String { "along.\(prefix).\(row)" }
    static func below(_ prefix: String, _ row: String) -> String { "below.\(prefix).\(row)" }
}
