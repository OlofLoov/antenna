import AntennaCore
import Testing

/// The posters loaded ahead of the highlight or the scroll.
@Suite struct PosterPrefetchTests {
    @Test("movies-and-series-browsing/browsing-stays-responsive the next three posters along a row load")
    func along() {
        #expect(PosterPrefetch.ahead(of: 0, count: 100) == 1..<4)
        #expect(PosterPrefetch.ahead(of: 40, count: 100) == 41..<44)
    }

    @Test("movies-and-series-browsing/browsing-stays-responsive moving back along a row loads the posters before")
    func backward() {
        #expect(PosterPrefetch.ahead(of: 40, count: 100, going: .backward) == 37..<40)
        #expect(PosterPrefetch.ahead(of: 1, count: 100, going: .backward) == 0..<1)
        #expect(PosterPrefetch.ahead(of: 0, count: 100, going: .backward).isEmpty)
    }

    @Test("movies-and-series-browsing/browsing-stays-responsive nothing past the end of a row loads")
    func rowEnd() {
        #expect(PosterPrefetch.ahead(of: 98, count: 100) == 99..<100)
        #expect(PosterPrefetch.ahead(of: 99, count: 100).isEmpty)
        #expect(PosterPrefetch.ahead(of: 100, count: 100).isEmpty, "a position outside the row loads nothing")
        #expect(PosterPrefetch.ahead(of: -1, count: 100).isEmpty)
    }

    @Test("movies-and-series-browsing/browsing-stays-responsive the direction of travel follows the posters that show")
    func trail() {
        var trail = PosterPrefetch.Trail()
        #expect(trail.shown(7, in: "drama", count: 100) == 8..<11, "a row's first poster loads forward")
        #expect(trail.shown(8, in: "drama", count: 100) == 9..<12)
        #expect(trail.shown(3, in: "drama", count: 100) == 0..<3, "scrolling back loads the posters before")
        #expect(trail.shown(20, in: "comedy", count: 100) == 21..<24, "each row has its own direction")
        trail.forget("drama")
        #expect(trail.shown(2, in: "drama", count: 100) == 3..<6, "a row seen again starts forward")
    }

    @Test("movies-and-series-browsing/browsing-stays-responsive the next row in the scroll's direction loads the posters it shows first")
    func nextRow() {
        var trail = PosterPrefetch.Trail()
        let rows = PosterPrefetch.rowsAhead
        #expect(trail.shown(0, in: "movies", count: 80, along: rows) == 1..<2, "the row under the first")
        #expect(trail.shown(5, in: "movies", count: 80, along: rows) == 6..<7, "moving down, the row under")
        #expect(trail.shown(3, in: "movies", count: 80, along: rows) == 2..<3, "moving up, the row above")
        #expect(trail.shown(79, in: "series", count: 80, along: rows).isEmpty, "nothing past the last row")
        #expect(PosterPrefetch.start(count: 300, visible: 8) == 0..<8)
        #expect(PosterPrefetch.start(count: 3, visible: 8) == 0..<3)
        #expect(PosterPrefetch.start(count: 0, visible: 8).isEmpty)
    }

    @Test("movies-and-series-browsing/browsing-stays-responsive a row shows as many posters as fit its width")
    func visible() {
        #expect(PosterPrefetch.visible(width: 1_920, poster: 212, gap: 20, gutter: 80) == 8, "Apple TV, the eighth cut by the edge")
        #expect(PosterPrefetch.visible(width: 390, poster: 110, gap: 10, gutter: 16) == 4, "iPhone, the fourth cut")
        #expect(PosterPrefetch.visible(width: 0, poster: 110, gap: 10, gutter: 16) == 1, "no width yet")
    }
}
