import Foundation
import Testing

@testable import AntennaCore

@Suite struct RecentChannelsTests {
    private func key(_ id: String, _ source: UUID = sourceA) -> LastChannelKey {
        LastChannelKey(sourceID: source, channelID: id)
    }

    @Test("session-restore-and-recently-watched/recents-keep-the-newest-first-each-channel-once a full list moves up and drops the oldest")
    func fullList() {
        var list = RecentChannels((0..<20).map { key("c\($0)") })
        #expect(list.entries.count == 20)
        list.record(key("c5"))
        #expect(list.entries.first == key("c5"))
        #expect(list.entries.count == 20)
        #expect(list.entries.filter { $0 == key("c5") }.count == 1)
        list.record(key("new"))
        #expect(list.entries.first == key("new"))
        #expect(list.entries.count == 20)
        #expect(!list.entries.contains(key("c19")), "the oldest falls off")
        #expect(list.entries[1] == key("c5"))
    }

    @Test("session-restore-and-recently-watched/recents-keep-the-newest-first-each-channel-once the same id in two sources is two channels")
    func sameIDTwoSources() {
        var list = RecentChannels()
        list.record(key("x", sourceA))
        list.record(key("x", sourceB))
        #expect(list.entries == [key("x", sourceB), key("x", sourceA)])
    }

    @Test("session-restore-and-recently-watched/recents-keep-the-newest-first-each-channel-once unreadable data gives empty recents")
    func damaged() {
        #expect(RecentChannels(data: Data("not json".utf8)).entries.isEmpty)
        #expect(RecentChannels(data: nil).entries.isEmpty)
        #expect(LiveSession(data: Data("{".utf8)) == LiveSession())
        let tooMany = (0..<30).map { key("c\($0)") } + [key("c1")]
        let stored = try? JSONEncoder().encode(tooMany)
        let list = RecentChannels(data: stored)
        #expect(list.entries.count == 20)
        #expect(list.entries == (0..<20).map { key("c\($0)") })
    }

    @Test("session-restore-and-recently-watched/recents-keep-the-newest-first-each-channel-once the list survives a round trip")
    func roundTrip() {
        var list = RecentChannels()
        list.record(key("a"))
        list.record(key("b"))
        #expect(RecentChannels(data: list.data) == list)
    }

    @Test("session-restore-and-recently-watched/links-with-passwords-are-never-stored an id with a stream link is not listed or saved")
    func streamLink() {
        let m3u = Channel.tagged(
            [Channel(id: "http://host/user/pass/1.ts", name: "One", streamURL: URL(fileURLWithPath: "/1"))], sourceID: sourceA)[0]
        let xtream = Channel.tagged([Channel(id: "xtream:7", name: "Seven", streamURL: URL(fileURLWithPath: "/7"))], sourceID: sourceB)[0]
        #expect(LastChannelKey(m3u) == nil)
        #expect(LastChannelKey(xtream) == key("xtream:7", sourceB))
        var list = RecentChannels([key("http://host/user/pass/1.ts")])
        #expect(list.entries.isEmpty)
        list.record(key("http://host/user/pass/1.ts"))
        #expect(list.entries.isEmpty)
        list.record(key("xtream:7", sourceB))
        #expect(list.entries == [key("xtream:7", sourceB)])
    }

    @Test("session-restore-and-recently-watched/deleting-a-source-clears-its-channels a source's channels and group go, others stay")
    func removeSource() {
        var list = RecentChannels([key("a1", sourceA), key("b1", sourceB), key("a2", sourceA)])
        list.remove(source: sourceA)
        #expect(list.entries == [key("b1", sourceB)])
        var session = LiveSession(tab: .guide, group: .named(sourceA, "News"))
        session.remove(source: sourceB)
        #expect(session.group?.group == .named(sourceA, "News"))
        session.remove(source: sourceA)
        #expect(session.group == nil)
        #expect(session.tab == .guide)
    }

    @Test("session-restore-and-recently-watched/reopen-on-the-same-tab-and-group every group kind survives a round trip")
    func sessionGroups() {
        for group: CatalogueGroup in [.favorites, .recents, .all, .named(sourceA, "Sport "), .ungrouped(sourceB)] {
            let session = LiveSession(tab: .live, group: group)
            #expect(LiveSession(data: session.data).group?.group == group)
        }
    }
}
