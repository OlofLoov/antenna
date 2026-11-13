import AntennaCore
import Foundation
import Testing

/// The banner's words and paging, the catalogue a source loads and what the
/// section shows while sources load or fail.
@Suite struct ShelfSectionTests {
    let one = UUID()
    let two = UUID()

    private func movie(_ name: String, category: String? = "Thriller") -> ShelfTitle {
        ShelfTitle(id: "xtream#h#vod#1", kind: .movie, sourceID: one, name: name, category: category)
    }

    // MARK: Banner

    @Test("movies-and-series-browsing/new-titles-up-front the banner shows name, category, year, length and description")
    func bannerText() {
        let details = ShelfDetails(year: 2024, duration: 128 * 60, plot: " A harbour pilot. ", ageRating: "15")
        let text = BannerText(movie("The Long Harbor 4K"), details: details)
        #expect(text.eyebrow == "Recently added · Thriller")
        #expect(text.title == "The Long Harbor 4K")
        #expect(text.facts == ["2024", "2 h 08 min"])
        #expect(text.badges == ["4K", "15"])
        #expect(text.description == "A harbour pilot.")
        let bare = BannerText(movie("Salt Road", category: nil), details: nil)
        #expect(bare.eyebrow == "Recently added")
        #expect(bare.facts.isEmpty && bare.badges.isEmpty && bare.description == nil)
    }

    @Test("movies-and-series-browsing/series-work-the-same-way a series banner shows seasons, never badges")
    func seriesBanner() {
        let series = ShelfTitle(id: "xtream#h#series#1", kind: .series, sourceID: one, name: "Northern Lights 4K")
        let text = BannerText(series, details: ShelfDetails(year: 2021, seasons: 3, ageRating: "15"))
        #expect(text.facts == ["2021", "3 seasons"])
        #expect(text.badges.isEmpty)
    }

    @Test("movies-and-series-browsing/new-titles-up-front paging wraps at either end and Reduce Motion stops the clock")
    func pager() {
        var pager = BannerPager(count: 4)
        pager.page(-1)
        #expect(pager.index == 3)
        pager.page(1)
        #expect(pager.index == 0)
        pager.page(6)
        #expect(pager.index == 2)
        pager.resize(2)
        #expect(pager.index == 1)
        pager.resize(0)
        #expect(pager.index == 0)
        #expect(BannerPager.rotates(count: 4, interacting: false, reduceMotion: false))
        #expect(!BannerPager.rotates(count: 4, interacting: false, reduceMotion: true))
        #expect(!BannerPager.rotates(count: 4, interacting: true, reduceMotion: false))
        #expect(!BannerPager.rotates(count: 1, interacting: false, reduceMotion: false))
    }

    @Test("movies-and-series-browsing/new-titles-up-front the banner waits for the backdrop before it settles for the poster")
    func bannerArt() throws {
        let poster = try #require(URL(string: "http://h/poster.jpg"))
        let backdrop = try #require(URL(string: "http://h/backdrop.jpg"))
        #expect(BannerArt.choose(details: nil, answered: false, waited: false, poster: poster) == nil)
        #expect(BannerArt.choose(details: nil, answered: false, waited: true, poster: poster) == .poster(poster))
        #expect(BannerArt.choose(details: nil, answered: true, waited: false, poster: poster) == .poster(poster))
        #expect(BannerArt.choose(details: ShelfDetails(year: 2024), answered: true, waited: false, poster: poster) == .poster(poster))
        let wide = ShelfDetails(backdropURL: backdrop)
        #expect(BannerArt.choose(details: wide, answered: true, waited: false, poster: poster) == .backdrop(backdrop))
        #expect(BannerArt.choose(details: nil, answered: true, waited: true, poster: nil) == nil)
        #expect(BannerArt.poster(poster).url == poster)
    }

    // MARK: Catalogue

    @Test("movies-and-series-browsing/rows-in-a-predictable-order a source's titles take their category names in provider order")
    func catalogue() throws {
        let categories = try JSONDecoder().decode(
            [XtreamCategory].self,
            from: Data(
                #"[{"category_id":"2","category_name":"Drama"},{"category_id":"1","category_name":"Action"},{"category_id":"2","category_name":"Again"}]"#
                    .utf8))
        let movies = [VODItem(id: "xtream#h#vod#1", streamID: 1, name: "One", containerExtension: "mkv", categoryID: "2")]
        let catalogue = ShelfCatalogue(movies: movies, categories: categories, sourceID: one)
        #expect(catalogue.categories == ["Drama", "Action", "Again"])
        #expect(catalogue.titles.first?.category == "Drama", "a repeated id keeps its first name")
        #expect(catalogue.titles.first?.containerExtension == "mkv")
    }

    @Test("movies-and-series-browsing/rows-in-a-predictable-order category names make stable identifiers")
    func slugs() {
        #expect(ShelfText.slug("Kids & Family") == "kids-family")
        #expect(ShelfText.slug("  Action ") == "action")
        #expect(ShelfText.slug("Sci-Fi/Fantasy 4K") == "sci-fi-fantasy-4k")
        #expect(ShelfText.titles(1) == "1 title")
        #expect(ShelfText.titles(187) == "187 titles")
    }

    // MARK: Sources

    private func source(_ id: UUID, _ name: String, _ state: ShelfSourceState) -> ShelfSource {
        ShelfSource(id: id, name: name, state: state)
    }

    @Test("movies-and-series-browsing/when-sources-fail titles show under a banner naming each failed source")
    func someFailed() {
        let sources = [source(one, "Home", .loaded(titles: 3)), source(two, "Cabin", .failed)]
        #expect(ShelfStatus(sources: sources, kind: .movie) == .titles(banner: "Could not load Cabin", waiting: []))
        #expect(ShelfStatus(sources: sources, kind: .movie, dismissed: [two]) == .titles(banner: nil, waiting: []))
    }

    @Test("movies-and-series-browsing/when-sources-fail no source with titles says why")
    func noneLoaded() {
        let offline = [source(one, "Home", .offline), source(two, "Cabin", .offline)]
        #expect(ShelfStatus(sources: offline, kind: .movie) == .offline(waiting: []))
        let failed = [source(one, "Home", .failed), source(two, "Cabin", .waitingForLogin)]
        #expect(ShelfStatus(sources: failed, kind: .movie) == .failed(waiting: ["Cabin: waiting for its login to sync from iCloud"]))
        #expect(ShelfStatus.failedTitle(.movie) == "Could not load movies")
        #expect(ShelfStatus.failedTitle(.series) == "Could not load series")
    }

    @Test("movies-and-series-browsing/when-sources-fail every source with nothing gets a line")
    func nothing() {
        let sources = [source(one, "Home", .loaded(titles: 0)), source(two, "Cabin", .waitingForLogin)]
        #expect(
            ShelfStatus(sources: sources, kind: .series)
                == .empty(lines: ["Home: no series", "Cabin: waiting for its login to sync from iCloud"]))
    }

    @Test("movies-and-series-browsing/when-sources-fail loading until a source answers with titles")
    func loading() {
        let sources = [source(one, "Home", .loading), source(two, "Cabin", .failed)]
        #expect(ShelfStatus(sources: sources, kind: .movie) == .loading(sources))
        let waiting = source(two, "Cabin", .waitingForLogin)
        #expect(
            ShelfStatus(sources: [source(one, "Home", .loaded(titles: 1)), waiting], kind: .movie)
                == .titles(banner: nil, waiting: [waiting]))
    }
}
