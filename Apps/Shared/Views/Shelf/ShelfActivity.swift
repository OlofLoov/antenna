import AntennaCore
import Foundation
import Observation
import SwiftData

/// The current profile's saved positions and My list as the Movies and
/// Series sections read them (movies-and-series-browsing/keep-a-list-for-later,
/// movies-and-series-browsing/continue-watching). Reads again after every
/// save, on this device or from iCloud, so an open section follows changes
/// made elsewhere.
@MainActor @Observable
final class ShelfActivity {
    private(set) var progress: [WatchProgress] = []
    private(set) var movies: [ListEntry] = []
    private(set) var series: [ListEntry] = []
    @ObservationIgnored private var store: ActivityStore?
    private var listed: Set<ActivityKey> = []

    /// Reads `store` now and after every save to its container, until the
    /// calling task ends.
    func follow(_ store: ActivityStore) async {
        self.store = store
        reload()
        for await _ in ActivityStore.changes(in: store.context.container) {
            reload()
        }
    }

    func reload() {
        guard let store else { return }
        progress = store.allProgress()
        movies = store.myList(.movie)
        series = store.myList(.series)
        listed = Set((movies + series).map { ActivityKey(titleID: $0.titleID, sourceID: $0.sourceID) })
    }

    func isOnMyList(_ title: ShelfTitle) -> Bool {
        listed.contains(title.activityKey)
    }

    /// Adds a title to My list, or removes it with every copy.
    func toggleMyList(_ title: ShelfTitle) {
        guard let store else { return }
        if isOnMyList(title) {
            store.removeFromMyList(title.id, source: title.sourceID)
        } else {
            store.addToMyList(title.id, source: title.sourceID)
        }
        reload()
    }

    /// The loaded titles on My list of the section's kind, latest added
    /// first. Entries for titles not loaded are skipped and kept.
    func myList(_ model: ShelfModel) -> [ShelfTitle] {
        (model.kind == .movie ? movies : series).compactMap { entry in
            model.title(ActivityKey(titleID: entry.titleID, sourceID: entry.sourceID))
        }
    }

    /// Movies and series in progress together, most recent first. A series
    /// whose episode list shows nothing unwatched leaves the row.
    func continueWatching(_ library: ShelfLibrary) -> [ContinueWatching.Item] {
        let finished = ContinueWatching.finishedSeries(progress: progress, episodes: library.series.episodes)
        return ContinueWatching.items(
            progress: progress, titles: library.movies.titles + library.series.titles, finishedSeries: finished)
    }

    /// The saved position of a movie, for its poster's label.
    func progress(of title: ShelfTitle) -> WatchProgress? {
        progress.first { $0.titleID == title.id && $0.sourceID == title.sourceID }
    }
}
