import Foundation
import Testing

@testable import AntennaCore

/// Fixtures shared by the search tests: two sources, a guide and a library.
enum SearchFixture {
    static let home = UUID(uuidString: "00000000-0000-0000-0000-0000000005A1") ?? UUID()
    static let cabin = UUID(uuidString: "00000000-0000-0000-0000-0000000005A2") ?? UUID()
    /// Tuesday 3 November 2026, 21:30 UTC.
    static let now = Date(timeIntervalSince1970: 1_793_741_400)

    static func channel(
        _ name: String, number: Int?, group: String? = nil, source: UUID = home, position: Int = 0, epg: String? = nil,
        catchUp: Bool = false
    ) -> SearchChannel {
        let channel = Channel(
            id: "ch-\(name)-\(position)", name: name, streamURL: URL(filePath: "/\(position)"), group: group, epgID: epg, number: number,
            hasCatchup: catchUp, sourceID: source, position: position)
        guard let key = RowKey(channel) else { preconditionFailure("a tagged channel has a row key") }
        return SearchChannel(
            key: key, name: name, group: group, number: number, sourceOrder: source == home ? 0 : 1,
            guideKey: GuideKey(channel: channel), hasCatchup: catchUp)
    }

    static func show(_ title: String, epg: String, minutes: Double, length: Double = 60, subtitle: String? = nil) -> Programme {
        let start = now.addingTimeInterval(minutes * 60)
        return Programme(channelID: epg, start: start, stop: start.addingTimeInterval(length * 60), title: title, subtitle: subtitle)
    }

    static func title(_ name: String, _ kind: ShelfTitle.Kind = .movie, id: String? = nil) -> ShelfTitle {
        ShelfTitle(id: id ?? "xtream#cabin#\(kind == .movie ? "vod" : "series")#\(name)", kind: kind, sourceID: cabin, name: name)
    }

    static func guide(_ epg: String, source: UUID = home) -> GuideKey {
        GuideKey(sourceID: source, epgID: epg)
    }
}

extension SearchIndex {
    /// An index built at `SearchFixture.now` over these programmes per guide key.
    init(channels: [SearchChannel], programmes: [GuideKey: [Programme]], titles: [ShelfTitle]) {
        var bySource: [UUID: [Programme]] = [:]
        for (key, list) in programmes {
            bySource[key.sourceID, default: []] += list.map { programme in
                var copy = programme
                copy.channelID = key.epgID
                return copy
            }
        }
        self.init(channels: channels, guide: GuideIndex(programmes: bySource), titles: titles, now: SearchFixture.now)
    }
}

struct SearchIndexTests {
    typealias Fixture = SearchFixture

    /// "Northern News" and "Nordic One" (group "Northern Report"), the
    /// programme "True North" and the movie "Northbound".
    private var north: SearchIndex {
        SearchIndex(
            channels: [
                Fixture.channel("Northern News", number: 201, position: 0, epg: "nn"),
                Fixture.channel("Nordic One", number: 301, group: "Northern Report", position: 1),
            ],
            programmes: [Fixture.guide("nn"): [Fixture.show("True North", epg: "nn", minutes: 30)]],
            titles: [Fixture.title("Northbound")])
    }

    private func names(_ results: SearchResults) -> [String] {
        results.channels.map(\.channel.name) + results.programmes.map(\.programme.title) + results.titles.map(\.title.name)
    }

    @Test("search/find-things-the-way-you-type-them case and accents are ignored")
    func caseAndAccents() {
        for typed in ["north", "NÖRTH", "  North  "] {
            let results = north.results(for: SearchQuery(typed), now: Fixture.now)
            #expect(names(results) == ["Northern News", "Nordic One", "True North", "Northbound"], "\(typed)")
        }
    }

    @Test("search/find-things-the-way-you-type-them every word has to be in the same name")
    func everyWordInOneField() {
        let results = north.results(for: SearchQuery("north news"), now: Fixture.now)
        #expect(names(results) == ["Northern News"])
        // "nordic" is in the name and "report" only in the group: no field has both.
        #expect(north.results(for: SearchQuery("nordic report"), now: Fixture.now).isEmpty)
    }

    @Test("search/find-things-the-way-you-type-them a channel found by its group says so")
    func matchedByGroup() throws {
        let results = north.results(for: SearchQuery("north"), now: Fixture.now)
        let nordic = try #require(results.channels.first { $0.channel.name == "Nordic One" })
        #expect(nordic.match == .group)
        #expect(SearchText.channelLine(nordic, now: nil) == "301 · Matches Northern Report")
        #expect(results.channels.first?.match == .name)
        #expect(SearchText.channelLine(try #require(results.channels.first), now: "Late Edition") == "201 · Now: Late Edition")
    }

    @Test("search/find-things-the-way-you-type-them one letter shows nothing yet")
    func oneLetter() {
        #expect(north.results(for: SearchQuery("n"), now: Fixture.now).isEmpty)
        #expect(north.results(for: SearchQuery(" n "), now: Fixture.now).isEmpty)
        #expect(!SearchQuery("n").isSearchable)
        #expect(SearchQuery("no").isSearchable)
    }

    @Test("search/find-things-the-way-you-type-them the same name in two sources shows twice")
    func duplicatesAcrossSources() {
        let index = SearchIndex(
            channels: [
                Fixture.channel("Arena", number: 7, source: Fixture.home, position: 0),
                Fixture.channel("Arena", number: 7, source: Fixture.cabin, position: 0),
            ],
            programmes: [:], titles: [])
        let results = index.results(for: SearchQuery("arena"), now: Fixture.now)
        #expect(results.channels.map(\.channel.key.sourceID) == [Fixture.home, Fixture.cabin])
        #expect(index.results(for: SearchQuery("7"), now: Fixture.now).channels.isEmpty, "one digit is one character")
    }

    @Test("search/find-things-the-way-you-type-them blank names and long queries")
    func blanksAndLength() {
        let index = SearchIndex(channels: [Fixture.channel("   ", number: 1)], programmes: [:], titles: [Fixture.title(" ")])
        #expect(index.results(for: SearchQuery("  "), now: Fixture.now).isEmpty)
        let long = String(repeating: "a", count: 140)
        #expect(SearchQuery(long).text.count == 100)
    }

    // MARK: Numbers

    /// Channel 104, channel 1040, channel 21, the movie "1917" and a programme "104".
    private var numbers: SearchIndex {
        SearchIndex(
            channels: [
                Fixture.channel("Harbour TV", number: 104, position: 0, epg: "h"),
                Fixture.channel("Coast Life", number: 1040, position: 1),
                Fixture.channel("Meadow", number: 21, position: 2),
            ],
            programmes: [Fixture.guide("h"): [Fixture.show("104", epg: "h", minutes: 60)]],
            titles: [Fixture.title("1917")])
    }

    @Test("search/find-a-channel-by-its-number digits match titles as text, not a channel number in the middle")
    func digitsAsText() {
        let results = numbers.results(for: SearchQuery("19"), now: Fixture.now)
        #expect(results.titles.map(\.title.name) == ["1917"])
        #expect(results.channels.isEmpty)
    }

    @Test("search/find-a-channel-by-its-number a number finds every channel starting with it, leading zeros ignored")
    func channelNumber() {
        for typed in ["104", "0104"] {
            let results = numbers.results(for: SearchQuery(typed), now: Fixture.now)
            #expect(results.channels.map(\.channel.number) == [104, 1040], "\(typed)")
            #expect(results.channels.allSatisfy { $0.match == .number })
        }
        #expect(numbers.results(for: SearchQuery("104"), now: Fixture.now).programmes.map(\.programme.title) == ["104"])
        #expect(numbers.results(for: SearchQuery("00"), now: Fixture.now).channels.isEmpty)
    }

    // MARK: Order

    @Test("search/results-grouped-best-first names starting with the query come first, then word starts, then the rest")
    func channelBands() {
        let index = SearchIndex(
            channels: [
                Fixture.channel("Arena Sport", number: 9, group: "Sport", position: 0),
                Fixture.channel("Sportsline", number: 3, position: 1),
                Fixture.channel("Eurosport", number: 2, position: 2),
                Fixture.channel("Sport 1", number: 4, position: 3),
                Fixture.channel("Kids", number: 5, group: "Sport extra", position: 4),
                Fixture.channel("Sport 1", number: 1, source: Fixture.cabin, position: 0),
            ],
            programmes: [:], titles: [])
        let results = index.results(for: SearchQuery("sport"), now: Fixture.now)
        #expect(results.channels.map(\.channel.name) == ["Sport 1", "Sport 1", "Sportsline", "Arena Sport", "Eurosport", "Kids"])
        #expect(results.channels.prefix(2).map(\.channel.number) == [1, 4], "same name: lower number first")
        #expect(results.channels.last?.match == .group)
    }

    @Test("search/results-grouped-best-first programmes in start order, on now first, ties on channel number")
    func programmeOrder() {
        let index = SearchIndex(
            channels: [
                Fixture.channel("Docu HD", number: 12, position: 0, epg: "docu"),
                Fixture.channel("Drama One", number: 5, position: 1, epg: "drama"),
            ],
            programmes: [
                Fixture.guide("docu"): [
                    Fixture.show("North Sea Patrol", epg: "docu", minutes: -30), Fixture.show("North Sea Patrol", epg: "docu", minutes: 90),
                ],
                Fixture.guide("drama"): [
                    Fixture.show("North Sea Patrol", epg: "drama", minutes: 90), Fixture.show("Northern Lights", epg: "drama", minutes: 30),
                ],
            ],
            titles: [])
        let results = index.results(for: SearchQuery("north"), now: Fixture.now)
        #expect(
            results.programmes.map(\.programme.title) == ["North Sea Patrol", "Northern Lights", "North Sea Patrol", "North Sea Patrol"])
        #expect(results.programmes.map(\.isOnNow) == [true, false, false, false])
        #expect(results.programmes.suffix(2).map(\.channel.name) == ["Drama One", "Docu HD"], "same start: lower number first")
    }

    @Test("search/results-grouped-best-first the same programme on two channels shows twice, on air first")
    func sameProgrammeTwice() {
        let index = SearchIndex(
            channels: [Fixture.channel("One", number: 1, position: 0, epg: "a"), Fixture.channel("Two", number: 2, position: 1, epg: "b")],
            programmes: [
                Fixture.guide("a"): [Fixture.show("Match Day", epg: "a", minutes: 60)],
                Fixture.guide("b"): [Fixture.show("Match Day", epg: "b", minutes: -10)],
            ],
            titles: [])
        let results = index.results(for: SearchQuery("match"), now: Fixture.now)
        #expect(results.programmes.map(\.channel.name) == ["Two", "One"])
        #expect(results.programmes.map(\.isOnNow) == [true, false])
    }

    @Test("search/results-grouped-best-first channels sharing a guide show its programme once, under the lowest number")
    func sharedGuide() {
        let index = SearchIndex(
            channels: [
                Fixture.channel("News HD", number: 8, position: 0, epg: "n"), Fixture.channel("News", number: 3, position: 1, epg: "n"),
            ],
            programmes: [Fixture.guide("n"): [Fixture.show("Late Edition", epg: "n", minutes: 0)]], titles: [])
        let results = index.results(for: SearchQuery("late"), now: Fixture.now)
        #expect(results.programmes.map(\.channel.name) == ["News"])
        #expect(results.programmes.first?.id == .init(guideKey: Fixture.guide("n"), start: Fixture.now))
    }

    @Test("search/results-grouped-best-first titles starting with the query first, counts per kind and in total")
    func titlesAndCounts() {
        let index = SearchIndex(
            channels: [Fixture.channel("North Sport", number: 118, position: 0)], programmes: [:],
            titles: [
                Fixture.title("True North"), Fixture.title("Northern Lights", .series), Fixture.title("Northbound"),
                Fixture.title("The North Water", .series),
            ])
        let results = index.results(for: SearchQuery("north"), now: Fixture.now)
        #expect(results.titles.map(\.title.name) == ["Northbound", "Northern Lights", "The North Water", "True North"])
        #expect(results.count(.all) == 5)
        #expect(results.count(.channels) == 1)
        #expect(results.count(.guide) == 0)
        #expect(results.count(.movies) == 2)
        #expect(results.count(.series) == 2)
        #expect(results.shownTitles(.series).map(\.title.name) == ["Northern Lights", "The North Water"])
    }

    @Test("search/results-grouped-best-first the matched letters are highlighted, accents and case ignored")
    func highlights() {
        let query = SearchQuery("north news")
        let name = "Northern News"
        #expect(query.highlights(in: name).map { String(name[$0]) } == ["North", "News"])
        let accented = "Nörth Café"
        #expect(SearchQuery("cafe north").highlights(in: accented).map { String(accented[$0]) } == ["Nörth", "Café"])
        #expect(SearchQuery("orth").highlights(in: "North orth").map { String("North orth"[$0]) } == ["orth"], "first occurrence only")
        #expect(SearchQuery("nor nort").highlights(in: name).map { String(name[$0]) } == ["Nort"], "overlaps merge")
    }

    @Test("search/results-grouped-best-first without guide data the guide section is empty")
    func noGuide() {
        let index = SearchIndex(channels: [Fixture.channel("Northern News", number: 1)], programmes: [:], titles: [])
        let results = index.results(for: SearchQuery("north"), now: Fixture.now)
        #expect(results.programmes.isEmpty)
        #expect(results.count(.guide) == 0)
    }

    // MARK: Seven days

    @Test("search/seven-days-of-guide only programmes on now or starting within seven days")
    func sevenDays() {
        let day = 24.0 * 60
        let index = SearchIndex(
            channels: [Fixture.channel("Docu", number: 1, epg: "d")],
            programmes: [
                Fixture.guide("d"): [
                    Fixture.show("Wild North", epg: "d", minutes: -120),
                    Fixture.show("Wild North", epg: "d", minutes: -30),
                    Fixture.show("Wild North", epg: "d", minutes: 6 * day),
                    Fixture.show("Wild North", epg: "d", minutes: 7 * day - 1),
                    Fixture.show("Wild North", epg: "d", minutes: 7 * day),
                    Fixture.show("Wild North", epg: "d", minutes: 9 * day),
                ]
            ], titles: [])
        let results = index.results(for: SearchQuery("wild"), now: Fixture.now)
        #expect(results.programmes.map(\.programme.start) == [-30, 6 * day, 7 * day - 1].map { Fixture.now.addingTimeInterval($0 * 60) })
        // The one on now drops out on the first query after it ends, and the
        // seven days move on with the clock.
        let later = Fixture.now.addingTimeInterval(31 * 60)
        #expect(index.results(for: SearchQuery("wild"), now: later).programmes.count == 3)
        #expect(index.results(for: SearchQuery("wild"), now: later).programmes.first?.isOnNow == false)
    }

    @Test("search/seven-days-of-guide each programme says NOW or its day and time, its channel and catch-up")
    func programmeText() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        let text = SearchText(calendar: calendar, locale: Locale(identifier: "en_GB"))
        let index = SearchIndex(
            channels: [
                Fixture.channel("Docu HD", number: 3, epg: "d", catchUp: true),
                Fixture.channel("Music Box", number: 4, position: 1, epg: "m"),
            ],
            programmes: [
                Fixture.guide("d"): [Fixture.show("Northern Lights", epg: "d", minutes: -30, subtitle: "S2 E4")],
                Fixture.guide("m"): [
                    Fixture.show("North Late", epg: "m", minutes: 60), Fixture.show("North Soul", epg: "m", minutes: 24 * 60),
                    Fixture.show("North Week", epg: "m", minutes: 3 * 24 * 60),
                ],
            ], titles: [])
        let hits = index.results(for: SearchQuery("north"), now: Fixture.now).programmes
        #expect(hits.count == 4)
        #expect(text.lead(hits[0], now: Fixture.now) == nil)
        #expect(text.detail(hits[0], now: Fixture.now) == "Docu HD · 21:00 – 22:00")
        #expect(SearchText.programmeTitle(hits[0].programme) == "Northern Lights · S2 E4")
        #expect(hits[0].hasCatchup)
        #expect(text.lead(hits[1], now: Fixture.now) == "22:30")
        #expect(text.detail(hits[1], now: Fixture.now) == "Music Box · Today")
        #expect(!hits[1].hasCatchup)
        #expect(text.lead(hits[2], now: Fixture.now) == "Wed 21:30")
        #expect(text.detail(hits[2], now: Fixture.now) == "Music Box · Tomorrow")
        #expect(text.detail(hits[3], now: Fixture.now) == "Music Box · Friday")
        #expect(text.later(hits[2].programme, now: Fixture.now) == "Tomorrow 21:30 · North Soul")
    }

    // MARK: Caps

    @Test("search/very-long-result-lists 600 channels list 500 with the full count, the guide four until See all")
    func caps() {
        let channels = (0..<600).map { Fixture.channel("Harbour \($0)", number: 1000 + $0, position: $0, epg: "h\($0)") }
        let programmes = Dictionary(
            uniqueKeysWithValues: (0..<6).map { (Fixture.guide("h\($0)"), [Fixture.show("Harbour Talk", epg: "h\($0)", minutes: 10)]) })
        let results = SearchIndex(channels: channels, programmes: programmes, titles: []).results(
            for: SearchQuery("harbour"), now: Fixture.now)
        #expect(results.count(.channels) == 600)
        #expect(results.shownChannels.count == 500)
        #expect(results.isChannelListCapped)
        #expect(SearchText.showing(results.shownChannels.count, of: results.count(.channels)) == "Showing 500 of 600")
        #expect(results.shownProgrammes(.all, expanded: false).count == 4)
        #expect(results.shownProgrammes(.all, expanded: true).count == 6)
        #expect(results.shownProgrammes(.guide, expanded: false).count == 6)
        #expect(SearchText.seeAll(results.count(.guide)) == "See all 6")
    }

    @Test("search/nothing-found the message names the query")
    func nothingFound() {
        let query = SearchQuery("norhtern")
        #expect(north.results(for: query, now: Fixture.now).isEmpty)
        #expect(SearchText.noResults(query) == "No results for “norhtern”")
    }
}
