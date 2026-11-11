import Foundation

extension ShelfText {
    /// What VoiceOver reads for a poster: the title, the year when the name
    /// has one and, while in progress, the minutes left
    /// (movies-and-series-browsing/rows-in-a-predictable-order).
    public static func posterLabel(_ title: ShelfTitle, progress: WatchProgress?) -> String {
        let left = progress.flatMap { $0.state == .inProgress ? ShelfText.left($0) : nil }
        return [title.name, title.year.map(String.init), left].compactMap(\.self).joined(separator: ", ")
    }

    /// "S2 E4", "E4" without a season, or nil without a number.
    public static func episodeCode(_ episode: Episode) -> String? {
        guard let number = episode.number else { return nil }
        return [episode.season.map { "S\($0)" }, "E\(number)"].compactMap(\.self).joined(separator: " ")
    }

    /// The line under a Continue watching card after the title: the minutes
    /// left for a movie; "Next episode", or the season and episode, for a
    /// series. `episode` is the episode the progress belongs to, once the
    /// series' episodes are known.
    public static func continueCaption(_ item: ContinueWatching.Item, episode: Episode?) -> String? {
        guard item.title.kind == .series else { return left(item.progress) }
        if item.isNextEpisode { return "Next episode" }
        return episode.flatMap(episodeCode) ?? left(item.progress)
    }
}

extension ContinueWatching {
    /// The series among `progress` whose episode lists show nothing left to
    /// watch. `episodes` holds the lists known so far, by series id; a series
    /// without a known list is never finished.
    public static func finishedSeries(progress: [WatchProgress], episodes: [String: [Episode]]) -> Set<String> {
        let byEpisode = Dictionary(progress.map { ($0.titleID, $0) }, uniquingKeysWith: { first, _ in first })
        return Set(
            episodes.compactMap { seriesID, list in
                !list.isEmpty && !hasUnwatched(list, progress: byEpisode) ? seriesID : nil
            })
    }

    /// The progress of a series' episodes by episode id, for `SeriesPlayTarget`.
    public static func episodeProgress(_ progress: [WatchProgress], seriesID: String, sourceID: UUID) -> [String: WatchProgress] {
        Dictionary(
            progress.filter { $0.seriesID == seriesID && $0.sourceID == sourceID }.map { ($0.titleID, $0) },
            uniquingKeysWith: { first, _ in first })
    }
}
