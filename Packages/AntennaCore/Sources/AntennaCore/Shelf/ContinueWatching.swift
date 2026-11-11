import Foundation

/// The Continue watching row and where a series plays from
/// (movies-and-series-browsing/continue-watching).
public enum ContinueWatching {
    /// One title in the row.
    public struct Item: Sendable, Hashable, Identifiable {
        /// The movie, or the series an episode belongs to.
        public var title: ShelfTitle
        /// The movie's progress, or that of the series' most recent episode.
        public var progress: WatchProgress
        /// True for a series whose most recent episode is finished, shown
        /// as "Next episode".
        public var isNextEpisode: Bool

        public var id: String { title.id }

        public init(title: ShelfTitle, progress: WatchProgress, isNextEpisode: Bool) {
            self.title = title
            self.progress = progress
            self.isNextEpisode = isNextEpisode
        }
    }

    /// Movies and series in progress, most recent first. A finished movie
    /// leaves; a series whose latest episode is finished stays as "Next
    /// episode" unless it is in `finishedSeries`, the series known to have no
    /// unwatched episode left. Progress for a title that is not in `titles`
    /// is left out and kept.
    public static func items(progress: [WatchProgress], titles: [ShelfTitle], finishedSeries: Set<String> = []) -> [Item] {
        let loaded = Dictionary(titles.map { ($0.activityKey, $0) }, uniquingKeysWith: { first, _ in first })
        var latestEpisode: [ActivityKey: WatchProgress] = [:]
        var items: [Item] = []
        for value in progress {
            if let seriesID = value.seriesID {
                let key = ActivityKey(titleID: seriesID, sourceID: value.sourceID)
                if let current = latestEpisode[key], !WatchProgress.newestFirst(value, current) { continue }
                latestEpisode[key] = value
            } else if value.state == .inProgress, let movie = loaded[ActivityKey(titleID: value.titleID, sourceID: value.sourceID)] {
                items.append(Item(title: movie, progress: value, isNextEpisode: false))
            }
        }
        for (key, episode) in latestEpisode {
            guard let series = loaded[key] else { continue }
            switch episode.state {
            case .inProgress:
                items.append(Item(title: series, progress: episode, isNextEpisode: false))
            case .watched where !finishedSeries.contains(key.titleID):
                items.append(Item(title: series, progress: episode, isNextEpisode: true))
            default:
                continue
            }
        }
        return items.sorted { WatchProgress.newestFirst($0.progress, $1.progress) }
    }

    /// True while a series has an episode the user has not finished.
    public static func hasUnwatched(_ episodes: [Episode], progress: [String: WatchProgress]) -> Bool {
        episodes.contains { progress[$0.id]?.state != .watched }
    }
}
