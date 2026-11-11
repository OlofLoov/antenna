import AntennaCore
import Foundation
import Testing

@testable import Antenna

/// The on-device store for recents, the session and the last channel.
@MainActor
@Suite struct RecentsStoreTests {
    let defaults: UserDefaults
    let deleted = UUID()
    let kept = UUID()
    let kids = UUID()

    init() throws {
        defaults = try #require(UserDefaults(suiteName: "recents-store-tests-\(UUID().uuidString)"))
    }

    private func key(_ id: String, _ source: UUID) -> LastChannelKey { LastChannelKey(sourceID: source, channelID: id) }

    private func fill(_ store: RecentsStore) {
        store.record(key("d1", deleted))
        store.record(key("k1", kept))
        store.write(key("d1", deleted))
        store.write(LiveSession(tab: .guide, group: .named(deleted, "News")))
    }

    @Test("session-restore-and-recently-watched/deleting-a-source-clears-its-channels every profile loses the source and keeps the rest")
    func deleteSource() {
        let main = RecentsStore(defaults: defaults)
        let other = RecentsStore(defaults: defaults, profile: kids)
        fill(main)
        fill(other)
        RecentsStore.remove(source: deleted, from: defaults)
        for store in [main, other] {
            #expect(store.recents.entries == [key("k1", kept)])
            #expect(store.read() == nil)
            #expect(store.session.group == nil)
            #expect(store.session.tab == .guide)
        }
    }

    @Test("session-restore-and-recently-watched/deleting-a-source-clears-its-channels another source's last channel stays")
    func otherSourceStays() {
        let store = RecentsStore(defaults: defaults)
        store.write(key("k1", kept))
        RecentsStore.remove(source: deleted, from: defaults)
        #expect(store.read() == key("k1", kept))
    }

    @Test("session-restore-and-recently-watched/recents-keep-the-newest-first-each-channel-once unreadable stored values read as nothing")
    func damaged() {
        let store = RecentsStore(defaults: defaults)
        defaults.set(Data("x".utf8), forKey: RecentsStore.listKey)
        defaults.set(Data("x".utf8), forKey: RecentsStore.sessionKey)
        defaults.set(Data("x".utf8), forKey: RecentsStore.lastChannelKey)
        #expect(store.recents.entries.isEmpty)
        #expect(store.session == LiveSession())
        #expect(store.read() == nil)
    }

    @Test(
        "session-restore-and-recently-watched/a-channel-counts-as-watched-after-ten-seconds a deleted source stops the count"
    )
    func deletedWhilePlaying() async {
        let clock = SleepClock()
        let tracker = SessionTracker(store: RecentsStore(defaults: defaults), sleep: { try await clock.sleep($0) })
        let channel = Channel.tagged([Channel(id: "d1", name: "D", streamURL: URL(fileURLWithPath: "/d1.ts"))], sourceID: deleted)[0]
        tracker.tuned(channel)
        tracker.stateChanged(.playing)
        await clock.advance(by: .seconds(5))
        tracker.remove(source: deleted)
        tracker.stateChanged(.playing)
        await clock.advance(by: .seconds(20))
        #expect(RecentsStore(defaults: defaults).recents.entries.isEmpty)
    }
}
