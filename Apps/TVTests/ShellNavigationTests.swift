import AntennaCore
import Foundation
import Testing

@testable import AntennaTV

/// The tvos-shell capability, what other screens and the bar ask of the shell, and the
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
                recents: RecentsStore(defaults: defaults),
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

    @Test("tvos-shell/the-video-pauses-behind-movies-series-and-search Live from the bar over a tab resumes without a reload")
    func liveFromBarResumes() async {
        await playing()
        _ = await model.select(.movies)
        #expect(engine.pauses == 1)
        let plays = engine.plays

        let focus = await model.select(.live)
        #expect(focus == .picture)
        #expect(model.tab == .live)
        #expect(model.liveInFront)
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
    }

    // tvos-shell/channel-list-over-the-picture
    @Test("tvos-shell/other-screens-can-send-the-user-somewhere the navigator shows Live full screen after a tune")
    func navigatorShowsLive() async {
        await playing()
        model.openPicker()
        await model.pick(model.channels[1])
        #expect(model.tab == .live)
        #expect(!model.pickerOpen)
        #expect(model.liveInFront)
        await wait { engine.loaded.count == 2 }

        _ = await model.select(.search)
        model.navigator.showLive()
        await wait { model.tab == .live }
    }

    @Test("tvos-shell/an-empty-screen-with-retry Retry loads again only the sources that added nothing")
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

    @Test("tvos-shell/a-loading-screen-at-launch a source waiting for its login loads when the app comes back")
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

    @Test("tvos-shell/menu-shows-the-tab-bar-over-the-picture the picture dims while the highlight is in the bar over Live and the Guide")
    func dimUnderTheBar() async {
        await playing()
        model.barFocused = true
        #expect(model.dimmed)
        #expect(!model.liveInFront)
        model.barFocused = false
        #expect(!model.dimmed)
        #expect(model.liveInFront)

        _ = await model.select(.guide)
        model.barFocused = true
        #expect(model.dimmed)
        _ = await model.select(.movies)
        #expect(!model.dimmed, "Movies hides the picture, so there is nothing to dim")
    }

    @Test("tvos-shell/open-settings Settings is the last tab and leaves the video alone")
    func settingsTab() async {
        await playing()
        #expect(model.tabs.last == .settings)
        let plays = engine.plays
        _ = await model.select(.settings)
        #expect(model.tab == .settings)
        #expect(engine.pauses == 0)
        #expect(engine.state == .playing)

        _ = await model.select(.live)
        #expect(engine.plays == plays)
        #expect(engine.loaded.count == 1)
    }

    // The system tab bar opens every tab the highlight passes, so reaching Settings
    // from Live goes through Movies, Series and Search. Settings sits over the
    // picture and ends their pause.
    @Test("tvos-shell/open-settings Settings opened from Movies resumes the channel without a reload")
    func settingsEndsTheHold() async {
        await playing()
        _ = await model.select(.movies)
        #expect(engine.state == .paused)
        _ = await model.select(.settings)
        #expect(engine.pauses == 1)
        #expect(engine.state == .playing, "Settings plays the channel behind it")
        #expect(model.heldByShell == nil)

        _ = await model.select(.live)
        #expect(engine.state == .playing)
        #expect(engine.loaded.count == 1)
    }

    @Test("tvos-shell/back-to-full-screen-from-the-tab-bar the bar changes tab at once and the video follows in order")
    func chooseQueues() async {
        await playing()
        model.choose(.guide)
        model.choose(.movies)
        model.choose(.live)
        #expect(model.tab == .live, "the page changes before the video does")
        await model.tabChange?.value
        await wait { engine.state == .playing }
        #expect(engine.loaded.count == 1)
    }

    @Test("tvos-shell/back-to-full-screen-from-the-tab-bar selecting Live over the dimmed Guide loads a failed stream again")
    func liveFromGuideRetriesFailedStream() async {
        engine.failLoads = true
        model.sourcesChanged([source])
        await wait { loader.isWaiting(source.id) }
        loader.finish(source.id, with: [.fixture("a1")])
        await wait { engine.loaded.count == 1 }
        _ = await model.select(.guide)
        model.barFocused = true
        #expect(model.dimmed)

        _ = await model.select(.live)
        await wait { engine.loaded.count == 2 }
    }

    @Test("tv-guide-grid/the-channel-keeps-playing-in-a-small-picture opening the Guide resumes a paused stream without a reload")
    func guideResumesPausedStream() async {
        await playing()
        await engine.pause()
        let plays = engine.plays
        #expect(await model.select(.guide) == nil)
        #expect(engine.plays == plays + 1)
        #expect(engine.loaded.count == 1)
        #expect(engine.state == .playing)

        // A playing stream is left alone.
        _ = await model.select(.guide)
        #expect(engine.plays == plays + 1)
    }

    @Test("tvos-shell/a-loading-screen-at-launch Live shows the loading screen, not the empty one, before the sources are read")
    func noEmptyFlash() {
        #expect(model.liveScreen == .loading)
        model.sourcesChanged([])
        #expect(model.liveScreen == .empty)
    }
}
