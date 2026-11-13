import AntennaCore
import Foundation
import Testing

/// The Movies and Series sections' banner, rows, Continue watching and words.
@Suite struct ShelfTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let one = UUID()
    let two = UUID()

    private func movie(_ id: Int, source: UUID? = nil, daysAgo: Double? = nil, category: String? = nil) -> ShelfTitle {
        ShelfTitle(
            id: "xtream#h#vod#\(id)", kind: .movie, sourceID: source ?? one, name: "Movie \(id)",
            added: daysAgo.map { now.addingTimeInterval(-$0 * 86_400) }, category: category)
    }

    private func series(_ id: Int) -> ShelfTitle {
        ShelfTitle(id: "xtream#h#series#\(id)", kind: .series, sourceID: one, name: "Series \(id)")
    }

    private func progress(
        _ title: String, series: String? = nil, at position: Double, of length: Double? = 100, saved offset: TimeInterval
    ) -> WatchProgress {
        WatchProgress(
            id: title, titleID: title, seriesID: series, sourceID: one, position: position, duration: length,
            updatedAt: now.addingTimeInterval(offset))
    }

    // MARK: Banner and rows

    @Test("movies-and-series-browsing/new-titles-up-front the four newest from every source, filled in provider order")
    func banner() {
        let titles = [movie(1, daysAgo: 9), movie(2, source: two, daysAgo: 1), movie(3), movie(4, daysAgo: 3), movie(5)]
        #expect(Shelf.banner(titles).map(\.id) == ["xtream#h#vod#2", "xtream#h#vod#4", "xtream#h#vod#1", "xtream#h#vod#3"])
        #expect(Shelf.banner([movie(1)]).count == 1)
    }

    @Test("movies-and-series-browsing/rows-in-a-predictable-order Recently added first, then categories in provider order with counts")
    func rows() {
        let titles = [
            movie(1, daysAgo: 40, category: "Drama"), movie(2, daysAgo: 2, category: "Action"), movie(3, category: "Drama"),
            movie(4, daysAgo: 10), movie(5, source: two, daysAgo: 1, category: "Drama"),
        ]
        let rows = Shelf.rows(titles, categoryOrder: ["Action", "Empty", "Drama"], now: now)
        #expect(rows.map(\.name) == ["Recently added", "Action", "Drama"], "a category without titles has no row")
        #expect(rows[0].titles.map(\.id).prefix(4) == ["xtream#h#vod#5", "xtream#h#vod#2", "xtream#h#vod#4", "xtream#h#vod#1"])
        #expect(rows[0].titles.last?.id == "xtream#h#vod#3", "undated titles follow dated ones")
        #expect(rows[0].count == 3, "added in the last 30 days")
        #expect(rows[2].count == 3, "two sources' Drama make one row")
        #expect(rows[2].titles.map(\.sourceID) == [one, one, two])
        #expect(!rows.dropFirst().contains { $0.titles.contains { $0.category == nil } }, "no category, Recently added only")
        #expect(Shelf.rows([], categoryOrder: ["Drama"], now: now).isEmpty)
    }

    @Test("movies-and-series-browsing/rows-in-a-predictable-order Recently added holds fifty, and category order merges sources")
    func recentCapAndOrder() {
        let many = (0..<70).map { movie($0, daysAgo: Double($0)) }
        #expect(Shelf.rows(many, categoryOrder: [], now: now).first?.titles.count == 50)
        #expect(Shelf.categoryOrder([["Action", "Drama"], ["Kids", "Drama", "Action", "Docs"]]) == ["Action", "Drama", "Kids", "Docs"])
    }

    @Test("movies-and-series-browsing/see-everything-new every title newest first, undated ones after in provider order")
    func seeAllNew() {
        let titles = (0..<60).map { movie($0, daysAgo: $0.isMultiple(of: 3) ? nil : Double($0)) }
        let grid = Shelf.sorted(titles, by: .recentlyAdded)
        #expect(grid.count == 60, "every title, not Recently added's fifty")
        #expect(grid.first?.id == "xtream#h#vod#1")
        #expect(grid.suffix(20).map(\.id) == stride(from: 0, to: 60, by: 3).map { "xtream#h#vod#\($0)" })
    }

    @Test("movies-and-series-browsing/series-work-the-same-way series order by when they last changed")
    func seriesOrder() throws {
        let body = #"[{"series_id":1,"name":"Old","last_modified":"1700000000"},{"series_id":2,"name":"New","last_modified":"1790000000"}]"#
        let newer = try XtreamClient.decodeSeriesList(Data(body.utf8), host: "h").items
        let titles = newer.map { ShelfTitle(series: $0, sourceID: one, categories: [:]) }
        #expect(Shelf.banner(titles).map(\.name) == ["New", "Old"])
        #expect(ShelfText.seasons(1) == "1 season")
        #expect(ShelfText.seasons(3) == "3 seasons")
        #expect(ShelfText.seasons(0) == nil)
    }

    // MARK: Continue watching

    @Test("movies-and-series-browsing/continue-watching movies and series together, most recent first, finished movies gone")
    func continueWatching() {
        let titles = [movie(1), movie(2), movie(3), series(7), series(8)]
        let saved = [
            progress("xtream#h#vod#1", at: 50, saved: 10),
            progress("xtream#h#vod#2", at: 99, saved: 20),
            progress("xtream#h#vod#3", at: 1, saved: 30),
            progress("xtream#h#episode#71", series: "xtream#h#series#7", at: 99, saved: 5),
            progress("xtream#h#episode#72", series: "xtream#h#series#7", at: 30, saved: 40),
            progress("xtream#h#episode#81", series: "xtream#h#series#8", at: 97, saved: 50),
        ]
        let items = ContinueWatching.items(progress: saved, titles: titles)
        #expect(items.map(\.id) == ["xtream#h#series#8", "xtream#h#series#7", "xtream#h#vod#1"])
        #expect(items.map(\.isNextEpisode) == [true, false, false], "a finished episode shows Next episode")
        #expect(items[1].progress.titleID == "xtream#h#episode#72", "the series' latest episode")
        let done = ContinueWatching.items(progress: saved, titles: titles, finishedSeries: ["xtream#h#series#8"])
        #expect(done.map(\.id) == ["xtream#h#series#7", "xtream#h#vod#1"], "no unwatched episode left")
        #expect(ContinueWatching.items(progress: [progress("xtream#h#vod#3", at: 1, saved: 0)], titles: titles).isEmpty)
    }

    @Test("movies-and-series-browsing/continue-watching a title that is not loaded is not shown")
    func notLoaded() {
        let saved = [
            progress("xtream#h#vod#9", at: 50, saved: 0), progress("xtream#h#episode#1", series: "xtream#h#series#9", at: 50, saved: 0),
        ]
        #expect(ContinueWatching.items(progress: saved, titles: [movie(1)]).isEmpty)
    }

    @Test("movies-and-series-browsing/play-a-series-from-the-next-episode the poster follows the title page's Play")
    func seriesPosterPlays() throws {
        let episodes = (1...3).map { Episode(id: "e\($0)", episodeID: $0, season: 1, number: $0, title: "Episode \($0)") }
        let watched = progress("e1", at: 98, saved: 0)
        let partway = progress("e2", at: 40, saved: 1)
        let pick = try #require(SeriesPlayTarget.resolve(episodes: episodes, progress: ["e1": watched, "e2": partway]))
        #expect(pick.episode.id == "e2")
        #expect(pick.resumes && pick.position == 40)
        #expect(try #require(SeriesPlayTarget.resolve(episodes: episodes, progress: [:])).episode.id == "e1")
        let skippedPilot = try #require(SeriesPlayTarget.resolve(episodes: episodes, progress: ["e2": progress("e2", at: 99, saved: 0)]))
        #expect(skippedPilot.episode.id == "e3", "after the last one finished, not back to the pilot")
        let all = Dictionary(uniqueKeysWithValues: episodes.map { ($0.id, progress($0.id, at: 99, saved: 0)) })
        #expect(!ContinueWatching.hasUnwatched(episodes, progress: all))
        let again = try #require(SeriesPlayTarget.resolve(episodes: episodes, progress: all))
        #expect(again.episode.id == "e1" && !again.resumes, "all finished, the first from the start")
        #expect(SeriesPlayTarget.resolve(episodes: [], progress: [:]) == nil)
    }

    @Test("movies-and-series-browsing/resume-where-you-left-off part-way resumes, barely started or finished starts over")
    func resume() {
        #expect(progress("m", at: 40, saved: 0).resumePosition == 40)
        #expect(progress("m", at: 1, saved: 0).resumePosition == 0)
        #expect(progress("m", at: 96, saved: 0).resumePosition == 0)
    }

    // MARK: Words

    @Test("movies-and-series-browsing/continue-watching minutes left and lengths")
    func words() {
        #expect(ShelfText.length(128 * 60) == "2 h 08 min")
        #expect(ShelfText.length(60 * 60) == "1 h 00 min")
        #expect(ShelfText.length(47 * 60 + 10) == "47 min")
        #expect(ShelfText.length(20) == "1 min")
        #expect(ShelfText.length(nil) == nil)
        #expect(ShelfText.length(0) == nil)
        #expect(ShelfText.left(progress("m", at: 1200, of: 3000, saved: 0)) == "30 min left")
        #expect(ShelfText.left(progress("m", at: 1201, of: 3000, saved: 0)) == "30 min left", "rounded up")
        #expect(ShelfText.left(progress("m", at: 10, of: nil, saved: 0)) == nil)
    }

    @Test("movies-and-series-browsing/new-titles-up-front 4K and age badges follow the badge rules")
    func badges() {
        #expect(ShelfText.is4K("Dune 2160p"))
        #expect(ShelfText.is4K("Dune [uhd]"))
        #expect(ShelfText.is4K("Dune 4k HDR"))
        #expect(!ShelfText.is4K("Dune 1080p"))
        for rating in ["0", "12", "21", "PG-13", "TV-MA", "12A", " 15 "] { #expect(ShelfText.ageBadge(rating) != nil, "\(rating)") }
        for rating in ["22", "07", "-1", "Unrated", "pg", "", nil] as [String?] { #expect(ShelfText.ageBadge(rating) == nil) }
    }
}
