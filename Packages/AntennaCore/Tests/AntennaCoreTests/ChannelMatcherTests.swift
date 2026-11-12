import AntennaCore
import Foundation
import Testing

/// Finding a channel the way Siri and Shortcuts ask for one.
@Suite struct ChannelMatcherTests {
    typealias TestCatalogue = Catalogue<Int>

    let cabin = UUID()
    let attic = UUID()

    private func channel(_ id: String, _ name: String, number: Int? = nil, group: String? = nil) -> Channel {
        Channel(id: id, name: name, streamURL: URL(filePath: "/\(id)"), group: group, number: number)
    }

    private func catalogue(_ first: [Channel], _ second: [Channel] = [], rules: GroupRules = GroupRules()) -> TestCatalogue {
        TestCatalogue(
            channels: Channel.tagged(first, sourceID: cabin) + Channel.tagged(second, sourceID: attic), groupOrder: [:], favorites: [],
            rules: rules)
    }

    private func names(_ catalogue: TestCatalogue, _ query: String, limit: Int = 20) -> [String] {
        catalogue.channels(matching: query, limit: limit).compactMap { catalogue.channel(for: $0)?.name }
    }

    @Test("app-intents/ask-for-a-channel-by-name-or-number case and accents are ignored")
    func caseAndAccents() {
        let list = catalogue([channel("1", "Música Uno", number: 1), channel("2", "Café TV", number: 2)])
        #expect(names(list, "MUSICA") == ["Música Uno"])
        #expect(names(list, "cafe tv") == ["Café TV"])
        #expect(names(list, "café") == ["Café TV"])
    }

    @Test("app-intents/ask-for-a-channel-by-name-or-number a single exact name is used alone")
    func exactName() {
        let list = catalogue([
            channel("1", "News", number: 1), channel("2", "News Extra", number: 2), channel("3", "World News", number: 3),
        ])
        #expect(names(list, "news") == ["News"])
        #expect(names(list, "  NEWS  ") == ["News"])
    }

    @Test("app-intents/ask-for-a-channel-by-name-or-number names rank as Search ranks them")
    func bands() {
        let list = catalogue([
            channel("1", "The Sports Hub", number: 1), channel("2", "Allsports", number: 2), channel("3", "Sports Two", number: 3),
            channel("4", "Sports One", number: 4),
        ])
        #expect(names(list, "sports") == ["Sports One", "Sports Two", "The Sports Hub", "Allsports"])
    }

    @Test("app-intents/ask-for-a-channel-by-name-or-number a number finds numbers, not names")
    func numbers() {
        let list = catalogue([
            channel("1", "Channel 24", number: 7), channel("2", "Seven", number: 24), channel("3", "Two", number: 240),
            channel("4", "Three", number: 25),
        ])
        #expect(names(list, "24") == ["Seven"])
        #expect(names(list, "024") == ["Seven"])
        #expect(names(list, "2") == ["Seven", "Three", "Two"])
        #expect(names(list, "000").isEmpty)
        #expect(names(list, "9").isEmpty)
    }

    @Test("app-intents/ask-for-a-channel-by-name-or-number group names never match")
    func groupsDoNotMatch() {
        let list = catalogue([channel("1", "Arena", number: 1, group: "Football")])
        #expect(names(list, "football").isEmpty)
    }

    @Test("app-intents/ask-for-a-channel-by-name-or-number nothing matches a blank or unknown query")
    func noMatch() {
        let list = catalogue([channel("1", "Arena", number: 1)])
        #expect(names(list, "").isEmpty)
        #expect(names(list, "   ").isEmpty)
        #expect(names(list, "zebra").isEmpty)
    }

    @Test("app-intents/siri-asks-which-when-two-channels-match two Sport Ones are both offered, by number then source")
    func ties() {
        let list = catalogue([channel("a", "Sport One", number: 9)], [channel("b", "Sport One", number: 3), channel("c", "Sport One HD")])
        let rows = list.channels(matching: "sport one", limit: 20)
        #expect(rows.map(\.sourceID) == [attic, cabin])
        let same = catalogue([channel("a", "Alpha", number: 5)], [channel("b", "Beta", number: 5)])
        #expect(same.channels(matching: "5", limit: 20).map(\.sourceID) == [cabin, attic])
    }

    @Test("app-intents/ask-for-a-channel-by-name-or-number matches stop at the limit")
    func limit() {
        let list = catalogue((0..<50).map { channel("\($0)", "News \($0)", number: $0 + 1) })
        #expect(list.channels(matching: "news", limit: 20).count == 20)
        #expect(list.channels(matching: "1", limit: 3).count == 1)
        #expect(list.channels(matching: "news", limit: 0).isEmpty)
    }

    @Test("app-intents/a-clear-reply-when-a-channel-or-title-cannot-play locked channels are not matched while locked")
    func lockedLeftOut() {
        let group = CatalogueGroup.named(cabin, "Kids")
        let rules = GroupRules(locked: [group])
        let list = catalogue(
            [channel("1", "Cartoon Time", number: 1, group: "Kids"), channel("2", "Cartoon News", number: 2)], rules: rules)
        #expect(names(list, "cartoon") == ["Cartoon News"])
        var open = rules
        open.locksOpen = true
        #expect(names(catalogue([channel("1", "Cartoon Time", number: 1, group: "Kids")], rules: open), "cartoon") == ["Cartoon Time"])
    }

    @Test("app-intents/ask-for-a-channel-by-name-or-number a channel of a hidden group can still be named")
    func hiddenStillFound() {
        let rules = GroupRules(hidden: [.named(cabin, "Extra")])
        let list = catalogue([channel("1", "Arena", number: 1, group: "Extra")], rules: rules)
        #expect(names(list, "arena") == ["Arena"])
    }

    @Test("app-intents/tune-a-channel-by-voice-or-shortcut a reference finds its channel by source and id, new name and all")
    func lookup() {
        let renamed = catalogue([channel("x", "Sport One Renamed", number: 1)], [channel("x", "Other", number: 2)])
        #expect(renamed.channel(for: LastChannelKey(sourceID: cabin, channelID: "x"))?.name == "Sport One Renamed")
        #expect(renamed.channel(for: LastChannelKey(sourceID: attic, channelID: "x"))?.name == "Other")
        #expect(renamed.channel(for: LastChannelKey(sourceID: cabin, channelID: "y")) == nil)
        let twice = catalogue([channel("x", "One", number: 1), channel("x", "Two", number: 2)])
        #expect(twice.channel(for: LastChannelKey(sourceID: cabin, channelID: "x")) == nil)
    }
}
