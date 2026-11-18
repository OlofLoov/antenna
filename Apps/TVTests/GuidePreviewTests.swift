import AntennaCore
import Foundation
import Testing

@testable import AntennaTV

/// The Guide's small picture following the highlighted row, against a
/// recording engine and a clock the test moves.
@MainActor
@Suite(.timeLimit(.minutes(1))) struct GuidePreviewTests {
    let engine = RecordingEngine()
    let loader = ScriptedLoader()
    let clock = ManualClock()
    let recents: RecentsStore
    let model: ShellModel
    let source = SourceDescriptor(name: "A", kind: .m3u, url: URL(fileURLWithPath: "/a.m3u"))

    init() throws {
        let defaults = try #require(UserDefaults(suiteName: "guide-preview-\(UUID().uuidString)"))
        let loader = loader
        let clock = clock
        recents = RecentsStore(defaults: defaults)
        model = ShellModel(
            .init(
                engine: engine, load: { try await loader.load($0) }, hasLogin: { _ in true },
                recents: recents, sleep: { try await clock.sleep($0) }, guide: nil))
    }

    private func wait(_ condition: () -> Bool, _ comment: Comment? = nil) async {
        for _ in 0..<5000 {
            if condition() { return }
            await Task.yield()
        }
        Issue.record(comment ?? "timed out")
    }

    /// a1 plays and the Guide is open.
    private func inTheGuide() async {
        model.sourcesChanged([source])
        await wait { loader.isWaiting(source.id) }
        loader.finish(source.id, with: [.fixture("a1"), .fixture("a2"), .fixture("a3")])
        await wait { engine.plays > 0 }
        _ = await model.select(.guide)
    }

    private var files: [String] { engine.loaded.map(\.lastPathComponent) }

    private func rest(on index: Int) async {
        let pending = clock.pending
        model.guideHighlightMoved(to: model.channels[index])
        await wait { clock.pending > pending }
        clock.advance(by: ShellModel.guideRestDelay)
    }

    @Test("tv-guide-grid/the-small-picture-follows-the-highlight the picture tunes the row the highlight rests on")
    func followsTheHighlight() async {
        await inTheGuide()
        let pending = clock.pending
        model.guideHighlightMoved(to: model.channels[1])
        await wait { clock.pending > pending }
        clock.advance(by: .milliseconds(600))
        await Task.yield()
        #expect(files == ["a1.ts"], "nothing tunes before the highlight rests")
        clock.advance(by: .milliseconds(100))
        await wait { files == ["a1.ts", "a2.ts"] }
        #expect(model.tuned == model.channels[1])
        #expect(recents.read() == LastChannelKey(model.channels[0]), "the picture's channel is not stored as the last one")
    }

    @Test("tv-guide-grid/the-small-picture-follows-the-highlight scrolling past rows tunes only the one it stops on")
    func scrollingPast() async {
        await inTheGuide()
        model.guideHighlightMoved(to: model.channels[1])
        model.guideHighlightMoved(to: model.channels[2])
        await rest(on: 2)
        await wait { files.count == 2 }
        #expect(files == ["a1.ts", "a3.ts"])
    }

    @Test("tv-guide-grid/the-small-picture-follows-the-highlight moving along the same row does not tune again")
    func sameRow() async {
        await inTheGuide()
        await rest(on: 1)
        await wait { files.count == 2 }
        let requested = clock.requested.count
        model.guideHighlightMoved(to: model.channels[1])
        await Task.yield()
        #expect(clock.requested.count == requested, "no new wait for the same row")
        #expect(files == ["a1.ts", "a2.ts"])
    }

    @Test("tv-guide-grid/the-small-picture-follows-the-highlight leaving the guide goes back to what played before")
    func leavingGoesBack() async {
        await inTheGuide()
        await rest(on: 1)
        await wait { files.count == 2 }
        _ = await model.select(.live)
        await wait { files.count == 3 }
        #expect(files.last == "a1.ts")
        #expect(model.tuned == model.channels[0])
        #expect(model.tab == .live)
    }

    @Test("tv-guide-grid/the-small-picture-follows-the-highlight leaving for Movies tunes back and holds that channel")
    func leavingForMovies() async {
        await inTheGuide()
        await rest(on: 1)
        await wait { files.count == 2 }
        _ = await model.select(.movies)
        await wait { files.count == 3 }
        #expect(files.last == "a1.ts")
        #expect(model.tuned == model.channels[0])
        #expect(model.pausedByShell, "the channel waits behind Movies")
        #expect(recents.read() == LastChannelKey(model.channels[0]))
    }

    @Test("tv-guide-grid/the-small-picture-follows-the-highlight watch keeps the channel in the picture without a reload")
    func watchKeeps() async {
        await inTheGuide()
        await rest(on: 1)
        await wait { files.count == 2 }
        await model.pickFromOverlay(model.channels[1])
        #expect(files == ["a1.ts", "a2.ts"], "no reload")
        #expect(model.tuned == model.channels[1])
        #expect(model.tab == .live)
        #expect(model.guidePicks == 1, "the info bar shows")
        #expect(recents.read() == LastChannelKey(model.channels[1]))
    }

    @Test("tv-guide-grid/the-small-picture-follows-the-highlight back on the first row leaves nothing to tune on the way out")
    func backToTheFirstRow() async {
        await inTheGuide()
        await rest(on: 1)
        await wait { files.count == 2 }
        await rest(on: 0)
        await wait { files.count == 3 }
        _ = await model.select(.live)
        #expect(files == ["a1.ts", "a2.ts", "a1.ts"])
        #expect(model.tuned == model.channels[0])
    }
}
