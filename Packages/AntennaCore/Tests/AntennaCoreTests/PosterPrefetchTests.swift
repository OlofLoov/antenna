import AntennaCore
import Testing

/// The posters loaded ahead of the highlight or the scroll.
@Suite struct PosterPrefetchTests {
    @Test("movies-and-series-browsing/browsing-stays-responsive the next six posters along a row load")
    func along() {
        #expect(PosterPrefetch.ahead(of: 0, count: 100) == 1..<7)
        #expect(PosterPrefetch.ahead(of: 40, count: 100) == 41..<47)
    }

    @Test("movies-and-series-browsing/browsing-stays-responsive moving back along a row loads the posters before")
    func backward() {
        #expect(PosterPrefetch.ahead(of: 40, count: 100, going: .backward) == 34..<40)
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
        #expect(trail.shown(7, in: "drama", count: 100) == 8..<14, "a row's first poster loads forward")
        #expect(trail.shown(8, in: "drama", count: 100) == 9..<15)
        #expect(trail.shown(3, in: "drama", count: 100) == 0..<3, "scrolling back loads the posters before, never past the start")
        #expect(trail.shown(20, in: "comedy", count: 100) == 21..<27, "each row has its own direction")
        trail.forget("drama")
        #expect(trail.shown(2, in: "drama", count: 100) == 3..<9, "a row seen again starts forward")
    }

    @Test("movies-and-series-browsing/browsing-stays-responsive the next two rows in the scroll's direction load their first posters")
    func nextRow() {
        var trail = PosterPrefetch.Trail()
        let rows = PosterPrefetch.rowsAhead
        #expect(trail.shown(0, in: "movies", count: 80, along: rows) == 1..<3, "the two rows under the first")
        #expect(trail.shown(5, in: "movies", count: 80, along: rows) == 6..<8, "moving down, the rows under")
        #expect(trail.shown(3, in: "movies", count: 80, along: rows) == 1..<3, "moving up, the rows above")
        #expect(trail.shown(79, in: "series", count: 80, along: rows).isEmpty, "nothing past the last row")
        #expect(PosterPrefetch.start(count: 300, visible: 8) == 0..<8)
        #expect(PosterPrefetch.start(count: 3, visible: 8) == 0..<3)
        #expect(PosterPrefetch.start(count: 0, visible: 8).isEmpty)
    }

    // Found on 2026-11-25 with the large library at 50 MB: walking six rows down and up, each row that came
    // into view loaded the 3 posters past its first ones, which were never shown and pushed the posters about
    // to show out of memory. More posters were still loading with each walk: 14, then 30, then 50 of about 120.
    @Test("movies-and-series-browsing/browsing-stays-responsive a row coming into view loads nothing along it until it settles")
    func rowComingIntoView() {
        var trail = PosterPrefetch.Trail()
        let start = ContinuousClock.now
        for index in 0..<10 {
            #expect(trail.shown(index, in: "drama", count: 100, at: start + .milliseconds(10 * index)).isEmpty)
        }
        #expect(trail.shown(10, in: "drama", count: 100, at: start + .seconds(1)) == 11..<17, "a scroll along the row loads ahead")
        trail.forget("drama")
        #expect(trail.shown(0, in: "drama", count: 100, at: start + .seconds(2)).isEmpty, "back in view, it settles again")
        #expect(trail.remembers("drama"))
        trail.forget("drama")
        #expect(!trail.remembers("drama"), "a row that scrolled away is not remembered")
    }

    // Found on 2026-11-25 with the large library: each move between rows lands the Apple TV highlight a
    // poster to the right, so after one walk six rows down and up it sat on the eighth poster. The rows it
    // moved into scrolled sideways to posters nothing had loaded, and more were still loading with each
    // walk: 14, then 30, then 50 of about 120.
    @Test("movies-and-series-browsing/browsing-stays-responsive the rows by the highlight load the posters around its column")
    func aroundTheHighlight() {
        #expect(PosterPrefetch.around(nil, count: 100, visible: 8) == 0..<8, "no highlight, the row's start")
        #expect(PosterPrefetch.around(2, count: 100, visible: 8) == 0..<8, "within the first screen")
        #expect(PosterPrefetch.around(9, count: 100, visible: 8) == 5..<13)
        #expect(PosterPrefetch.around(98, count: 100, visible: 8) == 92..<100, "never past the end")
        #expect(PosterPrefetch.around(9, count: 5, visible: 8) == 0..<5, "a short row whole")
    }

    // Owner-found on 2026-11-28 on an Apple TV with a large Xtream catalogue: posters showed late as the
    // highlight moved down the rows, since only the rows right above and below it had loaded around its column.
    @Test("movies-and-series-browsing/browsing-stays-responsive the highlight loads two rows ahead of its move and one behind")
    func highlightWindow() {
        typealias Span = PosterPrefetch.Span
        let counts = Array(repeating: 100, count: 10)
        #expect(
            PosterPrefetch.aroundHighlight(row: 4, column: 0, counts: counts, visible: 8, going: .down)
                == [Span(row: 5, columns: 0..<8), Span(row: 3, columns: 0..<8), Span(row: 6, columns: 0..<8)],
            "moving down: the row under, the row above, then the second row under")
        #expect(
            PosterPrefetch.aroundHighlight(row: 4, column: 20, counts: counts, visible: 8, going: .up)
                == [Span(row: 3, columns: 16..<24), Span(row: 5, columns: 16..<24), Span(row: 2, columns: 16..<24)],
            "moving up: the rows above first, around the column")
        #expect(
            PosterPrefetch.aroundHighlight(row: 0, column: 0, counts: counts, visible: 8, going: .up) == [Span(row: 1, columns: 0..<8)],
            "the first row has nothing above it")
        #expect(
            PosterPrefetch.aroundHighlight(row: 9, column: 0, counts: counts, visible: 8, going: .down) == [Span(row: 8, columns: 0..<8)],
            "the last row has nothing under it")
        #expect(
            PosterPrefetch.aroundHighlight(row: 1, column: 30, counts: [100, 100, 5, 0], visible: 8, going: .down)
                == [Span(row: 2, columns: 0..<5), Span(row: 0, columns: 26..<34)],
            "a short row loads whole, an empty row nothing")
        #expect(PosterPrefetch.aroundHighlight(row: 12, column: 0, counts: counts, visible: 8).isEmpty, "a row outside the section")
    }

    @Test("movies-and-series-browsing/browsing-stays-responsive the highlight's direction follows its moves between rows")
    func highlightDirection() {
        var trail = PosterPrefetch.Trail()
        #expect(trail.highlight(in: 3, of: "focus.movies") == .down, "down at first")
        #expect(trail.highlight(in: 2, of: "focus.movies") == .up)
        #expect(trail.highlight(in: 2, of: "focus.movies") == .up, "a move along the row keeps the last direction")
        #expect(trail.highlight(in: 5, of: "focus.movies") == .down)
        #expect(trail.highlight(in: 0, of: "focus.series") == .down, "each section has its own")
        trail.forget("focus.movies")
        #expect(trail.highlight(in: 1, of: "focus.movies") == .down, "forgotten, down again")
    }

    @Test("movies-and-series-browsing/browsing-stays-responsive a row shows as many posters as fit its width")
    func visible() {
        #expect(PosterPrefetch.visible(width: 1_920, poster: 212, gap: 20, gutter: 80) == 8, "Apple TV, the eighth cut by the edge")
        #expect(PosterPrefetch.visible(width: 390, poster: 110, gap: 10, gutter: 16) == 4, "iPhone, the fourth cut")
        #expect(PosterPrefetch.visible(width: 0, poster: 110, gap: 10, gutter: 16) == 1, "no width yet")
    }
}
