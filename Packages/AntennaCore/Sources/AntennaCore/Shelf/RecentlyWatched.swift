import Foundation

/// The Recently watched row of Movies or Series, from the profile's synced
/// progress (movies-and-series-browsing/recently-watched).
public enum RecentlyWatched {
    /// The titles of `kind` the profile played, finished ones included, most
    /// recent first, each once, at most `limit`. Episodes count for their series. Progress
    /// for a title that is not in `titles` is left out.
    public static func list(progress: [WatchProgress], titles: [ShelfTitle], kind: ShelfTitle.Kind, limit: Int = 20) -> [ShelfTitle] {
        let loaded = Dictionary(
            titles.filter { $0.kind == kind }.map { ($0.activityKey, $0) }, uniquingKeysWith: { first, _ in first })
        var latest: [ActivityKey: WatchProgress] = [:]
        for value in progress where value.isUsable {
            let key: ActivityKey
            switch (kind, value.seriesID) {
            case (.movie, nil): key = ActivityKey(titleID: value.titleID, sourceID: value.sourceID)
            case (.series, let seriesID?): key = ActivityKey(titleID: seriesID, sourceID: value.sourceID)
            default: continue
            }
            guard loaded[key] != nil else { continue }
            if let current = latest[key], !WatchProgress.newestFirst(value, current) { continue }
            latest[key] = value
        }
        return latest.sorted { WatchProgress.newestFirst($0.value, $1.value) }.prefix(limit).compactMap { loaded[$0.key] }
    }
}
