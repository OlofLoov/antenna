import AntennaCore
import Foundation
import Testing

@testable import Antenna

/// The movie and episode transport: skips, drags, slides on Apple TV and
/// when the controls hide, over a scripted engine.
@MainActor
@Suite struct TitleTransportTests {
    let engine = ScriptedEngine()

    /// A transport whose seeks land on the scripted engine, with a short hold.
    private func transport(hold: Duration = .milliseconds(80)) -> (TitleTransport, Task<Void, Never>) {
        let engine = engine
        let transport = TitleTransport(
            .init(
                engine: engine,
                seek: { time in
                    do {
                        try await engine.seek(to: time)
                        return true
                    } catch {
                        return false
                    }
                }, hold: hold))
        let follow = Task { await transport.follow() }
        return (transport, follow)
    }

    private func playing(at seconds: Int, _ transport: TitleTransport) async {
        try? await engine.load(URL(fileURLWithPath: "/film.mp4"), options: PlaybackOptions())
        await engine.play()
        engine.send(position: seconds)
        _ = await eventually { transport.position.time == .seconds(seconds) && transport.state == .playing }
    }

    @Test("player-controls-and-playback-errors/move-around-in-a-movie-or-episode skips show the new time before the engine reports it")
    func skips() async {
        let (transport, follow) = transport()
        defer { follow.cancel() }
        await playing(at: 600, transport)
        transport.skip(forward: false)
        #expect(transport.times.elapsed == "9:50")
        transport.skip(forward: false)
        #expect(transport.times.elapsed == "9:40")
        #expect(await eventually { engine.seeks == [.seconds(590), .seconds(580)] })
        #expect(await eventually { transport.pending == nil })
    }

    @Test("player-controls-and-playback-errors/move-around-in-a-movie-or-episode a server that cannot skip is named before a press")
    func cannotSkipUpFront() async {
        let (transport, follow) = transport(hold: .seconds(60))
        defer { follow.cancel() }
        try? await engine.load(URL(fileURLWithPath: "/film.mkv"), options: PlaybackOptions())
        await engine.play()
        engine.send(position: 600, canSkip: false)
        #expect(await eventually { !transport.canSkip })
        #expect(transport.notice == TitleTransport.cannotSkip, "said while the controls show, before any press")
        transport.skip(forward: true)
        transport.drag(to: 0.5)
        #expect(!transport.isScrubbing)
        try? await Task.sleep(for: .milliseconds(100))
        #expect(engine.seeks.isEmpty, "nothing is asked of the engine")
        #expect(transport.times.elapsed == "10:00")
        transport.hide()
        #expect(await eventually { transport.notice == nil }, "it goes with the controls")
    }

    @Test("player-controls-and-playback-errors/move-around-in-a-movie-or-episode a drag moves the time shown and seeks once")
    func drag() async {
        let (transport, follow) = transport()
        defer { follow.cancel() }
        await playing(at: 600, transport)
        transport.drag(to: 0.25)
        transport.drag(to: 0.5)
        #expect(transport.times.elapsed == "45:00")
        #expect(transport.times.remaining == "-45:00")
        #expect(engine.seeks.isEmpty, "the picture stays put while dragging")
        transport.endDrag()
        #expect(await eventually { engine.seeks == [.seconds(2700)] })
        #expect(engine.state == .playing)
    }

    @Test("player-controls-and-playback-errors/move-around-in-a-movie-or-episode a slide while paused moves a target, select plays from it")
    func slide() async {
        let (transport, follow) = transport()
        defer { follow.cancel() }
        await playing(at: 600, transport)
        transport.beginSlide()
        transport.slide(by: 0.5)
        #expect(!transport.isScrubbing, "a slide while playing only shows the bar")
        transport.endSlide()

        await engine.pause()
        #expect(await eventually { transport.isPaused })
        transport.beginSlide()
        transport.slide(by: 0.4)
        transport.endSlide()
        // An eighth of 90 minutes is 675 seconds; 0.4 of it is 270.
        #expect(transport.target == .seconds(870))
        transport.nudge(forward: true)
        #expect(transport.target == .seconds(880), "a click moves the target 10 seconds")
        transport.beginSlide()
        transport.slide(by: -0.2)
        #expect(transport.target == .seconds(745), "the next slide starts from the target")
        transport.endSlide()
        transport.commit()
        #expect(await eventually { engine.seeks == [.seconds(745)] && engine.state == .playing })
        #expect(!transport.isScrubbing)
    }

    @Test("player-controls-and-playback-errors/move-around-in-a-movie-or-episode Menu puts the target back and the title stays paused")
    func cancel() async {
        let (transport, follow) = transport()
        defer { follow.cancel() }
        await playing(at: 600, transport)
        await engine.pause()
        #expect(await eventually { transport.isPaused })
        transport.beginSlide()
        transport.slide(by: 1)
        transport.endSlide()
        transport.cancelScrub()
        #expect(!transport.isScrubbing)
        #expect(transport.times.elapsed == "10:00")
        try? await Task.sleep(for: .milliseconds(50))
        #expect(engine.seeks.isEmpty)
        #expect(engine.state == .paused)
    }

    @Test("player-controls-and-playback-errors/the-movie-controls-show-and-hide they hide while playing, stay while paused or held")
    func showAndHide() async {
        let (transport, follow) = transport()
        defer { follow.cancel() }
        await playing(at: 600, transport)
        #expect(transport.controlsShown, "they show when the title starts")
        #expect(await eventually { !transport.controlsShown })

        transport.toggle()
        #expect(transport.controlsShown)
        transport.toggle()
        #expect(!transport.controlsShown, "a second tap hides them")

        await engine.pause()
        transport.show(after: .touch)
        #expect(await eventually { transport.isPaused })
        try? await Task.sleep(for: .milliseconds(200))
        #expect(transport.controlsShown, "they stay while paused")

        await engine.play()
        transport.held = true
        try? await Task.sleep(for: .milliseconds(200))
        #expect(transport.controlsShown, "they stay while held")
        transport.held = false
        #expect(await eventually { !transport.controlsShown })
    }
}
