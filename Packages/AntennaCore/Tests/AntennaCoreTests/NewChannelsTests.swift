import Foundation
import Testing

@testable import AntennaCore

/// The New group and what the device remembers to build it.
@Suite struct NewChannelsTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func days(_ count: Double) -> Date {
        now.addingTimeInterval(-count * 86_400)
    }

    private func catalogue(_ ids: [String], names: [String: String] = [:], groups: [String: String] = [:]) -> TestCatalogue {
        let channels = ids.enumerated().map { offset, id in
            channel(id, group: groups[id] ?? "News", number: offset + 1, name: names[id] ?? id)
        }
        return TestCatalogue(channels: Channel.tagged(channels, sourceID: sourceA), groupOrder: [:], favorites: [])
    }

    @Test("new-channels/a-new-group-lists-channels-added-lately a refresh with three new channels lists them, newest first, after Recents")
    func added() {
        let yesterday = SeenChannels(firstLoad: (1...400).map { "c\($0)" }, now: days(1))
        var memory = SeenChannels.recording(yesterday, channelIDs: (1...401).map { "c\($0)" }, now: days(0.5))
        memory = SeenChannels.recording(memory, channelIDs: (1...403).map { "c\($0)" }, now: now)
        let ids = (1...403).map { "c\($0)" }
        let shown = NewChannels.group(catalogue(ids), seen: [sourceA: memory], now: now)
            .replacingRecents([LastChannelKey(sourceID: sourceA, channelID: "c5")])
        #expect(Array(shown.groups.prefix(4)) == [.favorites, .recents, .new, .all])
        #expect(shown.rows(in: .new).map(\.id) == ["c402", "c403", "c401"], "newest first, then catalogue order")
        #expect(shown.count(of: .new) == 3)
        #expect(shown.position(of: shown.rows(in: .new)[0], in: .new)! == (1, 3))
        #expect(shown.memberCount(of: .new) == 3)
        #expect(!shown.groups.dropFirst(4).contains(.new))
    }

    @Test("new-channels/a-new-group-lists-channels-added-lately a channel first seen eight days ago is no longer new")
    func aWeekLater() {
        let first = SeenChannels(firstLoad: ["a"], now: days(20))
        let memory = SeenChannels.recording(first, channelIDs: ["a", "b"], now: days(8))
        let shown = NewChannels.group(catalogue(["a", "b"]), seen: [sourceA: memory], now: now)
        #expect(shown.rows(in: .new).isEmpty)
        #expect(!shown.groups.contains(.new))
        #expect(shown.fallbackGroup == .all)
    }

    @Test("new-channels/a-new-group-lists-channels-added-lately the group survives other replacements and rules")
    func keptAcrossReplacements() {
        let memory = SeenChannels.recording(SeenChannels(firstLoad: ["a"], now: days(2)), channelIDs: ["a", "b"], now: days(1))
        let shown = NewChannels.group(catalogue(["a", "b"]), seen: [sourceA: memory], now: now)
            .replacingFavorites([])
            .replacingRules(GroupRules(hidden: [.new]))
        #expect(shown.rows(in: .new).map(\.id) == ["b"], "New is never hidden")
        #expect(CatalogueGroup(storageKey: CatalogueGroup.new.storageKey) == .new)
        #expect(LiveSession.Group(.new).group == .new)
    }

    @Test("new-channels/a-new-source-starts-with-nothing-new the first load counts every channel as known")
    func firstLoad() {
        let ids = (1...1_200).map { "c\($0)" }
        let memory = SeenChannels.recording(nil, channelIDs: ids, now: now)
        let shown = NewChannels.group(catalogue(ids), seen: [sourceA: memory], now: now)
        #expect(!shown.groups.contains(.new))
        let next = SeenChannels.recording(memory, channelIDs: ids, now: now.addingTimeInterval(3_600))
        #expect(NewChannels.group(catalogue(ids), seen: [sourceA: next], now: now).rows(in: .new).isEmpty)
        #expect(NewChannels.group(catalogue(ids), seen: [:], now: now).rows(in: .new).isEmpty, "no memory adds nothing")
    }

    @Test("new-channels/what-new-remembers-stays-on-the-device the memory holds no link or login, and forgets after 30 days")
    func nothingSecret() throws {
        let id = "http://alice:hunter2@example.com/live/alice/hunter2/42.ts"
        let memory = SeenChannels.recording(SeenChannels(firstLoad: [], now: days(1)), channelIDs: [id], now: now)
        let data = try JSONEncoder().encode(memory)
        let text = try #require(String(data: data, encoding: .utf8))
        for secret in ["alice", "hunter2", "example", "http", "42.ts"] { #expect(!text.contains(secret)) }
        let back = try JSONDecoder().decode(SeenChannels.self, from: data)
        #expect(back == memory)
        #expect(back.firstSeen(id) == now)

        let later = SeenChannels.recording(back, channelIDs: ["other"], now: now.addingTimeInterval(31 * 86_400))
        #expect(later.firstSeen(id) == nil, "gone for 30 days")
        #expect(later.firstSeen("other") != nil)
    }

    @Test("new-channels/renamed-and-moved-channels-are-not-new a new name, group or number keeps the channel known")
    func renamed() {
        let memory = SeenChannels.recording(SeenChannels(firstLoad: ["a", "b"], now: days(3)), channelIDs: ["b", "a"], now: now)
        let moved = catalogue(["b", "a"], names: ["a": "Renamed"], groups: ["a": "Sport"])
        #expect(NewChannels.group(moved, seen: [sourceA: memory], now: now).rows(in: .new).isEmpty)
    }
}
