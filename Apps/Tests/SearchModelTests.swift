import AntennaCore
import Foundation
import SwiftData
import Testing

@testable import Antenna

/// Search's model with a held debounce and a fixed clock: results follow a
/// pause in typing, one letter shows nothing, a finished source shows up on
/// the next search and a programme's start or end shows on the next refresh.
@MainActor
@Suite struct SearchModelTests {
    let source = UUID(uuidString: "00000000-0000-0000-0000-00000000BB01") ?? UUID()
    let start = Date(timeIntervalSince1970: 1_800_000_000)

    /// Lets the debounce through when the test says so.
    @MainActor final class Gate {
        private var waiting: [CheckedContinuation<Void, Never>] = []
        var isEmpty: Bool { waiting.isEmpty }

        func wait() async {
            await withCheckedContinuation { waiting.append($0) }
        }

        func open() {
            waiting.forEach { $0.resume() }
            waiting = []
        }
    }

    @MainActor final class Clock {
        var now: Date
        init(_ now: Date) { self.now = now }
    }

    private func corpus(_ channels: [Channel], programmes: [Programme] = [], sources: SearchSources = .loaded) -> SearchCorpus {
        let tagged = Channel.tagged(channels, sourceID: source)
        return SearchCorpus(
            catalogue: Catalogue(channels: tagged, groupOrder: [:], favorites: []), sourceOrder: [source: 0],
            guide: GuideIndex(programmes: [source: programmes]), titles: [], hasTitles: false, sources: sources)
    }

    private func channel(_ name: String, epg: String? = nil) -> Channel {
        Channel(id: name, name: name, streamURL: URL(filePath: "/\(name)"), epgID: epg)
    }

    private func settle(_ gate: Gate) async {
        while gate.isEmpty { await Task.yield() }
    }

    private func model(gate: Gate, clock: Clock) -> SearchModel {
        SearchModel(.init(debounce: .milliseconds(300), sleep: { _ in await gate.wait() }, now: { clock.now }))
    }

    @Test("search/find-things-the-way-you-type-them results follow once typing pauses, one letter shows nothing")
    func debounce() async {
        let gate = Gate()
        let model = model(gate: gate, clock: Clock(start))
        await model.load(corpus([channel("Northern News"), channel("Nordic One")]))

        model.type("n")
        #expect(model.results.isEmpty)
        model.type("no")
        await settle(gate)
        #expect(model.results.isEmpty, "nothing until the pause")
        model.type("nor")
        // The first pause was cancelled; let every waiting pause end until results show.
        while model.results.isEmpty {
            gate.open()
            await Task.yield()
        }
        #expect(model.results.channels.map(\.channel.name) == ["Nordic One", "Northern News"])

        model.type("n")
        #expect(model.results.isEmpty, "one letter clears at once")
    }

    @Test("search/nothing-found a source that finishes loading shows up in the next results")
    func sourceFinishes() async {
        let gate = Gate()
        let model = model(gate: gate, clock: Clock(start))
        await model.load(corpus([], sources: .loading))
        model.run("arena")
        await model.searched()
        #expect(model.results.isEmpty)
        #expect(model.sources == .loading)
        #expect(searchMessage(model)?.title == SearchText.channelsLoading())

        await model.load(corpus([channel("Arena")], sources: .partial))
        #expect(model.results.channels.map(\.channel.name) == ["Arena"])

        model.run("zzz")

        await model.searched()
        #expect(searchMessage(model)?.lines == [SearchText.hint(), SearchText.someStillLoading()])
    }

    @Test("search/seven-days-of-guide a programme that ends drops out on the next refresh")
    func refresh() async {
        let gate = Gate()
        let clock = Clock(start)
        let model = model(gate: gate, clock: clock)
        let show = Programme(channelID: "d", start: start.addingTimeInterval(-60), stop: start.addingTimeInterval(60), title: "Wild North")
        let next = Programme(channelID: "d", start: start.addingTimeInterval(60), stop: start.addingTimeInterval(3600), title: "Wild North")
        await model.load(corpus([channel("Docu", epg: "d")], programmes: [show, next]))
        model.run("wild")
        await model.searched()
        #expect(model.results.programmes.map(\.isOnNow) == [true, false])

        clock.now = start.addingTimeInterval(61)
        model.refresh()
        await model.searched()
        #expect(model.results.programmes.map(\.isOnNow) == [true])
        #expect(model.results.programmes.first?.programme.start == next.start)
    }

    @Test("search/clear-the-field clear empties the field and asks for the cursor")
    func clear() async {
        let gate = Gate()
        let model = model(gate: gate, clock: Clock(start))
        await model.load(corpus([channel("Arena")]))
        model.run("arena")
        await model.searched()
        let requests = model.focusRequests
        model.clear()
        #expect(model.query.isEmpty)
        #expect(model.results.isEmpty)
        #expect(model.focusRequests == requests + 1)
    }

    @Test("search/search-with-a-keyboard the arrows move through the rows and back up into the field")
    func cursor() async {
        let gate = Gate()
        let model = model(gate: gate, clock: Clock(start))
        await model.load(corpus([channel("Arena One"), channel("Arena Two")]))
        model.run("arena")
        await model.searched()
        model.moveCursor(1)
        #expect(model.cursor == model.items.first)
        model.moveCursor(1)
        model.moveCursor(1)
        #expect(model.cursor == model.items.last, "stops at the last row")
        let requests = model.focusRequests
        model.moveCursor(-1)
        model.moveCursor(-1)
        #expect(model.cursor == nil)
        #expect(model.focusRequests == requests + 1, "up from the first row goes back to the field")
    }

    // search/results-grouped-best-first, People last
    @Test("browse-by-person/find-a-person-in-search people come last in All, out of the narrowed views, and count as results")
    func people() async {
        let gate = Gate()
        let model = model(gate: gate, clock: Clock(start))
        await model.load(corpus([channel("Mira TV")]))
        let titles = [ShelfTitle(id: "xtream#h#vod#1", kind: .movie, sourceID: source, name: "Salt Road", cast: "Mira Holt")]
        model.peopleChanged(PeopleIndex(titles: titles, learned: LearnedCredits()))
        model.run("mira")
        await model.searched()
        #expect(model.people.map(\.name) == ["Mira Holt"])
        #expect(model.items.last == .person(PersonName.key("Mira Holt")), "People comes after every other section")
        model.scope = .channels
        #expect(model.shownPeople.isEmpty, "no People in a narrowed view")
        model.scope = .all
        model.run("holt")
        await model.searched()
        #expect(model.results.isEmpty)
        #expect(!model.foundNothing, "a person alone is a result")
        model.run("zz")
        await model.searched()
        #expect(model.people.isEmpty)
    }

    /// Holds the answer to one query until the test lets it through.
    actor HeldAnswer {
        private var waiting: [CheckedContinuation<Void, Never>] = []
        private(set) var released = 0

        func wait() async {
            await withCheckedContinuation { waiting.append($0) }
            released += 1
        }

        func open() {
            waiting.forEach { $0.resume() }
            waiting = []
        }

        var isWaiting: Bool { !waiting.isEmpty }
    }

    @Test("search/find-things-the-way-you-type-them an answer that arrives after a newer query never replaces it")
    func lateAnswer() async {
        let held = HeldAnswer()
        let model = SearchModel(
            .init(
                debounce: .zero, sleep: { _ in }, now: { [start] in start },
                answer: { index, people, query, now in
                    if query.text == "arena" { await held.wait() }
                    return await SearchModel.answer(index, people, query, now)
                }))
        await model.load(corpus([channel("Arena One"), channel("Arena Two"), channel("Nordic")]))

        model.run("arena")
        while await !held.isWaiting { await Task.yield() }
        model.run("nordic")
        await model.searched()
        #expect(model.results.channels.map(\.channel.name) == ["Nordic"])
        await held.open()
        while await held.released < 1 { await Task.yield() }
        for _ in 0..<20 { await Task.yield() }
        #expect(model.results.channels.map(\.channel.name) == ["Nordic"], "the late answer is dropped")

        model.run("arena")
        while await !held.isWaiting { await Task.yield() }
        model.type("a")
        #expect(model.results.isEmpty, "one letter clears at once")
        await held.open()
        while await held.released < 2 { await Task.yield() }
        for _ in 0..<20 { await Task.yield() }
        #expect(model.results.isEmpty, "the late answer does not come back")
        #expect(model.query == "a")
    }
}
