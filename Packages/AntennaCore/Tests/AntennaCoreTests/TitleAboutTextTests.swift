import Foundation
import Testing

@testable import AntennaCore

@Suite struct TitleAboutTextTests {
    static let movie = ShelfTitle(
        id: "xtream#h#vod#1", kind: .movie, sourceID: UUID(), name: "The Long Harbor", category: "Thriller")

    @Test("title-detail-and-episode-picker/what-the-title-is-about More shows the whole description, then the cast and director in full")
    func fullTitle() {
        let plot = String(repeating: "One tide to decide who gets out. ", count: 40)
        let cast = (1...12).map { "Actor \($0)" }.joined(separator: ", ")
        let metadata = TitleMetadata(
            movie: Self.movie,
            info: VODInfo(plot: plot, year: 2024, duration: 7_680, genre: "Thriller", cast: cast, director: "Sanna Weiss"), locale: .english
        )
        let about = TitleAboutText(metadata, locale: .english)
        #expect(about.heading == "The Long Harbor")
        #expect(about.details == metadata.detailsLine(.english))
        #expect(
            about.paragraphs == [
                .init(text: plot.trimmingCharacters(in: .whitespaces)), .init(label: "Cast", text: cast),
                .init(label: "Director", text: "Sanna Weiss"),
            ])
    }

    @Test("title-detail-and-episode-picker/what-the-title-is-about missing fields are left out of the full text")
    func sparseTitle() {
        let about = TitleAboutText(TitleMetadata(movie: Self.movie, info: VODInfo(duration: 5_520), locale: .english), locale: .english)
        #expect(about.paragraphs.isEmpty)
        #expect(about.heading == "The Long Harbor")
    }

    @Test("title-detail-and-episode-picker/what-each-episode-shows Description shows the number, title, length and whole description")
    func episode() {
        let plot = "The ferry runs aground off the north point. " + String(repeating: "They wait for the tide. ", count: 20)
        let episode = Episode(id: "e4", episodeID: 4, season: 1, number: 4, title: "Low Water", duration: 2_640, plot: plot)
        let about = TitleAboutText(episode, locale: .english)
        #expect(about.heading == "4. Low Water")
        #expect(about.details == "Season 1 · Episode 4 · 44 min")
        #expect(about.paragraphs == [.init(text: plot.trimmingCharacters(in: .whitespaces))])
    }

    @Test("title-detail-and-episode-picker/what-each-episode-shows an episode named by its number is not named twice")
    func numberedEpisode() {
        let about = TitleAboutText(Episode(id: "e2", episodeID: 2, number: 2, title: "Episode 2", plot: "Snow."), locale: .english)
        #expect(about.heading == "Episode 2")
        #expect(about.details == "Episode 2")
    }
}
