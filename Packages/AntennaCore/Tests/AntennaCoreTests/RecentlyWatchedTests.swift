import AntennaCore
import Foundation
import Testing

/// The Recently watched row of Movies and Series.
@Suite struct RecentlyWatchedTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let one = UUID()
    let two = UUID()

    private func movie(_ id: Int, source: UUID? = nil) -> ShelfTitle {
        ShelfTitle(id: "xtream#h#vod#\(id)", kind: .movie, sourceID: source ?? one, name: "Movie \(id)")
    }

    private func series(_ id: Int) -> ShelfTitle {
        ShelfTitle(id: "xtream#h#series#\(id)", kind: .series, sourceID: one, name: "Series \(id)")
    }

    private func progress(_ title: String, series: String? = nil, source: UUID? = nil, at spot: Double, saved: Double) -> WatchProgress {
        WatchProgress(
            id: title, titleID: title, seriesID: series, sourceID: source ?? one, position: spot, duration: 100,
            updatedAt: now.addingTimeInterval(saved))
    }

    @Test("movies-and-series-browsing/recently-watched movies most recent first, finished ones included")
    func movies() {
        let titles = [movie(1), movie(2), movie(3), series(7)]
        let saved = [
            progress("xtream#h#vod#1", at: 99, saved: -86_400),
            progress("xtream#h#vod#2", at: 40, saved: 0),
            progress("xtream#h#episode#71", series: "xtream#h#series#7", at: 99, saved: 10),
        ]
        let list = RecentlyWatched.list(progress: saved, titles: titles, kind: .movie)
        #expect(list.map(\.id) == ["xtream#h#vod#2", "xtream#h#vod#1"], "today's then yesterday's, no series")
    }

    @Test("movies-and-series-browsing/recently-watched episodes show their series once")
    func series() {
        let titles = [movie(1), series(7), series(8)]
        let saved = [
            progress("xtream#h#episode#71", series: "xtream#h#series#7", at: 99, saved: 10),
            progress("xtream#h#episode#72", series: "xtream#h#series#7", at: 20, saved: 30),
            progress("xtream#h#episode#81", series: "xtream#h#series#8", at: 50, saved: 20),
            progress("xtream#h#vod#1", at: 40, saved: 50),
        ]
        let list = RecentlyWatched.list(progress: saved, titles: titles, kind: .series)
        #expect(list.map(\.id) == ["xtream#h#series#7", "xtream#h#series#8"])
    }

    @Test("movies-and-series-browsing/recently-watched titles no longer listed are left out, and the row holds twenty")
    func leftOutAndCapped() {
        let saved = [progress("xtream#h#vod#9", at: 50, saved: 0), progress("xtream#h#vod#1", source: two, at: 50, saved: 0)]
        #expect(RecentlyWatched.list(progress: saved, titles: [movie(1)], kind: .movie).isEmpty, "another source's copy is not this one")
        let many = (0..<30).map { movie($0) }
        let watched = (0..<30).map { progress("xtream#h#vod#\($0)", at: 50, saved: Double($0)) }
        let list = RecentlyWatched.list(progress: watched, titles: many, kind: .movie)
        #expect(list.count == 20)
        #expect(list.first?.id == "xtream#h#vod#29")
        #expect(RecentlyWatched.list(progress: [], titles: many, kind: .movie).isEmpty)
    }
}
