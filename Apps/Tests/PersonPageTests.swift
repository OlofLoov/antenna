import AntennaCore
import Foundation
import Testing

@testable import Antenna

/// The library's page stack and people index: names from list rows and
/// from info answers, the person's page over a title page, and Back.
@MainActor
@Suite struct PersonPageTests {
    let source = UUID(uuidString: "00000000-0000-0000-0000-00000000AD01") ?? UUID()

    private var harbor: ShelfTitle {
        ShelfTitle(id: "xtream#h#vod#1", kind: .movie, sourceID: source, name: "The Long Harbor")
    }

    private var engines: ShelfTitle {
        ShelfTitle(id: "xtream#h#vod#2", kind: .movie, sourceID: source, name: "Quiet Engines", cast: "Mira Holt")
    }

    private func library(calls: Counter, store: PeopleStore? = nil) async -> ShelfLibrary {
        let titles = [harbor, engines]
        let dependencies = ShelfModel.Dependencies(
            load: { _, kind in ShelfCatalogue(titles: kind == .movie ? titles : [], categories: []) },
            hasLogin: { _ in true },
            episodes: { _, _ in [] },
            info: { _, _ in
                calls.value += 1
                return .movie(VODInfo(year: 2024, cast: "Mira Holt, Jonas Reeve", director: "Sanna Weiss"))
            })
        let library = ShelfLibrary(
            movies: ShelfModel(kind: .movie, dependencies), series: ShelfModel(kind: .series, dependencies), people: store)
        await library.peopleLoaded()
        library.sourcesChanged([SourceDescriptor(id: source, name: "Cabin", kind: .xtream, url: URL(fileURLWithPath: "/cabin"))])
        library.open()
        await library.movies.settled()
        return library
    }

    @Test("browse-by-person/a-person-s-page-never-asks-the-provider the page reads list rows and info answers already received")
    func namesFromRowsAndAnswers() async throws {
        let calls = Counter()
        let library = await library(calls: calls)
        let name = try #require(PersonName("Mira Holt"))
        #expect(await library.people().page(name).movies.map(\.name) == ["Quiet Engines"])

        library.openPage(harbor, from: .poster(row: "recentlyAdded"), in: .movie)
        let model = try #require(library.page?.model)
        await model.load()
        #expect(calls.value == 1)
        let page = await library.people().page(name)
        #expect(page.movies.map(\.name) == ["The Long Harbor", "Quiet Engines"], "the answer's year puts it first")
        #expect(calls.value == 1, "building the page asks the provider nothing")
    }

    @Test("movies-and-series-browsing/browsing-stays-responsive new answers reach the people index without reading every row again")
    func answersOnTopOfRows() async throws {
        let library = await library(calls: Counter())
        let name = try #require(PersonName("Jonas Reeve"))
        #expect(await library.people().page(name).isEmpty)
        for title in [harbor, engines] {
            library.openPage(title, from: .poster(row: "recentlyAdded"), in: .movie)
            await library.page?.model.load()
        }
        async let first = library.people()
        async let second = library.people()
        let (one, two) = await (first, second)
        #expect(one.page(name).movies.count == 2)
        #expect(two.page(name).movies.count == 2)
        #expect(library.rowBuilds == 1, "the titles did not change, so their rows are read once")
    }

    @Test("browse-by-person/a-person-s-page a person's page opens over the title page, and Back returns to its chip")
    func stack() async throws {
        let calls = Counter()
        let library = await library(calls: calls)
        library.openPage(harbor, from: .poster(row: "recentlyAdded"), in: .movie)
        let name = try #require(PersonName("Mira Holt"))
        library.openPerson(name, chip: "cast:mira holt")
        let person = try #require(library.person)
        #expect(person.section == .movie)
        #expect(library.page == nil)

        library.push(engines)
        #expect(library.page?.title == engines)
        #expect(library.page?.origin == .poster(row: "recentlyAdded"), "the stack keeps the first page's origin")
        library.closePage()
        #expect(library.person == person)
        #expect(library.popped?.titleRoute?.title == engines, "the person's page puts focus back on its poster")
        library.restored()
        library.closePage()
        #expect(library.page?.title == harbor)
        guard case .person(let closed)? = library.popped else {
            Issue.record("the person's page is the one just closed")
            return
        }
        #expect(closed.chip == "cast:mira holt")
        library.closePage()
        #expect(library.top == nil)
        #expect(library.returning?.title == harbor, "the section's poster takes focus back")
    }

    @Test("browse-by-person/names-the-provider-sent-are-kept names from info answers are saved and read back")
    func kept() async throws {
        let folder = URL.temporaryDirectory.appending(path: "people-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = PeopleStore(file: folder.appending(path: "credits.json"))
        var learned = LearnedCredits()
        learned.record(harbor, credits: TitleCredits(cast: "Mira Holt", director: nil), year: 2024, now: .now)
        await store.save(learned.encoded(now: .now))

        let library = await library(calls: Counter(), store: store)
        let page = await library.people().page(try #require(PersonName("Mira Holt")))
        #expect(page.movies.map(\.name) == ["The Long Harbor", "Quiet Engines"])
    }
}

extension LibraryPage {
    fileprivate var titleRoute: TitleRoute? {
        if case .title(let route) = self { return route }
        return nil
    }
}
