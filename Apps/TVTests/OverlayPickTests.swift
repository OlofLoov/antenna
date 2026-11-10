import AntennaCore
import Foundation
import Testing

@testable import AntennaTV

/// Select and Watch in the channel overlay, against a recording engine.
@MainActor
@Suite(.timeLimit(.minutes(1))) struct OverlayPickTests {
    let engine = RecordingEngine()
    let loader = ScriptedLoader()
    let clock = ManualClock()
    let model: ShellModel
    let source = SourceDescriptor(name: "A", kind: .m3u, url: URL(fileURLWithPath: "/a.m3u"))

    init() throws {
        let defaults = try #require(UserDefaults(suiteName: "overlay-pick-\(UUID().uuidString)"))
        let loader = loader
        let clock = clock
        model = ShellModel(
            .init(
                engine: engine, load: { try await loader.load($0) }, hasLogin: { _ in true },
                lastChannel: LastChannelStore(defaults: defaults), sleep: { try await clock.sleep($0) }, guide: nil))
    }

    private func wait(_ condition: () -> Bool, _ comment: Comment? = nil) async {
        for _ in 0..<5000 {
            if condition() { return }
            await Task.yield()
        }
        Issue.record(comment ?? "timed out")
    }

    private func playing() async -> Channel? {
        model.sourcesChanged([source])
        await wait { loader.isWaiting(source.id) }
        loader.finish(source.id, with: [.fixture("a1"), .fixture("a2")])
        await wait { engine.plays > 0 }
        return model.tuned
    }

    @Test("tv-channel-overlay/select-changes-channel another channel tunes and the overlay closes")
    func anotherChannel() async throws {
        _ = await playing()
        model.openPicker()
        await model.pickFromOverlay(model.channels[1])
        await wait { engine.loaded.count == 2 }
        #expect(model.tuned == model.channels[1])
        #expect(!model.pickerOpen)
        #expect(model.tab == .live)
    }

    @Test("tv-channel-overlay/select-on-the-playing-channel-does-not-restart-it the playing channel carries on")
    func playingCarriesOn() async throws {
        let tuned = try #require(await playing())
        await engine.play()
        let plays = engine.plays
        model.openPicker()
        await model.pickFromOverlay(tuned)
        #expect(engine.loaded.count == 1, "no reload")
        #expect(engine.plays == plays, "no play call")
        #expect(engine.pauses == 0)
        #expect(!model.pickerOpen)
    }

    @Test("tv-channel-overlay/select-on-the-playing-channel-does-not-restart-it a paused stream resumes once")
    func pausedResumes() async throws {
        let tuned = try #require(await playing())
        await engine.pause()
        let plays = engine.plays
        model.openPicker()
        await model.pickFromOverlay(tuned)
        #expect(engine.plays == plays + 1)
        #expect(engine.loaded.count == 1)
        #expect(engine.state == .playing)
    }

    @Test("tv-channel-overlay/select-on-the-playing-channel-does-not-restart-it a failed or stopped stream loads again once")
    func failedReloads() async throws {
        let tuned = try #require(await playing())
        await engine.stop()
        model.openPicker()
        await model.pickFromOverlay(tuned)
        await wait { engine.loaded.count == 2 }
        await settle()
        #expect(engine.loaded.count == 2, "one load, not two")
        #expect(!model.pickerOpen)
    }

    private func settle() async {
        for _ in 0..<200 { await Task.yield() }
    }
}
