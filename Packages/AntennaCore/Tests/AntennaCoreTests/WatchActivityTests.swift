import AntennaCore
import Foundation
import Testing

/// The rules every device applies to progress, My list and recent searches.
@Suite struct WatchActivityTests {
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    let source = UUID()
    let movie = "xtream#h#vod#1"

    private func progress(
        _ id: String, title: String? = nil, series: String? = nil, source: UUID?? = nil, at position: Double, of duration: Double? = 100,
        saved offset: TimeInterval = 0
    ) -> WatchProgress {
        WatchProgress(
            id: id, titleID: title ?? movie, seriesID: series, sourceID: source ?? self.source, position: position, duration: duration,
            updatedAt: start.addingTimeInterval(offset))
    }

    // MARK: Progress

    @Test("watch-progress-sync/devices-that-disagree-settle-on-the-same-answer latest save, then higher position, then lower id")
    func progressTieBreaks() {
        let early = progress("a", at: 50, saved: 0)
        let late = progress("b", at: 10, saved: 5)
        #expect(WatchProgress.resolve([early, late]).winners == [late], "the latest save")
        #expect(WatchProgress.resolve([late, early]).winners == [late], "whatever order they arrive in")
        #expect(WatchProgress.resolve([early, late]).losers == [0])

        let lower = progress("c", at: 10, saved: 5)
        let higher = progress("d", at: 30, saved: 5)
        #expect(WatchProgress.resolve([lower, higher]).winners == [higher], "same time, the higher position")

        let first = progress("e", at: 30, saved: 5)
        let second = progress("f", at: 30, saved: 5)
        #expect(WatchProgress.resolve([second, first]).winners == [first], "all equal, the lower id")
        #expect(WatchProgress.resolve([second, first]).losers == [0])
    }

    @Test("watch-progress-sync/devices-that-disagree-settle-on-the-same-answer one answer per title and source")
    func progressPerTitleAndSource() {
        let other = UUID()
        let copies = [
            progress("a", at: 10), progress("b", source: other, at: 20), progress("c", title: "xtream#h#vod#2", at: 30),
        ]
        let resolved = WatchProgress.resolve(copies)
        #expect(resolved.winners.count == 3)
        #expect(resolved.losers.isEmpty)
    }

    @Test("watch-progress-sync/devices-that-disagree-settle-on-the-same-answer damaged copies are skipped and never deleted")
    func damagedProgress() {
        let copies = [
            progress("a", title: "", at: 10), progress("b", source: .some(nil), at: 10), progress("c", at: -1),
            progress("d", at: .nan), progress("e", at: .infinity), progress("f", at: 10, of: .nan),
        ]
        let resolved = WatchProgress.resolve(copies)
        #expect(resolved.winners.map(\.id) == ["f"], "a bad length reads as unknown, the rest are skipped")
        #expect(resolved.losers.isEmpty, "nothing damaged is deleted")
        #expect(copies[5].knownDuration == nil)
    }

    @Test("watch-progress-sync/devices-that-disagree-settle-on-the-same-answer a save after reading a later clock still wins")
    func stampAfterLaterClock() {
        let now = start
        let ahead = start.addingTimeInterval(3600)
        #expect(WatchProgress.stamp(now: now, replacing: nil) == now)
        #expect(WatchProgress.stamp(now: now, replacing: start.addingTimeInterval(-60)) == now)
        let stamped = WatchProgress.stamp(now: now, replacing: ahead)
        #expect(stamped > ahead)
        let saved = progress("z", at: 5, saved: stamped.timeIntervalSince(start))
        #expect(WatchProgress.resolve([progress("y", at: 90, saved: 3600), saved]).winners == [saved], "the new position replaces it")
    }

    @Test("watch-progress-sync/progress-is-saved-and-read-back title ids that could carry a link or login are refused")
    func storableTitleIDs() {
        #expect(WatchProgress.isStorable(titleID: "xtream#host.tv#vod#55"))
        #expect(!WatchProgress.isStorable(titleID: ""))
        #expect(!WatchProgress.isStorable(titleID: "http://host/movie/u/p/55.mkv"))
        #expect(!WatchProgress.isStorable(titleID: "xtream#user@host#vod#55"))
    }

    @Test(
        "watch-progress-sync/in-progress-and-watched-mean-the-same-everywhere 2% and 95% split not started, in progress and watched",
        arguments: [
            (1.9, WatchState.notStarted, 0.0), (2, .inProgress, 2), (50, .inProgress, 50), (94.9, .inProgress, 94.9), (95, .watched, 0),
            (100, .watched, 0), (120, .watched, 0),
        ])
    func thresholds(position: Double, state: WatchState, resume: Double) {
        let value = progress("a", at: position, of: 100)
        #expect(value.state == state)
        #expect(value.resumePosition == resume)
    }

    @Test("watch-progress-sync/in-progress-and-watched-mean-the-same-everywhere no known length is never in progress or watched")
    func unknownLength() {
        for length in [nil, 0, -5, Double.nan, .infinity] as [Double?] {
            let value = progress("a", at: 40, of: length)
            #expect(value.state == .notStarted)
            #expect(value.resumePosition == 0)
        }
    }

    @Test("watch-progress-sync/in-progress-and-watched-mean-the-same-everywhere watching a finished title again puts it back in progress")
    func watchAgain() {
        let watched = progress("a", at: 98, saved: 0)
        let again = progress("a", at: 12, saved: 60)
        #expect(watched.state == .watched)
        #expect(WatchProgress.resolve([watched, again]).winners.first?.state == .inProgress)
    }

    @Test("watch-progress-sync/a-series-shows-progress-for-each-of-its-episodes a series lists its episodes, most recent first")
    func seriesEpisodes() {
        let series = "xtream#h#series#7"
        let all = [
            progress("m", at: 10, saved: 30), progress("e1", title: "xtream#h#episode#1", series: series, at: 10, saved: 10),
            progress("e2", title: "xtream#h#episode#2", series: series, at: 10, saved: 20),
            progress("x", title: "xtream#h#episode#9", series: "xtream#h#series#8", at: 10, saved: 40),
        ]
        #expect(WatchProgress.episodes(of: series, in: all).map(\.id) == ["e2", "e1"])
    }

    // MARK: My list

    private func entry(_ id: String, title: String? = nil, source: UUID?? = nil, added offset: TimeInterval = 0) -> ListEntry {
        ListEntry(id: id, titleID: title ?? movie, sourceID: source ?? self.source, addedAt: start.addingTimeInterval(offset))
    }

    @Test("watch-progress-sync/devices-that-disagree-settle-on-the-same-answer one My list entry: the earliest added, then the lower id")
    func listTieBreaks() {
        #expect(ListEntry.resolve([entry("b", added: 5), entry("a", added: 9)]).winners.map(\.id) == ["b"])
        #expect(ListEntry.resolve([entry("b", added: 5), entry("a", added: 5)]).winners.map(\.id) == ["a"])
        #expect(ListEntry.resolve([entry("b", added: 5), entry("a", added: 5)]).losers == [0])
        #expect(ListEntry.resolve([entry("a", title: ""), entry("b", source: .some(nil))]).winners.isEmpty)
        #expect(ListEntry.resolve([entry("a", title: ""), entry("b", source: .some(nil))]).losers.isEmpty)
    }

    @Test("watch-progress-sync/my-list-shows-movies-and-series-separately movies and series apart, newest first, others kept out")
    func listByKind() {
        let entries = [
            entry("m1", title: "xtream#h#vod#1", added: 1), entry("s1", title: "xtream#h#series#1", added: 2),
            entry("m2", title: "xtream#h#vod#2", added: 3), entry("l", title: "xtream#h#5", added: 4),
            entry("o", title: "jellyfin#x#movie#1", added: 5),
        ]
        #expect(ListEntry.list(.movie, in: entries).map(\.id) == ["m2", "m1"])
        #expect(ListEntry.list(.series, in: entries).map(\.id) == ["s1"])
        #expect(ListEntry.resolve(entries).winners.count == 5, "other kinds are kept")
    }

    // MARK: Recent searches

    private func search(_ id: String, _ query: String, at offset: TimeInterval) -> RecentSearch {
        RecentSearch(id: id, query: query, updatedAt: start.addingTimeInterval(offset))
    }

    @Test("watch-progress-sync/recent-searches-stay-short-and-tidy blanks are ignored, whitespace tidied, long searches cut")
    func tidy() {
        #expect(RecentSearch.tidy("   ") == nil)
        #expect(RecentSearch.tidy("") == nil)
        #expect(RecentSearch.tidy("  the   last\tof us ") == "the last of us")
        let long = String(repeating: "a", count: 150)
        #expect(RecentSearch.tidy(long)?.count == 100)
        #expect(RecentSearch.tidy(String(repeating: "a", count: 99) + " b")?.count == 99, "no trailing space after the cut")
    }

    @Test("watch-progress-sync/recent-searches-stay-short-and-tidy case and accents make one search, keeping the latest spelling")
    func foldedSearches() {
        #expect(RecentSearch.fold("Amélie") == RecentSearch.fold("  amelie "))
        #expect(RecentSearch.fold("Ö") == RecentSearch.fold("o"))
        let resolved = RecentSearch.resolve([search("a", "amelie", at: 1), search("b", "Amélie", at: 2), search("c", "dune", at: 0)])
        #expect(resolved.winners.map(\.query) == ["Amélie", "dune"], "newest first, latest spelling")
        #expect(resolved.losers == [0])
    }

    @Test("watch-progress-sync/recent-searches-stay-short-and-tidy only the ten newest are kept")
    func searchCap() {
        let searches = (0..<13).map { search("s\($0)", "query \($0)", at: Double($0)) }
        let resolved = RecentSearch.resolve(searches.shuffled())
        #expect(resolved.winners.map(\.query) == (3..<13).reversed().map { "query \($0)" })
        #expect(resolved.losers.count == 3)
        #expect(RecentSearch.resolve([search("x", "  ", at: 0)]).losers.isEmpty, "a blank record is skipped, not deleted")
    }

    @Test("watch-progress-sync/recent-searches-from-an-earlier-build-carry-over old searches keep their order, one second apart")
    func carriedOver() {
        let moved = RecentSearch.carriedOver(["newest", " ", "older", "oldest"], now: start)
        #expect(moved.map(\.query) == ["newest", "older", "oldest"])
        #expect(moved.map(\.updatedAt) == [start, start.addingTimeInterval(-1), start.addingTimeInterval(-2)])
    }
}
