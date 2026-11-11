import AntennaCore
import Foundation
import Testing

/// Poster labels, Continue watching captions and when a series is finished.
@Suite struct ShelfCaptionTests {
    let source = UUID()
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func progress(_ id: String, series: String? = nil, at position: Double, of length: Double = 3000) -> WatchProgress {
        WatchProgress(id: id, titleID: id, seriesID: series, sourceID: source, position: position, duration: length, updatedAt: now)
    }

    private let movie = ShelfTitle(id: "xtream#h#vod#1", kind: .movie, sourceID: UUID(), name: "Dune (2021)")
    private let series = ShelfTitle(id: "xtream#h#series#1", kind: .series, sourceID: UUID(), name: "Northern Lights")

    @Test("movies-and-series-browsing/rows-in-a-predictable-order VoiceOver reads title, year and minutes left")
    func posterLabel() {
        #expect(ShelfText.posterLabel(movie, progress: nil) == "Dune (2021), 2021")
        #expect(ShelfText.posterLabel(movie, progress: progress("m", at: 1200)) == "Dune (2021), 2021, 30 min left")
        #expect(ShelfText.posterLabel(series, progress: progress("m", at: 2990)) == "Northern Lights", "a finished title has none left")
    }

    @Test("movies-and-series-browsing/continue-watching cards say the minutes left, or the season and episode")
    func captions() {
        let movieItem = ContinueWatching.Item(title: movie, progress: progress("m", at: 1200), isNextEpisode: false)
        #expect(ShelfText.continueCaption(movieItem, episode: nil) == "30 min left")
        let episode = Episode(id: "e", episodeID: 4, season: 2, number: 4, title: "Four")
        let partway = ContinueWatching.Item(title: series, progress: progress("e", at: 600), isNextEpisode: false)
        #expect(ShelfText.continueCaption(partway, episode: episode) == "S2 E4")
        #expect(ShelfText.continueCaption(partway, episode: nil) == "40 min left", "before the episodes are known")
        let next = ContinueWatching.Item(title: series, progress: progress("e", at: 2990), isNextEpisode: true)
        #expect(ShelfText.continueCaption(next, episode: episode) == "Next episode")
        #expect(ShelfText.episodeCode(Episode(id: "x", episodeID: 1, number: 3, title: "Three")) == "E3")
        #expect(ShelfText.episodeCode(Episode(id: "x", episodeID: 1, season: 1, title: "Pilot")) == nil)
    }

    @Test("movies-and-series-browsing/continue-watching a series leaves once its episode list has nothing unwatched")
    func finished() {
        let episodes = ["s1": [Episode(id: "a", episodeID: 1, title: "A"), Episode(id: "b", episodeID: 2, title: "B")]]
        let halfway = [progress("a", series: "s1", at: 2990)]
        #expect(ContinueWatching.finishedSeries(progress: halfway, episodes: episodes).isEmpty)
        let done = halfway + [progress("b", series: "s1", at: 2995)]
        #expect(ContinueWatching.finishedSeries(progress: done, episodes: episodes) == ["s1"])
        #expect(ContinueWatching.finishedSeries(progress: done, episodes: [:]).isEmpty, "unknown lists never finish a series")
        #expect(ContinueWatching.episodeProgress(done, seriesID: "s1", sourceID: source).keys.sorted() == ["a", "b"])
    }
}
