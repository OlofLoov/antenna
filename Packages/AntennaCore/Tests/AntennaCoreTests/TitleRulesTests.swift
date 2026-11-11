import AntennaCore
import Foundation
import Testing

/// The title page's details line, season groups and play target.
@Suite struct TitleRulesTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let source = UUID()

    private func movie(name: String = "The Long Harbor 2160p", category: String? = "Thriller", rating: Double? = nil) -> ShelfTitle {
        ShelfTitle(id: "xtream#h#vod#1", kind: .movie, sourceID: source, name: name, category: category, rating: rating)
    }

    private func series(category: String? = "Drama") -> ShelfTitle {
        ShelfTitle(id: "xtream#h#series#7", kind: .series, sourceID: source, name: "Northern Lights", category: category)
    }

    private func episode(_ id: Int, season: Int?, number: Int?) -> Episode {
        Episode(id: "e\(id)", episodeID: id, season: season, number: number, title: "Episode \(number ?? 0)", duration: 2_640)
    }

    private func progress(_ id: String, at share: Double, saved offset: TimeInterval, length: Double? = 100) -> WatchProgress {
        WatchProgress(
            id: id, titleID: id, seriesID: "xtream#h#series#7", sourceID: source, position: share * 100, duration: length,
            updatedAt: now.addingTimeInterval(offset))
    }

    // MARK: Details line

    @Test("title-detail-and-episode-picker/what-the-title-is-about a movie with full details")
    func fullMovie() {
        let info = VODInfo(
            plot: " A harbour pilot. ", year: 2024, duration: 7_680, genre: "Thriller", ageRating: "15",
            backdropURLs: [URL(string: "http://h/b.jpg")!], cast: "Mira Holt", director: "Sanna Weiss", rating: 7.4,
            trailerURL: URL(string: "https://t.example/x"))
        let meta = TitleMetadata(movie: movie(), info: info)
        #expect(meta.eyebrow == "Movie · Thriller")
        #expect(meta.name == "The Long Harbor 2160p")
        #expect(meta.detailsLine == "2024 · 2 h 08 min · Thriller · ★ 7.4")
        #expect(meta.badges == ["4K", "15"])
        #expect(meta.description == "A harbour pilot.")
        #expect(meta.cast == "Mira Holt")
        #expect(meta.director == "Sanna Weiss")
        #expect(meta.backdropURL == URL(string: "http://h/b.jpg"))
        #expect(meta.trailerURL == URL(string: "https://t.example/x"))
    }

    @Test("title-detail-and-episode-picker/what-the-title-is-about missing fields are left out, never Unknown")
    func missingFields() {
        let meta = TitleMetadata(movie: movie(name: "Salt Road", category: nil), info: VODInfo(duration: 5_520, genre: " ", cast: ""))
        #expect(meta.eyebrow == "Movie")
        #expect(meta.detailsLine == "1 h 32 min")
        #expect(meta.badges.isEmpty)
        #expect(meta.description == nil && meta.cast == nil && meta.director == nil && meta.backdropURL == nil)
        #expect(TitleMetadata(movie: movie(), info: VODInfo()).detailsLine == nil)
        #expect(TitleMetadata(title: series(category: "  ")).eyebrow == "Series")
    }

    @Test("title-detail-and-episode-picker/what-the-title-is-about the rating falls back to the list row, one decimal")
    func ratingFallback() {
        #expect(TitleMetadata(movie: movie(rating: 6.25), info: VODInfo()).facts == ["★ 6.3"])
        #expect(TitleMetadata(movie: movie(rating: 6), info: VODInfo(rating: 8)).facts == ["★ 8.0"])
        #expect(TitleMetadata.rating(0) == nil)
        #expect(TitleMetadata.rating(.nan) == nil)
    }

    @Test("title-detail-and-episode-picker/what-the-title-is-about a series counts seasons from its episodes")
    func seriesSeasons() {
        let episodes = [episode(1, season: 1, number: 1), episode(2, season: 3, number: 1), episode(3, season: 0, number: 1)]
        let info = SeriesInfo(year: 2019, genre: "Drama", ageRating: "15", rating: 8.1, episodes: episodes)
        let meta = TitleMetadata(series: series(), info: info, groups: SeasonGroup.group(episodes))
        #expect(meta.eyebrow == "Series · Drama")
        #expect(meta.detailsLine == "2019 · 2 seasons · Drama · ★ 8.1")
        #expect(meta.badges == ["15"], "a series shows no 4K badge")
    }

    // MARK: Season groups

    @Test("title-detail-and-episode-picker/pick-a-season seasons in order, then Specials and Other")
    func grouping() {
        let episodes = [
            episode(1, season: nil, number: 1), episode(2, season: 0, number: 1), episode(3, season: 1, number: 1),
            episode(4, season: 1, number: 2), episode(5, season: 3, number: 1), episode(6, season: 2, number: 1),
            episode(7, season: -1, number: 1),
        ]
        let groups = SeasonGroup.group(episodes)
        #expect(groups.map(\.title) == ["Season 1", "Season 2", "Season 3", "Specials", "Other"])
        #expect(groups.map(\.id) == ["season-1", "season-2", "season-3", "specials", "other"])
        #expect(groups[0].episodes.map(\.id) == ["e3", "e4"])
        #expect(groups[4].episodes.map(\.id) == ["e1", "e7"])
        #expect(groups[0].countLabel == "2 episodes")
        #expect(groups[1].countLabel == "1 episode")
        #expect(SeasonGroup.seasonCount(groups) == 3)
    }

    @Test("title-detail-and-episode-picker/pick-a-season one group gives no picker")
    func oneGroup() {
        #expect(SeasonGroup.group([episode(1, season: nil, number: 1), episode(2, season: nil, number: 2)]).count == 1)
        #expect(SeasonGroup.group([]).isEmpty)
    }

    // MARK: Play target

    private var twoSeasons: [Episode] {
        [
            episode(10, season: 0, number: 1), episode(11, season: 1, number: 1), episode(12, season: 1, number: 2),
            episode(21, season: 2, number: 1), episode(22, season: 2, number: 2),
        ]
    }

    private func target(_ records: [WatchProgress]) -> SeriesPlayTarget? {
        SeriesPlayTarget.resolve(episodes: twoSeasons, progress: Dictionary(uniqueKeysWithValues: records.map { ($0.titleID, $0) }))
    }

    @Test("title-detail-and-episode-picker/play-starts-the-right-episode resumes the episode last in progress")
    func inProgress() throws {
        let pick = try #require(
            target([progress("e11", at: 0.5, saved: 0), progress("e21", at: 0.3, saved: 10), progress("e22", at: 0.99, saved: 20)]))
        #expect(pick.episode.id == "e21")
        #expect(pick.resumes)
        #expect(pick.position == 30)
        #expect(pick.label == "Resume S2 E1")
    }

    @Test("title-detail-and-episode-picker/play-starts-the-right-episode a tie goes to the earlier episode")
    func tie() throws {
        #expect(try #require(target([progress("e21", at: 0.5, saved: 0), progress("e12", at: 0.5, saved: 0)])).episode.id == "e12")
    }

    @Test("title-detail-and-episode-picker/play-starts-the-right-episode after the last finished, skipping watched ones")
    func afterFinished() throws {
        let pick = try #require(
            target([progress("e11", at: 0.97, saved: 5), progress("e12", at: 0.99, saved: 0), progress("e21", at: 0.01, saved: 9)]))
        #expect(pick.episode.id == "e21", "e12 is finished, e21 barely started counts as unwatched")
        #expect(!pick.resumes)
        #expect(pick.position == 0)
        #expect(pick.label == "Play S2 E1")
    }

    @Test("title-detail-and-episode-picker/play-starts-the-right-episode wraps to the start after the last episode")
    func wraps() throws {
        #expect(try #require(target([progress("e10", at: 0.96, saved: 9)])).episode.id == "e11", "Specials come after the seasons")
        let pick = try #require(
            target([progress("e22", at: 0.96, saved: 9), progress("e10", at: 0.96, saved: 2), progress("e11", at: 0.96, saved: 1)]))
        #expect(pick.episode.id == "e12")
    }

    @Test("title-detail-and-episode-picker/play-starts-the-right-episode nothing started plays Season 1 Episode 1")
    func nothingStarted() throws {
        let pick = try #require(target([progress("e12", at: 0.01, saved: 0), progress("e21", at: 0.5, saved: 0, length: nil)]))
        #expect(pick.episode.id == "e11", "not a special, and a record with no length counts as 0%")
        #expect(pick.label == "Play S1 E1")
    }

    @Test("title-detail-and-episode-picker/play-starts-the-right-episode everything watched plays the first episode")
    func allWatched() throws {
        let pick = try #require(target(twoSeasons.map { progress($0.id, at: 0.99, saved: 0) }))
        #expect(pick.episode.id == "e11")
        #expect(!pick.resumes)
    }

    @Test("title-detail-and-episode-picker/play-starts-the-right-episode no episodes, no target")
    func noEpisodes() {
        #expect(SeriesPlayTarget.resolve(episodes: [], progress: [:]) == nil)
    }

    @Test("title-detail-and-episode-picker/play-starts-the-right-episode labels name the episode as far as it is numbered")
    func labels() {
        #expect(PlayLabel.text(resumes: false) == "Play")
        #expect(PlayLabel.text(resumes: true) == "Resume")
        #expect(PlayLabel.text(resumes: false, episode: episode(1, season: 2, number: 3)) == "Play S2 E3")
        #expect(PlayLabel.text(resumes: true, episode: episode(1, season: nil, number: 3)) == "Resume E3")
        #expect(PlayLabel.text(resumes: false, episode: episode(1, season: 2, number: nil)) == "Play S2")
        #expect(PlayLabel.text(resumes: false, episode: episode(1, season: nil, number: nil)) == "Play")
    }

    // MARK: Episode rows

    @Test("title-detail-and-episode-picker/what-each-episode-shows watched, in progress, barely started and unwatched")
    func episodeStates() {
        let row = episode(4, season: 2, number: 4)
        #expect(EpisodeText.status(row, progress: progress("e4", at: 0.99, saved: 0)) == "Watched")
        #expect(EpisodeText.fraction(progress("e4", at: 0.99, saved: 0)) == 1)
        let partway = WatchProgress(
            id: "e4", titleID: "e4", sourceID: source, position: 1_380, duration: 2_640, updatedAt: now)
        #expect(EpisodeText.status(row, progress: partway) == "44 min · 21 min left")
        #expect(EpisodeText.fraction(partway).map { abs($0 - 1_380.0 / 2_640) < 0.001 } == true)
        #expect(EpisodeText.status(row, progress: progress("e4", at: 0.01, saved: 0)) == "44 min")
        #expect(EpisodeText.fraction(progress("e4", at: 0.01, saved: 0)) == nil)
        #expect(EpisodeText.status(row, progress: nil) == "44 min")
        #expect(EpisodeText.status(Episode(id: "x", episodeID: 1, title: "Episode"), progress: nil) == nil)
    }

    @Test("title-detail-and-episode-picker/what-each-episode-shows VoiceOver reads number, title, length, state and up next")
    func episodeLabel() {
        let row = Episode(id: "e4", episodeID: 4, season: 2, number: 4, title: "Low Water", duration: 2_640)
        let partway = WatchProgress(id: "e4", titleID: "e4", sourceID: source, position: 1_380, duration: 2_640, updatedAt: now)
        #expect(
            EpisodeText.accessibilityLabel(row, progress: partway, upNext: true) == "Episode 4, Low Water, 44 min, 21 min left, up next")
        #expect(EpisodeText.accessibilityLabel(episode(6, season: 2, number: 6), progress: nil, upNext: false) == "Episode 6, 44 min")
    }

    @Test("title-detail-and-episode-picker/what-each-episode-shows unreadable episodes are counted")
    func skipped() {
        #expect(EpisodeText.skipped(0) == nil)
        #expect(EpisodeText.skipped(1) == "1 episode could not be read from the provider's list.")
        #expect(EpisodeText.skipped(3) == "3 episodes could not be read from the provider's list.")
    }
}
