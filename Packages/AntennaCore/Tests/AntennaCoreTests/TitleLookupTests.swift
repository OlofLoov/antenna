import AntennaCore
import Foundation
import Testing

/// Title names, scores, the kept-match rules and the Debug mock.
@Suite struct TitleLookupTests {
    let source = UUID()

    private func movie(_ name: String, id: String = "xtream#h#vod#1") -> ShelfTitle {
        ShelfTitle(id: id, kind: .movie, sourceID: source, name: name, category: "Thriller")
    }

    // MARK: Names

    struct NameCase: Sendable, CustomTestStringConvertible {
        var raw: String
        var name: String
        var year: Int?
        var testDescription: String { raw }
    }

    @Test(
        "title-metadata/a-title-is-matched-by-its-database-id-first: provider tags come off the name",
        arguments: [
            NameCase(raw: "EN | Dune: Part Two (2024) 4K", name: "Dune: Part Two", year: 2024),
            NameCase(raw: "[MULTI] Heat (1995)", name: "Heat", year: 1995),
            NameCase(raw: "4K-NF: The Long Harbor", name: "The Long Harbor"),
            NameCase(raw: "UK - Salt Road [2021] 1080p x265", name: "Salt Road", year: 2021),
            NameCase(raw: "The Long Harbor 2160p", name: "The Long Harbor"),
            NameCase(raw: "Dune: Part Two", name: "Dune: Part Two"),
            NameCase(raw: "WALL-E", name: "WALL-E"),
            NameCase(raw: "Amélie VOSTFR", name: "Amélie"),
            NameCase(raw: "1917 (2019)", name: "1917", year: 2019),
        ])
    func cleansNames(_ example: NameCase) {
        let cleaned = TitleName.clean(example.raw)
        #expect(cleaned.name == example.name)
        #expect(cleaned.year == example.year)
    }

    @Test("title-metadata/a-title-is-matched-by-its-database-id-first: a name of tags only stays as it was")
    func tagsOnly() {
        #expect(TitleName.clean("4K").name == "4K")
        #expect(TitleName.folded("  Amélie   Poulain ") == "amelie poulain")
    }

    @Test("title-metadata/only-what-is-needed-is-looked-up: the query holds the name and year only")
    func queryFromTitle() {
        let query = TitleLookupQuery(movie("EN | Dune: Part Two (2024) 4K"))
        #expect(query == TitleLookupQuery(kind: .movie, name: "Dune: Part Two", year: 2024))
        #expect(TitleLookupQuery(movie("Heat (1995)"), year: 1996).year == 1996, "the provider's year wins")
    }

    // MARK: Scores

    @Test("title-detail-and-episode-picker/scores-from-other-sites: each site's text and what VoiceOver reads")
    func scoreText() {
        #expect(Score(site: .tmdb, value: 7.4, scale: 10).text == "74%")
        #expect(Score(site: .tmdb, value: 7.4, scale: 10).spoken(Locale(identifier: "en_US")) == "TMDB user score 74 percent")
        #expect(Score(site: .imdb, value: 7.8, scale: 10).text == "7.8")
        #expect(Score(site: .rottenTomatoes, value: 92, scale: 100).text == "92%")
        #expect(Score(site: .metacritic, value: 81, scale: 100).text == "81")
        #expect(Score(site: .tmdb, value: 0, scale: 10).text == nil)
        #expect(Score(site: .tmdb, value: 11, scale: 10).text == nil)
        #expect(Score(site: .tmdb, value: .nan, scale: 10).text == nil)
    }

    @Test("title-detail-and-episode-picker/scores-from-other-sites: fixed order, a site with no score left out")
    func scoreOrder() {
        let scores = [
            Score(site: .tmdb, value: 7.4, scale: 10), Score(site: .metacritic, value: 0, scale: 100),
            Score(site: .imdb, value: 7.8, scale: 10), Score(site: .imdb, value: 6, scale: 10),
        ]
        #expect(Score.ordered(scores).map(\.site) == [.imdb, .tmdb])
        #expect(Score.ordered(scores).first?.text == "7.8")
    }

    // MARK: Merging

    @Test("title-metadata/details-the-provider-left-out-come-from-the-database: a plain playlist movie")
    func fillsMissing() {
        let match = TitleMatch(
            tmdbID: 1,
            details: TitleDetails(
                plot: "A film.", year: 2024, duration: 7_680, genre: "Drama", backdropURL: URL(string: "https://img.example/b.jpg"),
                cast: "A, B", director: "C"),
            scores: [Score(site: .tmdb, value: 7.4, scale: 10)])
        let meta = TitleMetadata(movie: movie("Salt Road"), info: VODInfo()).merging(match)
        #expect(meta.detailsLine == "2024 · 2 h 08 min · Drama")
        #expect(meta.description == "A film.")
        #expect(meta.cast == "A, B")
        #expect(meta.director == "C")
        #expect(meta.backdropURL == URL(string: "https://img.example/b.jpg"))
        #expect(meta.scores.map(\.text) == ["74%"])
        #expect(!meta.scoresAreSample)
    }

    @Test("title-metadata/details-the-provider-left-out-come-from-the-database: the provider's description wins")
    func providerWins() {
        let match = TitleMatch(tmdbID: 1, details: TitleDetails(plot: "Theirs.", year: 1999, cast: "From TMDB"))
        let meta = TitleMetadata(movie: movie("Heat"), info: VODInfo(plot: "Ours.", year: 1995)).merging(match)
        #expect(meta.description == "Ours.")
        #expect(meta.year == "1995")
        #expect(meta.cast == "From TMDB")
    }

    @Test("title-detail-and-episode-picker/what-the-title-is-about: scores replace the provider's rating")
    func scoresReplaceRating() {
        let base = TitleMetadata(movie: movie("Heat"), info: VODInfo(year: 1995, rating: 7.4))
        #expect(base.detailsLine == "1995 · ★ 7.4")
        let scored = base.merging(TitleMatch(tmdbID: 1, scores: [Score(site: .tmdb, value: 7.9, scale: 10)]))
        #expect(scored.detailsLine == "1995")
        let unscored = base.merging(TitleMatch(tmdbID: 1, scores: [Score(site: .tmdb, value: 0, scale: 10)]))
        #expect(unscored.detailsLine == "1995 · ★ 7.4", "with no usable score the rating stays")
        #expect(base.merging(nil) == base)
    }

    // MARK: Kept matches

    final class Counting: TitleLookup, @unchecked Sendable {
        private let lock = NSLock()
        private var answers: [Result<TitleMatch?, any Error>]
        private(set) var asked: [TitleLookupQuery] = []

        init(_ answers: [Result<TitleMatch?, any Error>]) { self.answers = answers }

        func match(_ query: TitleLookupQuery) async throws -> TitleMatch? {
            try lock.withLock {
                asked.append(query)
                return try (answers.isEmpty ? .success(nil) : answers.removeFirst()).get()
            }
        }

        var count: Int { lock.withLock { asked.count } }
    }

    final class Clock: @unchecked Sendable {
        private let lock = NSLock()
        private var date = Date(timeIntervalSince1970: 1_800_000_000)
        var now: Date { lock.withLock { date } }
        func advance(days: Double) { lock.withLock { date.addTimeInterval(days * 86_400) } }
    }

    struct Offline: Error {}

    private func directory() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "kept-\(UUID().uuidString)", directoryHint: .isDirectory)
    }

    private let dune = TitleMatch(tmdbID: 438_631, scores: [Score(site: .tmdb, value: 7.4, scale: 10)])
    private let query = TitleLookupQuery(kind: .movie, name: "Dune")

    @Test("title-metadata/matches-are-kept-on-the-device: a page opened again shows at once with no new lookup")
    func keptForSevenDays() async {
        let base = Counting([.success(dune), .success(dune)])
        let clock = Clock()
        let kept = KeptTitleLookup(base: base, directory: directory(), now: { clock.now })
        let key = KeptTitleLookup.Key(movie("Dune"))
        #expect(await kept.match(query, key: key) == dune)
        clock.advance(days: 1)
        #expect(await kept.match(query, key: key) == dune)
        #expect(base.count == 1)
        clock.advance(days: 7)
        #expect(await kept.match(query, key: key) == dune)
        #expect(base.count == 2, "asked again after seven days")
    }

    @Test("title-metadata/matches-are-kept-on-the-device: kept on disk, never past six months")
    func keptOnDisk() async {
        let folder = directory()
        let clock = Clock()
        let key = KeptTitleLookup.Key(movie("Dune"))
        let first = KeptTitleLookup(base: Counting([.success(dune)]), directory: folder, now: { clock.now })
        _ = await first.match(query, key: key)
        let file = folder.appending(path: "\(source.uuidString).json")
        #expect(FileManager.default.fileExists(atPath: file.path()))

        let relaunched = KeptTitleLookup(base: Counting([]), directory: folder, now: { clock.now })
        #expect(await relaunched.kept(key) == dune)
        clock.advance(days: 181)
        let later = KeptTitleLookup(base: Counting([]), directory: folder, now: { clock.now })
        #expect(await later.kept(key) == nil)
    }

    @Test("title-metadata/matches-are-kept-on-the-device: offline shows what was kept, and nothing for the rest")
    func offline() async {
        let clock = Clock()
        let base = Counting([.success(dune), .failure(Offline()), .failure(Offline())])
        let kept = KeptTitleLookup(base: base, directory: nil, now: { clock.now })
        let key = KeptTitleLookup.Key(movie("Dune"))
        _ = await kept.match(query, key: key)
        clock.advance(days: 8)
        #expect(await kept.match(query, key: key) == dune)
        #expect(await kept.match(TitleLookupQuery(kind: .movie, name: "Heat"), key: .init(movie("Heat", id: "2"))) == nil)
    }

    @Test("title-metadata/a-slow-or-failing-lookup-never-holds-up-the-page: a failed lookup is tried again next time")
    func retriesAfterFailure() async {
        let base = Counting([.failure(Offline()), .success(dune)])
        let kept = KeptTitleLookup(base: base, directory: nil)
        let key = KeptTitleLookup.Key(movie("Dune"))
        #expect(await kept.match(query, key: key) == nil)
        #expect(await kept.match(query, key: key) == dune)
    }

    @Test("title-metadata/lookups-can-be-turned-off: nothing is sent and kept matches are deleted")
    func turnedOff() async {
        let folder = directory()
        let base = Counting([.success(dune), .success(dune)])
        let kept = KeptTitleLookup(base: base, directory: folder)
        let key = KeptTitleLookup.Key(movie("Dune"))
        _ = await kept.match(query, key: key)
        await kept.setEnabled(false)
        #expect(!FileManager.default.fileExists(atPath: folder.path()))
        #expect(await kept.match(query, key: key) == nil)
        #expect(await kept.kept(key) == nil)
        #expect(base.count == 1)
        await kept.setEnabled(true)
        #expect(await kept.match(query, key: key) == dune)
        #expect(base.count == 2, "turned back on, the title is looked up again")
    }

    @Test("title-metadata/matches-are-kept-on-the-device: deleting a source removes its matches")
    func sourceDeleted() async {
        let folder = directory()
        let other = UUID()
        let kept = KeptTitleLookup(base: Counting([.success(dune), .success(dune)]), directory: folder)
        let mine = KeptTitleLookup.Key(movie("Dune"))
        let theirs = KeptTitleLookup.Key(sourceID: other, titleID: "x")
        _ = await kept.match(query, key: mine)
        _ = await kept.match(query, key: theirs)
        await kept.keepSources([other])
        #expect(await kept.kept(mine) == nil)
        #expect(await kept.kept(theirs) == dune)
        #expect(!FileManager.default.fileExists(atPath: folder.appending(path: "\(source.uuidString).json").path()))
    }

    @Test("sources-and-settings/a-switch-for-movie-database-lookups: on by default")
    func switchDefault() {
        #expect(AppPreferences().lookupsEnabled)
        #expect(!AppPreferences(lookupsEnabled: false).lookupsEnabled)
    }

    // MARK: Mock

    @Test("title-detail-and-episode-picker/scores-from-other-sites: the mock gives stable sample scores")
    func mockIsStable() async throws {
        let mock = MockTitleLookup()
        let first = try await mock.match(TitleLookupQuery(movie("EN | The Long Harbor (2024) 4K")))
        let again = try await mock.match(TitleLookupQuery(kind: .movie, name: "the long harbor", year: 2024))
        #expect(first?.scores == again?.scores && first?.tmdbID == again?.tmdbID, "the folded, cleaned name decides the answer")
        #expect(first?.isSample == true)
        #expect(first?.scores.map(\.site) == [.tmdb])
        #expect(MockTitleLookup.stableHash("a") == 0xaf63_dc4c_8601_ec8c, "FNV-1a, the same on every launch")
        let text = try #require(first?.scores.first?.text)
        #expect(text.hasSuffix("%"))
        let percent = try #require(Int(text.dropLast()))
        #expect((50...90).contains(percent))
        #expect(first?.details.backdropURL == nil, "the mock sends nothing to the network")
        let all = try await MockTitleLookup(sites: Score.Site.allCases).match(query)
        #expect(Score.ordered(all?.scores ?? []).count == 4)
    }
}
