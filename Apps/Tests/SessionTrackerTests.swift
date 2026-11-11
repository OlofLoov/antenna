import AntennaCore
import Foundation
import Testing

@testable import Antenna

/// The ten-second count and the last channel, driven through `LiveModel`
/// as the app drives them, with a hand-moved clock.
@MainActor
@Suite struct SessionTrackerTests {
    private let suite = "session-tracker-tests-\(UUID().uuidString)"
    private let source = UUID()

    private struct Harness {
        let model: LiveModel
        let engine: PlayerTestEngine
        let clock: SleepClock
        let store: RecentsStore
    }

    private func harness() -> Harness {
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        let store = RecentsStore(defaults: defaults)
        let engine = PlayerTestEngine()
        let clock = SleepClock()
        let model = LiveModel(
            .init(
                engine: engine, load: { _ in Playlist(channels: []) }, hasLogin: { _ in true }, programmes: UITestingLive.guide,
                recents: store, sleep: { try await clock.sleep($0) }))
        return Harness(model: model, engine: engine, clock: clock, store: store)
    }

    private func channel(_ id: String) -> Channel {
        Channel.tagged([Channel(id: id, name: id, streamURL: URL(fileURLWithPath: "/\(id).ts"))], sourceID: source)[0]
    }

    private func key(_ id: String) -> LastChannelKey { LastChannelKey(sourceID: source, channelID: id) }

    /// Tunes `channel` and lets the engine report playing.
    private func play(_ channel: Channel, _ model: LiveModel, _ clock: SleepClock) async {
        model.pick(channel)
        await clock.settle()
        model.session.stateChanged(.playing)
        await clock.settle()
    }

    @Test("session-restore-and-recently-watched/a-channel-counts-as-watched-after-ten-seconds ten seconds of play counts")
    func tenSeconds() async {
        let rig = harness()
        await play(channel("one"), rig.model, rig.clock)
        #expect(rig.store.read() == key("one"), "the loaded stream is the last channel")
        await rig.clock.advance(by: .seconds(9))
        #expect(rig.store.recents.entries.isEmpty)
        await rig.clock.advance(by: .seconds(1))
        #expect(rig.store.recents.entries == [key("one")])
    }

    @Test("session-restore-and-recently-watched/a-channel-counts-as-watched-after-ten-seconds switching channel early does not count")
    func switchChannel() async {
        let rig = harness()
        await play(channel("one"), rig.model, rig.clock)
        await rig.clock.advance(by: .seconds(8))
        await play(channel("two"), rig.model, rig.clock)
        await rig.clock.advance(by: .seconds(8))
        #expect(rig.store.recents.entries.isEmpty)
        await rig.clock.advance(by: .seconds(2))
        #expect(rig.store.recents.entries == [key("two")])
    }

    @Test("session-restore-and-recently-watched/a-channel-counts-as-watched-after-ten-seconds a stall starts the count again from zero")
    func stall() async {
        let rig = harness()
        await play(channel("one"), rig.model, rig.clock)
        await rig.clock.advance(by: .seconds(6))
        rig.model.session.stateChanged(.buffering)
        await rig.clock.advance(by: .seconds(6))
        #expect(rig.store.recents.entries.isEmpty)
        rig.model.session.stateChanged(.playing)
        await rig.clock.advance(by: .seconds(9))
        #expect(rig.store.recents.entries.isEmpty)
        await rig.clock.advance(by: .seconds(1))
        #expect(rig.store.recents.entries == [key("one")])
    }

    @Test("session-restore-and-recently-watched/a-channel-counts-as-watched-after-ten-seconds a movie starting stops the count")
    func movie() async {
        let rig = harness()
        await play(channel("one"), rig.model, rig.clock)
        await rig.clock.advance(by: .seconds(5))
        await rig.model.suspend()
        await rig.clock.advance(by: .seconds(10))
        #expect(rig.store.recents.entries.isEmpty)
    }

    @Test("session-restore-and-recently-watched/a-channel-counts-as-watched-after-ten-seconds leaving the app restarts the count")
    func leaveApp() async {
        let rig = harness()
        await play(channel("one"), rig.model, rig.clock)
        await rig.clock.advance(by: .seconds(5))
        rig.model.session.interrupt()
        await rig.clock.advance(by: .seconds(10))
        #expect(rig.store.recents.entries.isEmpty)
        rig.model.session.stateChanged(.playing)
        await rig.clock.advance(by: .seconds(10))
        #expect(rig.store.recents.entries == [key("one")])
    }

    @Test("tvos-shell/back-to-the-last-channel-on-launch a stream that fails to load leaves the last channel as it was")
    func failedLoad() async {
        let rig = harness()
        await play(channel("one"), rig.model, rig.clock)
        rig.engine.failNextLoad = .unreachable
        rig.model.pick(channel("two"))
        await rig.clock.settle()
        #expect(rig.store.read() == key("one"))
    }

    @Test("session-restore-and-recently-watched/links-with-passwords-are-never-stored an M3U id with its link is not kept")
    func streamLink() async {
        let rig = harness()
        await play(channel("http://host/u/p/1.ts"), rig.model, rig.clock)
        await rig.clock.advance(by: .seconds(10))
        #expect(rig.store.read() == nil)
        #expect(rig.store.recents.entries.isEmpty)
    }
}
