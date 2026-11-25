import AntennaCore
import Testing

/// The posters loaded ahead of the highlight or the scroll.
@Suite struct PosterPrefetchTests {
    @Test("movies-and-series-browsing/browsing-stays-responsive the next eight posters along a row load")
    func along() {
        #expect(PosterPrefetch.ahead(of: 0, count: 100) == 1..<9)
        #expect(PosterPrefetch.ahead(of: 40, count: 100) == 41..<49)
    }

    @Test("movies-and-series-browsing/browsing-stays-responsive nothing past the end of a row loads")
    func rowEnd() {
        #expect(PosterPrefetch.ahead(of: 95, count: 100) == 96..<100)
        #expect(PosterPrefetch.ahead(of: 99, count: 100).isEmpty)
        #expect(PosterPrefetch.ahead(of: 100, count: 100).isEmpty, "a position outside the row loads nothing")
        #expect(PosterPrefetch.ahead(of: -1, count: 100).isEmpty)
    }

    @Test("movies-and-series-browsing/browsing-stays-responsive the two rows under a row that shows load their start")
    func rowsBelow() {
        #expect(PosterPrefetch.below(row: 0, rowCount: 80) == 1..<3)
        #expect(PosterPrefetch.below(row: 78, rowCount: 80) == 79..<80)
        #expect(PosterPrefetch.below(row: 79, rowCount: 80).isEmpty)
        #expect(PosterPrefetch.start(count: 300) == 0..<8)
        #expect(PosterPrefetch.start(count: 3) == 0..<3)
        #expect(PosterPrefetch.start(count: 0).isEmpty)
    }
}
