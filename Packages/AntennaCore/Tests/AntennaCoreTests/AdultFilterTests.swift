import Foundation
import Testing

@testable import AntennaCore

/// The adult filter in the catalogue, the shelf, search and the Siri lookups.
@Suite struct AdultFilterTests {
    static let news = CatalogueGroup.named(sourceA, "News")
    static let xxx = CatalogueGroup.named(sourceA, "XXX")
    static let sport = CatalogueGroup.named(sourceA, "Sport")
    static let swim = CatalogueGroup.named(sourceA, "Adult Swim")
    static let night = CatalogueGroup.named(sourceA, "Night")

    /// News 101, XXX 201 202, Sport 301 and 302 (flagged), Adult Swim 401,
    /// Night 501 502 (both flagged).
    static func channels() -> [Channel] {
        var flagged = channel("s2", group: "Sport", number: 302)
        flagged.isAdult = true
        var nightOne = channel("g1", group: "Night", number: 501)
        nightOne.isAdult = true
        var nightTwo = channel("g2", group: "Night", number: 502)
        nightTwo.isAdult = true
        return Channel.tagged(
            [
                channel("n1", group: "News", number: 101), channel("x1", group: "XXX", number: 201),
                channel("x2", group: "XXX", number: 202), channel("s1", group: "Sport", number: 301), flagged,
                channel("k1", group: "Adult Swim", number: 401), nightOne, nightTwo,
            ], sourceID: sourceA)
    }

    static func build(
        _ rules: GroupRules = GroupRules(), favorites: [Snapshot] = [], recents: [LastChannelKey] = []
    ) -> TestCatalogue {
        TestCatalogue(channels: channels(), groupOrder: [:], favorites: favorites, recents: recents, rules: rules)
    }

    /// The row of fixture channel `id`; every id the tests name exists.
    static func key(_ id: String) -> RowKey {
        let keys = channels().compactMap(RowKey.init)
        guard let key = keys.first(where: { $0.id == id }) else { preconditionFailure("no fixture channel \(id)") }
        return key
    }

    static func ids(_ rows: [RowKey]) -> [String] { rows.map(\.id) }

    @Test("adult-content/hidden-everywhere-by-default a catalogue with no rules leaves adult groups and channels out")
    func hiddenByDefault() {
        let catalogue = Self.build()
        #expect(catalogue.groups == [.favorites, .all, Self.news, Self.sport, Self.swim])
        #expect(Self.ids(catalogue.rows(in: .all)) == ["n1", "s1", "k1"])
        #expect(Self.ids(catalogue.rows(in: Self.sport)) == ["s1"])
        #expect(catalogue.rows(in: Self.xxx).isEmpty && catalogue.rows(in: Self.night).isEmpty)
        #expect(catalogue.count(of: Self.sport) == 1)
        #expect(catalogue.lockedGroups.isEmpty)
        #expect(catalogue.managedGroups == [.all, Self.news, Self.sport, Self.swim])
        #expect(catalogue.hidesAdultGroups)
        #expect(Self.ids(catalogue.searchRows(includingHidden: true)) == ["n1", "s1", "k1"])
    }

    @Test("adult-content/hidden-everywhere-by-default hidden channels have no number, match no digits and other numbers stay")
    func numbers() {
        let catalogue = Self.build()
        #expect(catalogue.number(for: Self.key("x1")) == nil)
        #expect(catalogue.number(for: Self.key("s2")) == nil)
        #expect(catalogue.number(for: Self.key("s1")) == 301)
        #expect(catalogue.number(for: Self.key("k1")) == 401)
        #expect(catalogue.match(digits: "2") == nil)
        #expect(catalogue.match(digits: "302") == nil)
        #expect(catalogue.position(of: Self.key("x1"), in: .all) == nil)
        #expect(catalogue.position(of: Self.key("s1"), in: Self.sport).map { $0 == (1, 1) } == true)
    }

    @Test("adult-content/hidden-everywhere-by-default favorites, recents and New leave adult channels out")
    func favoritesRecentsNew() {
        let favorites = [
            Snapshot(channelID: "x1", sourceID: sourceA, sortOrder: 0), Snapshot(channelID: "n1", sourceID: sourceA, sortOrder: 1),
        ]
        let recents = [LastChannelKey(sourceID: sourceA, channelID: "s2"), LastChannelKey(sourceID: sourceA, channelID: "s1")]
        let catalogue = Self.build(favorites: favorites, recents: recents)
        #expect(Self.ids(catalogue.rows(in: .favorites)) == ["n1"])
        #expect(Self.ids(catalogue.rows(in: .recents)) == ["s1"])
        let now = Date(timeIntervalSince1970: 1_000_000)
        let seen = SeenChannels(firstLoad: [], now: now.addingTimeInterval(-86_400 * 30))
        let fresh = SeenChannels.recording(seen, channelIDs: ["x1", "s2", "k1"], now: now)
        let withNew = NewChannels.group(catalogue, seen: [sourceA: fresh], now: now)
        #expect(Self.ids(withNew.rows(in: .new)) == ["k1"])
    }

    @Test("adult-content/hidden-everywhere-by-default a hidden adult channel reads as hidden, not locked, and asks for no lock")
    func notLocked() {
        let catalogue = Self.build(GroupRules(locked: [Self.xxx, Self.news]))
        #expect(catalogue.isAdultHidden(Self.key("x1")))
        #expect(!catalogue.isLocked(Self.key("x1")))
        #expect(catalogue.isLocked(Self.key("n1")))
        #expect(!catalogue.isAdultHidden(Self.key("n1")))
        #expect(catalogue.lockedGroups == [Self.news])
        #expect(!catalogue.isLocked(Self.xxx))
    }

    @Test("adult-content/show-adult-content-with-the-passcode a profile that shows adult content sees every channel as without the filter")
    func shown() {
        let shown = Self.build(GroupRules(showsAdult: true))
        let plain = TestCatalogue(channels: Self.channels(), groupOrder: [:], favorites: [], rules: GroupRules(showsAdult: true))
        #expect(shown.groups == [.favorites, .all, Self.news, Self.xxx, Self.sport, Self.swim, Self.night])
        #expect(shown.groups == plain.groups)
        #expect(shown.rows(in: .all).count == 8)
        #expect(shown.number(for: Self.key("x1")) == 201)
        #expect(!shown.hidesAdultGroups)
        #expect(shown.isAdult(Self.xxx) && shown.isAdult(Self.night) && !shown.isAdult(Self.sport) && !shown.isAdult(Self.swim))
        #expect(shown.managedGroups.contains(Self.xxx))
        #expect(!shown.isAdultHidden(Self.key("x1")))
    }

    @Test("adult-content/correct-a-group the user's mark overrides the name and the provider's flag")
    func corrections() {
        let rules = GroupRules(adultMarks: [Self.xxx: false, Self.sport: false, Self.news: true, Self.night: false])
        let catalogue = Self.build(rules)
        #expect(catalogue.groups == [.favorites, .all, Self.xxx, Self.sport, Self.swim, Self.night])
        #expect(Self.ids(catalogue.rows(in: Self.sport)) == ["s1", "s2"])
        #expect(Self.ids(catalogue.rows(in: .all)) == ["x1", "x2", "s1", "s2", "k1", "g1", "g2"])
        #expect(catalogue.isAdult(Self.news) && !catalogue.isAdult(Self.xxx))
        #expect(catalogue.number(for: Self.key("n1")) == nil)
    }

    @Test("adult-content/correct-a-group a group whose every channel the provider flags is adult")
    func flaggedGroup() {
        let catalogue = Self.build()
        #expect(catalogue.isAdult(Self.night))
        #expect(!catalogue.isAdult(Self.sport), "one flagged channel hides the channel, not its group")
    }

    @Test("adult-content/correct-a-group an own group marked adult hides with its channels, and adult members leave other own groups")
    func ownGroups() {
        let mine = UUID()
        let theirs = UUID()
        let members = ["n1", "x1"].map { GroupRules.Member(channelID: $0, sourceID: sourceA) }
        let rules = GroupRules(
            ownGroups: [
                GroupRules.OwnGroup(id: mine, name: "Mine", members: members),
                GroupRules.OwnGroup(id: theirs, name: "Theirs", members: [GroupRules.Member(channelID: "k1", sourceID: sourceA)]),
            ], adultMarks: [.own(theirs): true])
        let catalogue = Self.build(rules)
        #expect(Self.ids(catalogue.rows(in: .own(mine))) == ["n1"])
        #expect(!catalogue.groups.contains(.own(theirs)))
        #expect(catalogue.number(for: Self.key("k1")) == nil)
        #expect(catalogue.groups.contains(.own(mine)))
    }

    @Test("adult-content/hidden-everywhere-by-default settings for gone adult groups are not listed while hidden")
    func orphans() {
        let gone = CatalogueGroup.named(sourceA, "Erotik")
        let goneMarked = CatalogueGroup.named(sourceA, "Late")
        let goneNews = CatalogueGroup.named(sourceA, "Old News")
        let rules = GroupRules(hidden: [gone, goneNews], adultMarks: [goneMarked: true])
        #expect(Self.build(rules).orphanedGroups == [goneNews])
        var shown = rules
        shown.showsAdult = true
        #expect(Set(Self.build(shown).orphanedGroups) == [gone, goneMarked, goneNews])
    }

    @Test("adult-content/hidden-everywhere-by-default search, Siri and Shortcuts find no hidden adult channel")
    func searchAndIntents() {
        let catalogue = Self.build()
        let search = SearchChannel.all(in: catalogue, includingHidden: true).map(\.key.id)
        #expect(search == ["n1", "s1", "k1"])
        #expect(ChannelMatcher(catalogue).matches("Channel", limit: 20).map(\.id).sorted() == ["k1", "n1", "s1"])
        #expect(Self.ids(IntentLookup.suggestedChannels(in: catalogue)) == ["n1", "s1", "k1"])
        let sources = [IntentSource(id: sourceA, name: "Home", state: .loaded)]
        #expect(
            IntentLookup.channel(LastChannelKey(sourceID: sourceA, channelID: "x1"), in: catalogue, sources: sources)
                == .failure(.adultHidden))
        #expect(
            (try? IntentLookup.channel(LastChannelKey(sourceID: sourceA, channelID: "n1"), in: catalogue, sources: sources).get())?.id
                == "n1")
    }

    @Test("adult-content/links-to-hidden-content-ask-first the reply about a hidden adult item names nothing")
    func reply() {
        let english = IntentFailure.adultHidden.description(Locale(identifier: "en_US"))
        #expect(english == "This profile hides adult content. Show it in Antenna's Settings first.")
    }

    // MARK: Movies and series

    static func titles() -> [ShelfTitle] {
        let source = sourceA
        return [
            ShelfTitle(
                id: "m1", kind: .movie, sourceID: source, name: "Long Winter", added: Date(timeIntervalSince1970: 100), category: "Drama"),
            ShelfTitle(
                id: "m2", kind: .movie, sourceID: source, name: "Night Film", added: Date(timeIntervalSince1970: 300), category: "XXX"),
            ShelfTitle(
                id: "m3", kind: .movie, sourceID: source, name: "Flagged Film", added: Date(timeIntervalSince1970: 200), category: "Drama",
                cast: "Ann Lee", isAdult: true),
            ShelfTitle(id: "m4", kind: .movie, sourceID: source, name: "Cartoons", category: "Adult Swim", cast: "Bo Ray"),
        ]
    }

    @Test("adult-content/hidden-everywhere-by-default the movie shelf leaves adult titles out of rows, banner and lookups")
    func shelfHidden() {
        let index = ShelfIndex(
            catalogues: [ShelfCatalogue(titles: Self.titles(), categories: ["Drama", "XXX", "Adult Swim"])], showsAdult: false, now: .now)
        #expect(index.titles.map(\.id) == ["m1", "m4"])
        #expect(index.banner.map(\.id) == ["m1", "m4"])
        #expect(index.rows.map(\.id) == [.recentlyAdded, .category("Drama"), .category("Adult Swim")])
        #expect(index.title(ActivityKey(titleID: "m2", sourceID: sourceA)) == nil)
        #expect(index.withheldTitle(ActivityKey(titleID: "m2", sourceID: sourceA))?.name == "Night Film")
        #expect(index.withheldTitle(ActivityKey(titleID: "m1", sourceID: sourceA)) == nil)
        let people = PeopleIndex(titles: index.titles, learned: LearnedCredits())
        #expect(people.search(SearchQuery("Ann")).isEmpty)
        #expect(!people.search(SearchQuery("Bo")).isEmpty)
        let search = SearchIndex(channels: [], guide: GuideIndex(), titles: index.titles, now: .now)
        #expect(search.results(for: SearchQuery("Film"), now: .now).titles.isEmpty)
    }

    @Test("adult-content/hidden-everywhere-by-default Continue watching, recently watched and Siri leave adult titles out")
    func shelfActivity() {
        let index = ShelfIndex(catalogues: [ShelfCatalogue(titles: Self.titles(), categories: [])], showsAdult: false, now: .now)
        let progress = ["m2", "m1"].enumerated().map { place, id in
            WatchProgress(
                id: id, titleID: id, sourceID: sourceA, position: 600, duration: 6_000,
                updatedAt: Date(timeIntervalSince1970: Double(1_000 - place)))
        }
        #expect(ContinueWatching.items(progress: progress, titles: index.titles).map(\.title.id) == ["m1"])
        #expect(RecentlyWatched.list(progress: progress, titles: index.titles, kind: .movie).map(\.id) == ["m1"])
        let all = Self.titles()
        #expect(
            IntentLookup.suggestedTitles(
                progress: progress, myList: [ActivityKey(titleID: "m3", sourceID: sourceA)], titles: all, showsAdult: false
            )
            .map(\.id) == ["m1"])
        let sources = [IntentSource(id: sourceA, name: "Home", state: .loaded)]
        let reference = TitleReference(sourceID: sourceA, titleID: "m2")
        #expect(IntentLookup.title(reference, in: all, showsAdult: false, sources: sources) == .failure(.adultHidden))
        #expect((try? IntentLookup.title(reference, in: all, showsAdult: true, sources: sources).get())?.id == "m2")
    }

    @Test("adult-content/show-adult-content-with-the-passcode a profile that shows adult content sees every title")
    func shelfShown() {
        let index = ShelfIndex(
            catalogues: [ShelfCatalogue(titles: Self.titles(), categories: ["Drama", "XXX"])], showsAdult: true, now: .now)
        #expect(index.titles.count == 4)
        #expect(index.rows.map(\.id).contains(.category("XXX")))
        #expect(Self.titles().visible(showsAdult: false).map(\.id) == ["m1", "m4"])
        #expect(Self.titles().visible(showsAdult: true).count == 4)
    }
}
