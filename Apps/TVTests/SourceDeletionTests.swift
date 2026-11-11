import AntennaCore
import Foundation
import Testing

@testable import AntennaTV

/// Deleting a source on Apple TV, against a scripted loader and a recording engine.
@MainActor
@Suite(.timeLimit(.minutes(1))) struct SourceDeletionTests {
    let engine = RecordingEngine()
    let loader = ScriptedLoader()
    let clock = ManualClock()
    let defaults: UserDefaults
    let model: ShellModel

    let sourceA = SourceDescriptor(name: "A", kind: .m3u, url: URL(fileURLWithPath: "/a.m3u"))
    let sourceB = SourceDescriptor(name: "B", kind: .xtream, url: URL(fileURLWithPath: "/b"))

    init() throws {
        defaults = try #require(UserDefaults(suiteName: "source-deletion-tests-\(UUID().uuidString)"))
        let loader = loader
        let clock = clock
        model = ShellModel(
            .init(
                engine: engine, load: { try await loader.load($0) }, hasLogin: { _ in true }, recents: RecentsStore(defaults: defaults),
                sleep: { try await clock.sleep($0) }, guide: nil))
    }

    private func wait(_ condition: () -> Bool, _ comment: Comment? = nil) async {
        for _ in 0..<5000 {
            if condition() { return }
            await Task.yield()
        }
        Issue.record(comment ?? "timed out")
    }

    @Test("session-restore-and-recently-watched/deleting-a-source-clears-its-channels a deleted source's channel is not tuned at launch")
    func launchSkipsDeleted() async {
        let store = RecentsStore(defaults: defaults)
        store.write(LastChannelKey(sourceID: sourceB.id, channelID: "fixture/b2"))
        model.sourcesChanged([sourceA, sourceB])
        await wait({ loader.isWaiting(sourceA.id) && loader.isWaiting(sourceB.id) }, "both sources loading")

        // Deleted on another device: the store goes first, then the record.
        RecentsStore.remove(source: sourceB.id, from: defaults)
        model.sourceDeleted(sourceB.id)
        model.sourcesChanged([sourceA])
        #expect(store.read() == nil)

        loader.finish(sourceA.id, with: [.fixture("a1")])
        await wait({ engine.loaded.last == Channel.fixture("a1").streamURL }, "first channel of A tuned")
    }
}
