import AntennaCore
import Foundation
import Testing

/// Saved references resolved against what loaded, and what Shortcuts suggests.
@Suite struct IntentLookupTests {
    typealias TestCatalogue = Catalogue<Int>

    let cabin = UUID()
    let attic = UUID()

    private func channel(_ id: String, group: String? = nil, number: Int) -> Channel {
        Channel(id: id, name: id.capitalized, streamURL: URL(filePath: "/\(id)"), group: group, number: number)
    }

    private func catalogue(favorites: [String] = [], rules: GroupRules = GroupRules()) -> TestCatalogue {
        let channels = [
            channel("news", group: "Info", number: 1), channel("sport", group: "Sport", number: 2),
            channel("kids", group: "Kids", number: 3), channel("extra", group: "Extra", number: 4),
        ]
        let snapshots = zip(favorites.indices, favorites).map { FavoriteSnapshot<Int>(channelID: $1, sourceID: cabin, sortOrder: $0) }
        return TestCatalogue(channels: Channel.tagged(channels, sourceID: cabin), groupOrder: [:], favorites: snapshots, rules: rules)
    }

    private func sources(_ state: IntentSource.State = .loaded) -> [IntentSource] {
        [IntentSource(id: cabin, name: "Cabin", state: .loaded), IntentSource(id: attic, name: "Attic", state: state)]
    }

    @Test("app-intents/tune-a-channel-by-voice-or-shortcut a saved reference finds its channel")
    func found() throws {
        let result = IntentLookup.channel(LastChannelKey(sourceID: cabin, channelID: "sport"), in: catalogue(), sources: sources())
        #expect(try result.get().name == "Sport")
    }

    @Test(
        "app-intents/a-clear-reply-when-a-channel-or-title-cannot-play each reason a channel is out of reach",
        arguments: [
            (IntentSource.State.loading, IntentFailure.stillLoading), (.offline, .offline), (.failed, .sourceFailed(source: "Attic")),
            (.waitingForLogin, .loginMissing(source: "Attic")), (.loaded, .channelGone(channel: nil, source: "Attic")),
        ])
    func unreachable(_ state: IntentSource.State, _ failure: IntentFailure) {
        let result = IntentLookup.channel(LastChannelKey(sourceID: attic, channelID: "x"), in: catalogue(), sources: sources(state))
        #expect(result == .failure(failure))
    }

    @Test("app-intents/a-clear-reply-when-a-channel-or-title-cannot-play a source deleted and added again is gone")
    func sourceGone() {
        let result = IntentLookup.channel(LastChannelKey(sourceID: UUID(), channelID: "news"), in: catalogue(), sources: sources())
        #expect(result == .failure(.channelSourceGone))
    }

    @Test("app-intents/a-clear-reply-when-a-channel-or-title-cannot-play a locked channel says so and plays once unlocked")
    func locked() throws {
        var rules = GroupRules(locked: [.named(cabin, "Kids")])
        let key = LastChannelKey(sourceID: cabin, channelID: "kids")
        #expect(IntentLookup.channel(key, in: catalogue(rules: rules), sources: sources()) == .failure(.locked(channel: "Kids")))
        rules.locksOpen = true
        #expect(try IntentLookup.channel(key, in: catalogue(rules: rules), sources: sources()).get().name == "Kids")
    }

    @Test("app-intents/a-clear-reply-when-a-channel-or-title-cannot-play an item that comes back plays again")
    func comesBack() throws {
        let key = LastChannelKey(sourceID: attic, channelID: "late")
        #expect(IntentLookup.channel(key, in: catalogue(), sources: sources(.waitingForLogin)) == .failure(.loginMissing(source: "Attic")))
        let back = TestCatalogue(
            channels: Channel.tagged([channel("late", number: 9)], sourceID: attic), groupOrder: [:], favorites: [])
        #expect(try IntentLookup.channel(key, in: back, sources: sources()).get().name == "Late")
    }

    @Test("app-intents/a-clear-reply-when-a-channel-or-title-cannot-play titles fail the same way")
    func titles() throws {
        let movie = ShelfTitle(id: "xtream#h#vod#1", kind: .movie, sourceID: attic, name: "Harbor")
        let reference = TitleReference(movie)
        #expect(try IntentLookup.title(reference, in: [movie], sources: sources()).get() == movie)
        #expect(IntentLookup.title(reference, in: [], sources: sources()) == .failure(.titleGone(title: nil, source: "Attic")))
        #expect(IntentLookup.title(reference, in: [], sources: sources(.loading)) == .failure(.stillLoading))
        #expect(IntentLookup.title(reference, in: [movie], sources: []) == .failure(.titleSourceGone))
    }

    @Test("app-intents/shortcuts-suggests-what-you-watch favorites first, then other channels, locked and hidden left out")
    func channelSuggestions() {
        let rules = GroupRules(hidden: [.named(cabin, "Extra")], locked: [.named(cabin, "Kids")])
        let list = catalogue(favorites: ["sport", "kids", "extra"], rules: rules)
        let names = IntentLookup.suggestedChannels(in: list).compactMap { list.channel(for: $0)?.id }
        #expect(names == ["sport", "news"])
        #expect(IntentLookup.suggestedChannels(in: catalogue(), limit: 2).count == 2)
    }

    @Test("app-intents/shortcuts-suggests-what-you-watch titles in progress, then My list, each once and only when loaded")
    func titleSuggestions() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let titles = (1...4).map { ShelfTitle(id: "xtream#h#vod#\($0)", kind: .movie, sourceID: cabin, name: "Movie \($0)") }
        let progress = [
            WatchProgress(id: "a", titleID: titles[2].id, sourceID: cabin, position: 10, duration: 100, updatedAt: now),
            WatchProgress(id: "b", titleID: "xtream#h#vod#99", sourceID: cabin, position: 10, duration: 100, updatedAt: now),
        ]
        let list = [titles[0].activityKey, titles[2].activityKey, ActivityKey(titleID: "xtream#h#vod#77", sourceID: cabin)]
        let suggested = IntentLookup.suggestedTitles(progress: progress, myList: list, titles: titles)
        #expect(suggested.map(\.name) == ["Movie 3", "Movie 1"])
        #expect(IntentLookup.suggestedTitles(progress: progress, myList: list, titles: titles, limit: 1).map(\.name) == ["Movie 3"])
    }
}
