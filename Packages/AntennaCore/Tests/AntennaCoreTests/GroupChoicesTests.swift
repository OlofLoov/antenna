import Foundation
import Testing

@testable import AntennaCore

@Suite struct GroupChoicesTests {
    static let seNews = CatalogueGroup.named(sourceA, "SE | NEWS")
    static let seSport = CatalogueGroup.named(sourceA, "SE | SPORT")
    static let ukSports = CatalogueGroup.named(sourceA, "UK ▸ SPORTS HD")
    static let ppv = CatalogueGroup.named(sourceB, "Sport PPV")
    static let cafe = CatalogueGroup.named(sourceB, "Café Télé")

    /// Source A: SE | NEWS, SE | SPORT, UK ▸ SPORTS HD. Source B: Sport PPV, Café Télé.
    static func build(_ rules: GroupRules = GroupRules()) -> TestCatalogue {
        let channels =
            Channel.tagged(
                [
                    channel("a0", group: "SE | NEWS", number: 1), channel("a1", group: "SE | SPORT", number: 2),
                    channel("a2", group: "SE | SPORT", number: 3), channel("a3", group: "UK ▸ SPORTS HD", number: 4),
                ], sourceID: sourceA)
            + Channel.tagged(
                [channel("b0", group: "Sport PPV", number: 5), channel("b1", group: "Café Télé", number: 6)], sourceID: sourceB)
        return TestCatalogue(channels: channels, groupOrder: [:], favorites: [], rules: rules)
    }

    static func choices(_ catalogue: TestCatalogue, _ query: String, locale: Locale = Locale(identifier: "en")) -> GroupChoices {
        GroupChoices(catalogue, query: query) { catalogue.customName(of: $0) ?? $0.label(locale) }
    }

    @Test("live-tv-on-iphone-ipad-mac/find-a-group-among-many a blank query lists every group, built-in ones first")
    func blank() {
        let catalogue = Self.build()
        let choices = Self.choices(catalogue, "  ")
        #expect(choices.builtIn.map(\.group) == [.favorites, .all])
        #expect(choices.groups.map(\.group) == [Self.seNews, Self.seSport, Self.ukSports, Self.ppv, Self.cafe])
        #expect((choices.builtIn + choices.groups).compactMap(\.index) == Array(catalogue.groups.indices))
        #expect(choices.locked.isEmpty)
        #expect(!choices.isEmpty)
    }

    @Test("live-tv-on-iphone-ipad-mac/find-a-group-among-many typing part of a provider's name keeps order and indexes")
    func partOfAName() {
        let catalogue = Self.build()
        let choices = Self.choices(catalogue, "sport")
        #expect(choices.builtIn.isEmpty)
        #expect(choices.groups.map(\.group) == [Self.seSport, Self.ukSports, Self.ppv])
        #expect(choices.groups.map(\.index) == [3, 4, 5])
        #expect(Self.choices(catalogue, "se sport").groups.map(\.group) == [Self.seSport])
    }

    @Test("live-tv-on-iphone-ipad-mac/find-a-group-among-many case and accents are ignored")
    func caseAndAccents() {
        #expect(Self.choices(Self.build(), "CAFE tele").groups.map(\.group) == [Self.cafe])
    }

    @Test("live-tv-on-iphone-ipad-mac/find-a-group-among-many built-in groups match by their name in the app's language")
    func builtInNames() {
        let catalogue = Self.build()
        #expect(Self.choices(catalogue, "favor", locale: Locale(identifier: "sv")).builtIn.map(\.group) == [.favorites])
        #expect(Self.choices(catalogue, "alla", locale: Locale(identifier: "sv")).builtIn.map(\.group) == [.all])
        #expect(Self.choices(catalogue, "alla", locale: Locale(identifier: "en")).builtIn.isEmpty)
    }

    @Test("live-tv-on-iphone-ipad-mac/find-a-group-among-many a renamed group matches by its new name")
    func renamed() {
        let catalogue = Self.build(GroupRules(names: [Self.seNews: "Nyheter"]))
        #expect(Self.choices(catalogue, "nyheter").groups.map(\.group) == [Self.seNews])
        #expect(Self.choices(catalogue, "news").groups.isEmpty)
    }

    @Test("live-tv-on-iphone-ipad-mac/pick-a-group hidden groups are left out and locked ones come last with no index")
    func hiddenAndLocked() {
        let catalogue = Self.build(GroupRules(hidden: [Self.seNews], locked: [Self.ppv]))
        let choices = Self.choices(catalogue, "")
        #expect(!(choices.builtIn + choices.groups + choices.locked).map(\.group).contains(Self.seNews))
        #expect(choices.locked == [GroupChoices.Choice(group: Self.ppv, index: nil)])
        #expect(Self.choices(catalogue, "ppv").locked.map(\.group) == [Self.ppv])
        #expect(Self.choices(catalogue, "news").isEmpty)
    }

    @Test("live-tv-on-iphone-ipad-mac/find-a-group-among-many hundreds of groups filter quickly")
    func hundreds() {
        let channels = (0..<600).map { channel("m\($0)", group: String(format: "UK ▸ GROUP %03d", $0 / 2), number: $0 + 1) }
        let catalogue = TestCatalogue(channels: Channel.tagged(channels, sourceID: sourceA), groupOrder: [:], favorites: [])
        let start = ContinuousClock.now
        let choices = Self.choices(catalogue, "group 137")
        if Benchmarks.enabled { #expect(ContinuousClock.now - start < .milliseconds(200)) }
        #expect(choices.groups.map(\.group) == [.named(sourceA, "UK ▸ GROUP 137")])
    }
}
