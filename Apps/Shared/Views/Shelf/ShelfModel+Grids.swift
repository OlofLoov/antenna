import AntennaCore
import Foundation

/// Which grid list: a genre or every title, in one order.
struct SortedList: Hashable {
    var genre: String?
    var sort: ShelfSort
}

/// A grid list in its order and the index revision it was sorted from.
struct SortedTitles {
    var revision: Int
    var titles: [ShelfTitle]
}

// MARK: Grid lists

extension ShelfModel {
    /// The section's titles, or one genre's, in `sort` order, or nil while
    /// that order is worked out. Sorted once per index, so a grid's
    /// redraws do not sort again. A list of more than `sortsInPlace`
    /// titles is sorted away from the main actor by `sort(in:by:)`, and
    /// until it is ready the order from before the titles last changed
    /// shows (movies-and-series-browsing/browsing-stays-responsive).
    func titles(in genre: String? = nil, sortedBy sort: ShelfSort) -> [ShelfTitle]? {
        _ = sortedReady
        if genre == nil, sort == .recentlyAdded { return index.newest }
        let key = SortedList(genre: genre, sort: sort)
        if let kept = sortedLists[key], kept.revision == indexRevision { return kept.titles }
        let members = genre.map { Shelf.titles(in: $0, of: index.titles) } ?? index.titles
        guard members.count > Self.sortsInPlace else {
            let list = Shelf.sorted(members, by: sort)
            sortedLists[key] = SortedTitles(revision: indexRevision, titles: list)
            return list
        }
        return sortedLists[key]?.titles
    }

    /// Lists up to this long sort on the caller's actor, in a few milliseconds.
    static let sortsInPlace = 2_000

    /// Sorts the list `titles(in:sortedBy:)` has no order for yet, away
    /// from the main actor. Callers asking for the same list share one sort.
    func sort(in genre: String?, by sort: ShelfSort) async {
        let key = SortedList(genre: genre, sort: sort)
        let revision = indexRevision
        guard sortedLists[key]?.revision != revision, !(genre == nil && sort == .recentlyAdded) else { return }
        if let running = sorting[key], running.revision == revision {
            await running.task.value
            return
        }
        let all = index.titles
        let task = Task { await Self.sorted(all, genre: genre, by: sort) }
        sorting[key] = (revision, task)
        let list = await task.value
        guard revision == indexRevision else { return }
        sorting[key] = nil
        sortedLists[key] = SortedTitles(revision: revision, titles: list)
        sortedReady += 1
        sortedAway += 1
    }

    @concurrent
    private static func sorted(_ titles: [ShelfTitle], genre: String?, by sort: ShelfSort) async -> [ShelfTitle] {
        Shelf.sorted(genre.map { Shelf.titles(in: $0, of: titles) } ?? titles, by: sort)
    }
}
