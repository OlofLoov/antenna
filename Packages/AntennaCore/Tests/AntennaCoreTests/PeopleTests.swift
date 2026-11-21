import Foundation
import Testing

@testable import AntennaCore

@Suite struct PeopleTests {
    let english = Locale(identifier: "en_US")
    let cabin = UUID(uuidString: "00000000-0000-0000-0000-0000000000C1") ?? UUID()
    let office = UUID(uuidString: "00000000-0000-0000-0000-0000000000C2") ?? UUID()

    func movie(_ id: Int, _ name: String, source: UUID? = nil, cast: String? = nil, director: String? = nil) -> ShelfTitle {
        ShelfTitle(
            id: "xtream#h#vod#\(id)", kind: .movie, sourceID: source ?? cabin, name: name, cast: cast, director: director)
    }

    func series(_ id: Int, _ name: String, cast: String? = nil, director: String? = nil) -> ShelfTitle {
        ShelfTitle(id: "xtream#h#series#\(id)", kind: .series, sourceID: cabin, name: name, cast: cast, director: director)
    }

    // MARK: Names

    @Test("xtream-vod-client/names-on-list-rows a series row with a cast, a movie row without names")
    func listRows() throws {
        let seriesBody = Data(
            #"[{"series_id": 7, "name": "Dark", "cast": "Mira Holt, Jonas Reeve", "director": "Sanna Weiss"}, {"series_id": 8, "name": "1899", "actors": "Zoë Brandt"}]"#
                .utf8)
        let series = try XtreamClient.decodeSeriesList(seriesBody, host: "h").items
        #expect(series[0].cast == "Mira Holt, Jonas Reeve")
        #expect(series[0].director == "Sanna Weiss")
        #expect(series[1].cast == "Zoë Brandt")
        let movies = try XtreamClient.decodeVODList(Data(#"[{"stream_id": 55, "name": "Dune"}]"#.utf8), host: "h").items
        #expect(movies.count == 1)
        #expect(movies[0].cast == nil)
        #expect(movies[0].director == nil)
        let title = ShelfTitle(series: series[0], sourceID: cabin, categories: [:])
        #expect(title.cast == "Mira Holt, Jonas Reeve")
        #expect(title.director == "Sanna Weiss")
    }

    @Test("browse-by-person/the-same-person-across-titles case, accents, dots and spaces are ignored")
    func keys() {
        #expect(PersonName.key("Zoë Brandt") == PersonName.key("ZOE  BRANDT"))
        #expect(PersonName.key("J.J. Abrams") == PersonName.key("JJ Abrams"))
        #expect(PersonName.key("Jean-Luc Picard") == "jean luc picard")
        #expect(PersonName.key("Mira Holt") != PersonName.key("Mira Holte"))
    }

    @Test("browse-by-person/the-same-person-across-titles other separators split the field")
    func separators() {
        let names = PersonName.split("Mira Holt / Jonas Reeve | Adaeze Okafor; Teodor Lind\nIris Moen · Lena Varga")
        #expect(names.map(\.display) == ["Mira Holt", "Jonas Reeve", "Adaeze Okafor", "Teodor Lind", "Iris Moen", "Lena Varga"])
    }

    @Test("browse-by-person/the-same-person-across-titles a part in brackets is dropped, and Last, First is not reordered")
    func brackets() {
        #expect(PersonName.split("Jonas Reeve (voice), Mira Holt").map(\.display) == ["Jonas Reeve", "Mira Holt"])
        #expect(PersonName.split("Holt, Mira").map(\.display) == ["Holt", "Mira"])
        #expect(PersonName.split("Mira Holt, MIRA HOLT").count == 1)
    }

    @Test("browse-by-person/pick-someone-in-the-cast placeholders and junk show no name")
    func junk() {
        #expect(PersonName.split("N/A").isEmpty)
        #expect(PersonName.split("n/a, Unknown, -, 0, ?, none").isEmpty)
        #expect(PersonName.split("Mira Holt, N/A").map(\.display) == ["Mira Holt"])
        #expect(PersonName.split(String(repeating: "word ", count: 20)).isEmpty)
        #expect(PersonName.split("   ").isEmpty)
        #expect(PersonName.split(nil).isEmpty)
        #expect(TitleCredits(cast: "N/A", director: "").isEmpty)
    }

    @Test("browse-by-person/pick-someone-in-the-cast at most 15 names, the cast first and the directors last")
    func chips() {
        let thirty = (1...30).map { "Actor \($0)" }.joined(separator: ", ")
        let long = TitleCredits(cast: thirty, director: "Sanna Weiss").chips
        #expect(long.count == 15)
        #expect(long.prefix(14).allSatisfy { $0.role == .cast })
        #expect(long.last == CastChip(name: PersonName("Sanna Weiss")!, role: .director))
        let short = TitleCredits(cast: "Mira Holt, Jonas Reeve", director: "Sanna Weiss, Ole Dahl").chips
        #expect(short.map(\.name.display) == ["Mira Holt", "Jonas Reeve", "Sanna Weiss", "Ole Dahl"])
        #expect(TitleCredits(cast: thirty, director: nil).chips.count == 15)
    }

    @Test("browse-by-person/pick-someone-in-the-cast a title page shows the row's names until its info call answers")
    func pageNames() {
        let title = movie(1, "Salt Road", cast: "Mira Holt", director: "Sanna Weiss")
        #expect(TitleMetadata(title: title, locale: .english).cast == "Mira Holt")
        let answered = TitleMetadata(movie: title, info: VODInfo(cast: "Jonas Reeve"), locale: .english)
        #expect(answered.cast == "Jonas Reeve")
        #expect(answered.director == "Sanna Weiss")
    }

    // MARK: Index and page

    @Test("browse-by-person/a-person-s-page rows of movies, series and directed titles, newest first")
    func page() throws {
        var learned = LearnedCredits()
        let older = movie(1, "The Long Harbor (2019)", cast: "Mira Holt")
        let newer = movie(2, "Salt Road", cast: "MIRA HOLT, Jonas Reeve")
        learned.record(newer, credits: TitleCredits(cast: "Mira Holt, Jonas Reeve", director: nil), year: 2024, now: .now)
        let show = series(3, "Pier Stories", cast: "Zoë Brandt, Mira Holt")
        let directed = movie(4, "Night Ferry", director: "Mira Holt")
        let index = PeopleIndex(titles: [older, newer, show, directed], learned: learned)
        let page = index.page(try #require(PersonName("mira holt")))
        #expect(page.name == "Mira Holt")
        #expect(page.movies.map(\.name) == ["Salt Road", "The Long Harbor (2019)"])
        #expect(page.series.map(\.name) == ["Pier Stories"])
        #expect(page.directed.map(\.name) == ["Night Ferry"])
        #expect(page.count == 4)
        #expect(page.countLine(locale: english) == "Acting · 4 in your sources")
        #expect(page.initials == "MH")
        #expect(!page.showsNote)
    }

    @Test("browse-by-person/a-person-s-page only the title they came from shows the note")
    func onlyOne() throws {
        let one = movie(1, "Salt Road", cast: "Mira Holt")
        let unnamed = movie(2, "Arrival")
        let index = PeopleIndex(titles: [one, unnamed], learned: LearnedCredits())
        let page = index.page(try #require(PersonName("Mira Holt")))
        #expect(page.countLine(locale: english) == "Acting · 1 in your sources")
        #expect(page.showsNote)
        #expect(PersonPage.note(locale: english).hasPrefix("Only titles whose cast"))
    }

    @Test("browse-by-person/a-person-s-page a director's page says Directing")
    func directing() throws {
        let index = PeopleIndex(
            titles: [movie(1, "A", director: "Sanna Weiss"), movie(2, "B", director: "Sanna Weiss"), movie(3, "C", cast: "Sanna Weiss")],
            learned: LearnedCredits())
        let page = index.page(try #require(PersonName("Sanna Weiss")))
        #expect(page.department == .directing)
        #expect(page.countLine(locale: english) == "Directing · 3 in your sources")
        #expect(PersonPage(name: "Zendaya", credits: [], showsNote: false).initials == "Z")
    }

    @Test("browse-by-person/only-titles-your-sources-have a removed source's titles leave the page")
    func onlyLoaded() throws {
        let cabinMovie = movie(1, "Salt Road", source: cabin, cast: "Mira Holt")
        let officeMovie = movie(1, "Salt Road", source: office, cast: "Mira Holt")
        let both = PeopleIndex(titles: [cabinMovie, officeMovie], learned: LearnedCredits())
        let name = try #require(PersonName("Mira Holt"))
        #expect(both.page(name).movies.count == 2)
        let one = PeopleIndex(titles: [cabinMovie], learned: LearnedCredits())
        #expect(one.page(name).movies.map(\.sourceID) == [cabin])
    }

    @Test("browse-by-person/only-titles-your-sources-have nothing left says so")
    func nothing() throws {
        let page = PeopleIndex.empty.page(try #require(PersonName("Mira Holt")))
        #expect(page.isEmpty)
        #expect(page.emptyLine(locale: english) == "Nothing with Mira Holt in your sources.")
        let arabic = page.emptyLine(locale: Locale(identifier: "ar"))
        #expect(arabic.contains("\u{2068}Mira Holt\u{2069}"))
    }

    @Test("browse-by-person/a-person-s-page-never-asks-the-provider names from the list and from details answers")
    func sources() throws {
        let listed = series(1, "Dark", cast: "Mira Holt")
        let opened = movie(2, "Salt Road")
        let unopened = movie(3, "Arrival")
        var learned = LearnedCredits()
        learned.record(opened, credits: TitleCredits(cast: "Mira Holt", director: nil), year: nil, now: .now)
        let index = PeopleIndex(titles: [listed, opened, unopened], learned: learned)
        let page = index.page(try #require(PersonName("Mira Holt")))
        #expect(page.series.map(\.name) == ["Dark"])
        #expect(page.movies.map(\.name) == ["Salt Road"])
        #expect(page.showsNote)
        let allNamed = PeopleIndex(titles: [listed], learned: LearnedCredits())
        #expect(!allNamed.page(try #require(PersonName("Mira Holt"))).showsNote)
    }

    @Test("browse-by-person/a-person-s-page-never-asks-the-provider 40,000 titles index without a request")
    func large() throws {
        let index = PeopleIndex(titles: largeCatalogue(), learned: LearnedCredits())
        #expect(index.page(try #require(PersonName("Mira Holt"))).count == 40_000)
    }

    /// Timed, so it runs with the benchmarks under `ANTENNA_BENCHMARKS=1 swift test`.
    @Test(
        "browse-by-person/a-person-s-page-never-asks-the-provider 40,000 titles index within 5 s",
        .enabled(if: ProcessInfo.processInfo.environment["ANTENNA_BENCHMARKS"] == "1"))
    func largeIsQuick() {
        let titles = largeCatalogue()
        let clock = ContinuousClock()
        let started = clock.now
        _ = PeopleIndex(titles: titles, learned: LearnedCredits())
        #expect(clock.now - started < .seconds(5))
    }

    @Test("browse-by-person/a-person-s-page-never-asks-the-provider an answer's cast replaces the row's, and its directors the row's")
    func answersOnTop() throws {
        let both = movie(1, "Salt Road", cast: "Mira Holt", director: "Sanna Weiss")
        let castOnly = movie(2, "Night Ferry", cast: "Mira Holt", director: "Sanna Weiss")
        var learned = LearnedCredits()
        learned.record(both, credits: TitleCredits(cast: "Jonas Reeve", director: "Ole Dahl"), year: 2024, now: .now)
        learned.record(castOnly, credits: TitleCredits(cast: "jonas reeve, Mira Holt", director: nil), year: nil, now: .now)
        let rows = PeopleIndex.Rows(libraries: [ShelfIndex(lookingUp: [both, castOnly])], isCancelled: { false })
        let index = PeopleIndex(rows: try #require(rows), learned: learned)
        func page(_ name: String) throws -> PersonPage { index.page(try #require(PersonName(name))) }
        #expect(try page("Mira Holt").movies.map(\.name) == ["Night Ferry"])
        #expect(try page("Sanna Weiss").directed.map(\.name) == ["Night Ferry"], "an answer with no directors keeps the row's")
        #expect(try page("Ole Dahl").directed.map(\.name) == ["Salt Road"])
        #expect(try page("Jonas Reeve").movies.map(\.name) == ["Salt Road", "Night Ferry"], "the answer's year puts it first")
        #expect(try page("Jonas Reeve").name == "Jonas Reeve", "the spelling of the first title in source order")
        #expect(index.search(SearchQuery("jonas")).first?.titleCount == 2)
        #expect(index.search(SearchQuery("sanna")).first?.titleCount == 1)
    }

    @Test("movies-and-series-browsing/browsing-stays-responsive a cancelled build of the row names stops and returns nothing")
    func cancelledRows() {
        var asked = 0
        let titles = (0..<2_000).map { movie($0, "Movie \($0)", cast: "Mira Holt") }
        let rows = PeopleIndex.Rows(
            libraries: [ShelfIndex(lookingUp: titles)],
            isCancelled: {
                asked += 1
                return asked > 1
            })
        #expect(rows == nil)
        #expect(asked == 2, "it stops at the second check, 1 024 titles in")
    }

    /// 100 000 movies and 30 000 series, each row naming five of 15 000
    /// people and a director: the review's worst case. Timed, so it runs
    /// with the benchmarks under `ANTENNA_BENCHMARKS=1 swift test`.
    @Test(
        "movies-and-series-browsing/browsing-stays-responsive the row names of 130 000 titles with cast build in 8 s, an answer goes on top in 500 ms",
        .enabled(if: Benchmarks.enabled))
    func castHeavyLibrary() throws {
        let people = (0..<15_000).map { "Given\($0 % 3_000) Family\($0 / 3_000)" }
        func names(_ seed: Int) -> String { (0..<5).map { people[(seed * 13 + $0 * 4_391) % people.count] }.joined(separator: ", ") }
        let movies = (0..<100_000).map { movie($0, "Movie \($0)", cast: names($0), director: people[$0 * 3 % people.count]) }
        let shows = (0..<30_000).map { series($0, "Series \($0)", cast: names($0 + 200_000), director: people[$0 * 5 % people.count]) }
        var rows: PeopleIndex.Rows?
        let rowTime = FastestRun.of(1) {
            rows = PeopleIndex.Rows(libraries: [ShelfIndex(lookingUp: movies), ShelfIndex(lookingUp: shows)], isCancelled: { false })
        }
        var learned = LearnedCredits()
        for seed in 0..<20_000 {
            learned.record(movies[seed * 5], credits: TitleCredits(cast: names(seed + 500_000), director: nil), year: 2000, now: .now)
        }
        let built = try #require(rows)
        var index = PeopleIndex.empty
        let answerTime = FastestRun.of { index = PeopleIndex(rows: built, learned: learned) }
        #expect(index.person(PersonName.key(people[0])) != nil)
        #expect(!index.hasUnknownTitles)
        #expect(answerTime < .milliseconds(500), "the answers took \(answerTime)")
        #expect(rowTime < .seconds(8), "the rows took \(rowTime)")
    }

    private func largeCatalogue() -> [ShelfTitle] {
        (0..<40_000).map { movie($0, "Movie \($0)", cast: "Actor \($0 % 500), Mira Holt", director: "Director \($0 % 90)") }
    }

    // MARK: Kept names

    @Test("browse-by-person/names-the-provider-sent-are-kept names survive a restart for 30 days")
    func kept() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        var learned = LearnedCredits()
        let yesterday = movie(1, "Salt Road")
        learned.record(yesterday, credits: TitleCredits(cast: "Mira Holt", director: nil), year: 2024, now: now.addingTimeInterval(-86_400))
        let old = now.addingTimeInterval(-31 * 86_400)
        learned.record(movie(2, "Old"), credits: TitleCredits(cast: "Jonas Reeve", director: nil), year: nil, now: old)
        let restored = LearnedCredits.decode(learned.encoded(now: now.addingTimeInterval(-1)), now: now)
        #expect(restored.count == 1)
        let entry = try #require(restored.entry(yesterday.activityKey))
        #expect(entry.credits.cast.map(\.display) == ["Mira Holt"])
        #expect(entry.year == 2024)
        #expect(LearnedCredits.decode(Data("not json".utf8), now: now).isEmpty)
    }

    @Test("browse-by-person/names-the-provider-sent-are-kept a deleted source's names are dropped, and the oldest go past the limit")
    func pruning() {
        var learned = LearnedCredits()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        learned.record(movie(1, "A", source: cabin), credits: TitleCredits(), year: nil, now: now)
        learned.record(movie(2, "B", source: office), credits: TitleCredits(), year: nil, now: now)
        let dropped = learned.keep(sources: [cabin])
        let again = learned.keep(sources: [cabin])
        #expect(dropped)
        #expect(learned.count == 1)
        #expect(!again)
        var full = LearnedCredits()
        for index in 0...LearnedCredits.limit {
            full.record(movie(index, "M"), credits: TitleCredits(), year: nil, now: now.addingTimeInterval(Double(index)))
        }
        #expect(full.count == LearnedCredits.limit)
        var kept = LearnedCredits()
        kept.record(movie(1, "A", source: cabin), credits: TitleCredits(cast: "Old Name", director: nil), year: nil, now: now)
        kept.merge(learned)
        #expect(kept.entry(movie(1, "A", source: cabin).activityKey)?.credits.isEmpty == true)
        #expect(full.entry(movie(0, "M").activityKey) == nil)
        #expect(full.entry(movie(1, "M").activityKey) != nil)
    }

    // MARK: Search

    @Test("browse-by-person/find-a-person-in-search every typed word starts a word of the name, most titles first")
    func search() {
        let titles = [
            movie(1, "A", cast: "Mira Holt, Miriam Holm"), movie(2, "B", cast: "Mira Holt"), movie(3, "C", cast: "Amira Holt"),
            movie(4, "D", cast: "Mirko Hale"), movie(5, "E", cast: "Mikkel Holt"),
        ]
        let index = PeopleIndex(titles: titles, learned: LearnedCredits())
        #expect(index.search(SearchQuery("mira h")).map(\.name) == ["Mira Holt"])
        #expect(index.search(SearchQuery("mir")).map(\.name) == ["Mira Holt", "Miriam Holm", "Mirko Hale"])
        #expect(index.search(SearchQuery("holt")).first?.name == "Mira Holt")
        #expect(index.search(SearchQuery("zz")).isEmpty)
        #expect(index.search(SearchQuery("m")).isEmpty)
        #expect(index.search(SearchQuery("MÍRA")).first?.page.countLine(locale: english) == "Acting · 2 in your sources")
    }
}
