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
    /// The ten newest searches, newest first (search/recent-searches).
    private(set) var searches: [String] = []
    @ObservationIgnored private var store: ActivityStore?
    private var listed: Set<ActivityKey> = []
    /// Each title's saved position, for posters' labels. A poster reads
    /// only its own, so a save redraws only the posters whose position
    /// changed (movies-and-series-browsing/browsing-stays-responsive).
    @ObservationIgnored private let positions = KeyedValues<ActivityKey, WatchProgress>()

    /// How long a change waits before the read, so a burst of changes,
    /// such as one iCloud import, makes one read.
    static let settle = Duration.milliseconds(250)

    /// When the last read started, and the store's history then.
    @ObservationIgnored private var readAt = ContinuousClock.now
    @ObservationIgnored private var historyMark: DefaultHistoryToken?
    /// Series with a saved episode, whose episode lists the library keeps.
    @ObservationIgnored private(set) var seriesWithProgress: Set<String> = []
    /// How many times the store was read. For tests.
    @ObservationIgnored private(set) var reads = 0

    /// Reads `store` now and after every change to its progress, My list
    /// or recent searches, on this device or from iCloud, until the calling
    /// task ends. A change that a read since has already seen, such as the
    /// one this object's own save just read, and a change to the history
    /// that touched no activity record, such as a favorite, read nothing
    /// (movies-and-series-browsing/browsing-stays-responsive).
    func follow(_ store: ActivityStore) async {
        self.store = store
        reload()
        for await change in ActivityStore.changes(in: store.context.container) {
            guard !Task.isCancelled else { break }
            guard isUnread(change) else { continue }
            try? await Task.sleep(for: Self.settle)
            guard !Task.isCancelled else { break }
            guard isUnread(change) else { continue }
            reload()
        }
    }

    private func isUnread(_ change: ActivityChange) -> Bool {
        guard change.at > readAt else { return false }
        switch change.kind {
        case .saved: return true
        case .history: return store?.activityChanged(after: historyMark) ?? false
        }
    }

    /// Reads the store. Only the lists that changed are handed on, so a
    /// save of one title's position redraws only what shows it.
    func reload() {
        guard let store else { return }
        readAt = .now
        historyMark = store.historyMark()
        reads += 1
        let progress = store.allProgress()
        if progress != self.progress {
            self.progress = progress
            var latest: [ActivityKey: WatchProgress] = [:]
            for saved in progress where latest[saved.key] == nil { latest[saved.key] = saved }
            positions.replace(with: latest)
            seriesWithProgress = Set(progress.compactMap(\.seriesID))
        }
        let movies = store.myList(.movie)
        let series = store.myList(.series)
        if movies != self.movies { self.movies = movies }
        if series != self.series { self.series = series }
        let searches = store.recentSearches().map(\.query)
        if searches != self.searches { self.searches = searches }
        let listed = Set((movies + series).map { ActivityKey(titleID: $0.titleID, sourceID: $0.sourceID) })
        if listed != self.listed { self.listed = listed }
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

    /// The section's titles the profile played on any device, finished ones
    /// included, most recent first (movies-and-series-browsing/recently-watched).
    func recentlyWatched(_ model: ShelfModel) -> [ShelfTitle] {
        RecentlyWatched.list(progress: progress, kind: model.kind, title: model.title)
    }

    /// Movies and series in progress together, most recent first. A series
    /// whose episode list shows nothing unwatched leaves the row.
    func continueWatching(_ library: ShelfLibrary) -> [ContinueWatching.Item] {
        let finished = ContinueWatching.finishedSeries(progress: progress, episodes: library.series.episodes)
        return ContinueWatching.items(
            progress: progress, title: { library.movies.title($0) ?? library.series.title($0) }, finishedSeries: finished)
    }

    /// Remembers a search whose result the user picked.
    func recordSearch(_ query: String) {
        store?.recordSearch(query)
        reload()
    }

    /// Saves where the user is in a movie or episode.
    func saveProgress(titleID: String, seriesID: String?, source: UUID, position: Double, duration: Double?) {
        store?.saveProgress(titleID: titleID, seriesID: seriesID, source: source, position: position, duration: duration)
        reload()
    }

    /// The saved position of a movie, for its poster's label.
    func progress(of title: ShelfTitle) -> WatchProgress? {
        positions.value(title.activityKey)
    }
}

extension WatchProgress {
    fileprivate var key: ActivityKey { ActivityKey(titleID: titleID, sourceID: sourceID) }
}
