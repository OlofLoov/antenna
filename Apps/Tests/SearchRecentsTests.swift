import AntennaCore
import Foundation
import SwiftData
import Testing

@testable import Antenna

/// Recent searches as Search reads and writes them through the activity
/// store, against an in-memory container.
@MainActor
@Suite struct SearchRecentsTests {
    let container: ModelContainer

    init() throws {
        let schema = Schema(AntennaSchema.models)
        container = try ModelContainer(
            for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none))
    }

    @Test("search/recent-searches the ten latest picked searches, newest first, case-only differences listed once")
    func tenNewest() async throws {
        let store = ActivityStore(context: container.mainContext)
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let queries = (1...11).map { "search \($0)" } + ["SEARCH 11", "Arsenal"]
        for (offset, query) in queries.enumerated() {
            store.recordSearch(query, now: start.addingTimeInterval(Double(offset)))
        }
        let activity = ShelfActivity()
        let following = Task { await activity.follow(store) }
        defer { following.cancel() }
        while activity.searches.isEmpty { await Task.yield() }

        #expect(activity.searches.count == 10)
        #expect(activity.searches.first == "Arsenal")
        #expect(activity.searches.dropFirst().first == "SEARCH 11", "the latest spelling wins")
        #expect(!activity.searches.contains("search 11"))
        #expect(activity.searches.last == "search 3")
    }

    @Test("search/recent-searches picking a result remembers the query")
    func recordOnPick() async throws {
        let activity = ShelfActivity()
        let following = Task { await activity.follow(ActivityStore(context: container.mainContext)) }
        defer { following.cancel() }
        let model = SearchModel(.init(debounce: .zero, sleep: { _ in }, now: { .now }))
        let channel = Channel(id: "a", name: "Arena", streamURL: URL(filePath: "/a"), sourceID: nil)
        let source = UUID()
        let tagged = Channel.tagged([channel], sourceID: source)
        await model.load(
            SearchCorpus(
                catalogue: Catalogue(channels: tagged, groupOrder: [:], favorites: []), sourceOrder: [source: 0], guide: GuideIndex(),
                titles: [], hasTitles: false, sources: .loaded))
        var played: [String] = []
        let feed = SearchFeed(
            model: model, channel: { key in tagged.first { RowKey($0) == key } }, onNow: { _, _ in nil },
            picks: SearchPicks(channel: { played.append($0.name) }, programme: { _, _ in }, title: { _ in }),
            remember: { activity.recordSearch($0) }, text: SearchText())
        model.run("  Arena  ")
        try feed.pick(#require(model.results.channels.first))

        #expect(played == ["Arena"])
        #expect(activity.searches == ["Arena"], "kept tidy")
        model.run("zzz")
        #expect(activity.searches == ["Arena"], "a search without a pick is not kept")
    }
}
