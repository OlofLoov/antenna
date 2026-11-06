import AntennaCore
import Foundation
import Testing

@testable import AntennaTV

/// Spec 0015, what other screens and the bar ask of the shell, and the
/// sources that load again on Retry or in the foreground.
@MainActor
@Suite(.timeLimit(.minutes(1))) struct ShellNavigationTests {
    let engine = RecordingEngine()
    let loader = ScriptedLoader()
    let clock = ManualClock()
    let logins = Logins()
    let model: ShellModel

    let source = SourceDescriptor(name: "A", kind: .m3u, url: URL(fileURLWithPath: "/a.m3u"))
    let xtream = SourceDescriptor(name: "X", kind: .xtream, url: URL(fileURLWithPath: "/x"), credentialKey: "x")

    /// Which sources have a login on this device.
    @MainActor
    final class Logins {
        var missing: Set<UUID> = []
    }

    init() throws {
        let defaults = try #require(UserDefaults(suiteName: "shell-nav-\(UUID().uuidString)"))
        let loader = loader
        let clock = clock
        let logins = logins
        model = ShellModel(
            .init(
                engine: engine,
                load: { try await loader.load($0) },
                hasLogin: { !logins.missing.contains($0.id) },
                lastChannel: LastChannelStore(defaults: defaults),
                sleep: { try await clock.sleep($0) },
                guide: nil))
    }

    private func wait(_ condition: () -> Bool, _ comment: Comment? = nil) async {
        for _ in 0..<5000 {
            if condition() { return }
            await Task.yield()
        }
        Issue.record(comment ?? "timed out")
    }

    private func settle() async {
        for _ in 0..<200 { await Task.yield() }
    }

    private func playing() async {
        model.sourcesChanged([source])
        await wait { loader.isWaiting(source.id) }
        loader.finish(source.id, with: [.fixture("a1"), .fixture("a2")])
        await wait { engine.plays > 0 }
    }

    @Test("tvos-shell/menu-from-the-tab-bar-goes-back-to-live Menu from the bar over a paused tab resumes Live without a reload")
    func menuFromBarResumes() async {
        await playing()
        _ = await model.select(.movies)
        await wait { clock.requested.last == .seconds(30) }
        clock.advance(by: .seconds(30))
        await wait { engine.pauses == 1 }
        let plays = engine.plays

        _ = await model.menu(from: .content)
        let focus = await model.menu(from: .bar)
        #expect(focus == .picture)
        #expect(model.tab == .live)
        #expect(!model.barVisible)
        #expect(engine.plays == plays + 1)
        #expect(engine.loaded.count == 1)
    }

    @Test("tvos-shell/other-screens-can-send-the-user-somewhere the navigator opens Search and the Guide at a programme")
    func navigatorShows() async {
        await playing()
        _ = await model.select(.movies)
        let navigator = model.navigator

        navigator.show(.search)
        await wait { model.tab == .search }

        model.openPicker()
        let key = ProgrammeKey(guideKey: GuideKey(sourceID: source.id, epgID: "news"), start: Date(timeIntervalSince1970: 0))
        navigator.show(.guide(programmeKey: key))
        await wait { model.tab == .guide }
        #expect(model.guideRequest == key)
        #expect(!model.pickerOpen, "a request from the overlay closes it")
        #expect(!model.barVisible)
    }

    @Test("tvos-shell/other-screens-can-send-the-user-somewhere the navigator shows Live full screen after a tune")
    func navigatorShowsLive() async {
        await playing()
        model.openPicker()
        await model.pick(model.channels[1])
        #expect(model.tab == .live)
        #expect(!model.pickerOpen)
        #expect(!model.barVisible)
        await wait { engine.loaded.count == 2 }

        _ = await model.select(.search)
        model.navigator.showLive()
        await wait { model.tab == .live }
        #expect(!model.barVisible)
    }

    @Test("Retry loads again only the sources that added nothing")
    func retry() async {
        model.sourcesChanged([source, xtream])
        await wait { loader.isWaiting(source.id) && loader.isWaiting(xtream.id) }
        loader.finish(source.id, with: [])
        loader.fail(xtream.id, with: URLError(.notConnectedToInternet))
        await wait { model.liveScreen == .empty }
        #expect(model.sources.map(\.state) == [.loaded(channels: 0), .offline])

        model.retry()
        #expect(model.liveScreen == .loading)
        await wait { loader.calls.count == 4 }
    }

    @Test("a source waiting for its login loads when the app comes back")
    func loginArrives() async {
        logins.missing = [xtream.id]
        model.sourcesChanged([xtream])
        await wait { model.sources.first?.state == .waitingForLogin }
        #expect(loader.calls.isEmpty)

        await model.becameActive()
        #expect(loader.calls.isEmpty, "still no login")

        logins.missing = []
        await model.becameActive()
        await wait { loader.isWaiting(xtream.id) }
        #expect(model.liveScreen == .loading)
    }

    @Test("swipe down lowers the bar only over Live and Guide")
    func swipeDown() async {
        await playing()
        _ = await model.menu(from: .picture)
        #expect(model.dimmed)
        #expect(model.swipeDown() == .picture)
        #expect(!model.barVisible)

        _ = await model.select(.movies)
        #expect(model.swipeDown() == nil)
        #expect(model.barVisible)
    }

    @Test("tvos-shell/back-to-full-screen-from-the-tab-bar selecting Live over the dimmed Guide loads a failed stream again")
    func liveFromGuideRetriesFailedStream() async {
        engine.failLoads = true
        model.sourcesChanged([source])
        await wait { loader.isWaiting(source.id) }
        loader.finish(source.id, with: [.fixture("a1")])
        await wait { engine.loaded.count == 1 }
        _ = await model.select(.guide)
        _ = await model.menu(from: .content)
        #expect(model.dimmed)

        _ = await model.select(.live)
        await wait { engine.loaded.count == 2 }
        #expect(!model.barVisible)
    }

    @Test("Live shows the loading screen, not the empty one, before the sources are read")
    func noEmptyFlash() {
        #expect(model.liveScreen == .loading)
        model.sourcesChanged([])
        #expect(model.liveScreen == .empty)
    }
}
