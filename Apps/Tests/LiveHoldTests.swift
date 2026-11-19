import AntennaCore
import Foundation
import Testing

@testable import Antenna

/// The channel behind Movies, Series and Search on iPhone, iPad and Mac,
/// through the Live model both layouts read, on a scripted engine and a
/// clock the test moves.
@MainActor
@Suite(.serialized, .timeLimit(.minutes(1))) struct LiveHoldTests {
    let engine = PlayerTestEngine()
    let clock = SleepClock()
    let pictureInPicture = Broadcast(false)
    let airPlay = Broadcast(false)
    let live: LiveModel
    let channels = [
        Channel(id: "a", name: "A", streamURL: URL(fileURLWithPath: "/a.ts")),
        Channel(id: "b", name: "B", streamURL: URL(fileURLWithPath: "/b.ts")),
    ]

    init() async throws {
        let channels = channels
        let clock = clock
        let pictureInPicture = pictureInPicture
        let airPlay = airPlay
        var dependencies = LiveModel.Dependencies(
            engine: engine, load: { _ in Playlist(channels: channels) }, hasLogin: { _ in true }, guide: nil,
            programmes: UITestingLive.guide, network: .online)
        dependencies.sleep = { try await clock.sleep($0) }
        dependencies.pictureInPicture = PictureInPictureHooks(activity: { pictureInPicture.stream() }, stop: {})
        dependencies.airPlay = { airPlay.stream() }
        live = LiveModel(dependencies)
        live.sourcesChanged([SourceDescriptor(id: UUID(), name: "Home", kind: .m3u, url: URL(fileURLWithPath: "/home.m3u"))])
        await live.settled()
        Task { [live] in await live.observeEngine() }
        Task { [live] in await live.player.observePictureInPicture() }
        Task { [live] in await live.player.observeAirPlay() }
    }

    private func playing() async {
        live.pick(channels[0])
        #expect(await eventually { engine.state == .playing })
    }

    /// Opens `tab` as a layout does and waits for the change to finish.
    private func open(_ tab: LiveSession.Tab) async {
        live.opened(tab)
        await live.tabChange?.value
    }

    @Test(
        "live-tv-on-iphone-ipad-mac/the-channel-pauses-behind-movies-series-and-search Movies pauses, Live plays on with no reload"
    )
    func pauseBehindMovies() async {
        await playing()
        await open(.movies)
        #expect(engine.state == .paused, "no sound behind Movies")
        #expect(engine.pauses == 1)
        await clock.advance(by: .seconds(29))
        #expect(engine.state == .paused, "not stopped before 30 seconds")

        await open(.live)
        #expect(await eventually { engine.state == .playing })
        #expect(engine.loaded.count == 1, "playing on does not load the channel again")
    }

    @Test(
        "live-tv-on-iphone-ipad-mac/the-channel-pauses-behind-movies-series-and-search 30 seconds stop the stream, Live tunes again"
    )
    func stopBehindMovies() async {
        await playing()
        await open(.movies)
        await clock.advance(by: .seconds(30))
        #expect(await eventually { engine.state == .idle }, "the provider's connection is free")

        await open(.live)
        #expect(await eventually { engine.loaded.count == 2 })
        #expect(engine.loaded.last == channels[0].streamURL)
        #expect(await eventually { engine.state == .playing })
        #expect(live.playing == channels[0])
    }

    @Test(
        "live-tv-on-iphone-ipad-mac/the-channel-pauses-behind-movies-series-and-search 30 seconds run on across Series and Settings"
    )
    func stopAcrossTabs() async {
        await playing()
        await open(.movies)
        await clock.advance(by: .seconds(20))
        await open(.series)
        await open(.settings)
        #expect(engine.pauses == 1, "moving on pauses nothing more")
        #expect(engine.state == .paused, "Settings does not play the channel")
        await clock.advance(by: .seconds(10))
        #expect(await eventually { engine.state == .idle })

        await open(.guide)
        #expect(await eventually { engine.loaded.count == 2 })
        #expect(await eventually { engine.state == .playing })
    }

    @Test(
        "live-tv-on-iphone-ipad-mac/the-channel-pauses-behind-movies-series-and-search the Guide and Settings leave the channel playing"
    )
    func guideAndSettingsPlayOn() async {
        await playing()
        await open(.guide)
        await open(.settings)
        await open(.live)
        await clock.advance(by: .seconds(60))
        #expect(engine.pauses == 0)
        #expect(engine.state == .playing)
    }

    @Test(
        "live-tv-on-iphone-ipad-mac/the-channel-pauses-behind-movies-series-and-search a quick Live, Movies, Live keeps it playing"
    )
    func quickRoundTrip() async {
        await playing()
        live.opened(.movies)
        live.opened(.live)
        await live.tabChange?.value
        #expect(await eventually { engine.state == .playing })
        await clock.advance(by: .seconds(30))
        #expect(engine.state == .playing, "no stop after the round trip")
    }

    @Test(
        "live-tv-on-iphone-ipad-mac/the-channel-pauses-behind-movies-series-and-search a user's pause stays and is not stopped"
    )
    func userPauseStands() async {
        await playing()
        live.playPause()
        #expect(await eventually { engine.state == .paused })
        await open(.movies)
        #expect(engine.pauses == 1, "the hold pauses nothing more")
        await clock.advance(by: .seconds(30))
        #expect(engine.state == .paused)
        let plays = engine.plays
        await open(.live)
        await clock.settle()
        #expect(engine.plays == plays)
        #expect(engine.state == .paused)
    }

    @Test(
        "live-tv-on-iphone-ipad-mac/the-channel-pauses-behind-movies-series-and-search a load that lands behind Search stays paused"
    )
    func loadLandsBehindSearch() async {
        let gate = LoadGate()
        engine.loadGate = { await gate.wait() }
        live.pick(channels[1])
        #expect(await eventually { engine.loaded.count == 1 })
        await open(.search)
        gate.release()
        await clock.settle()
        #expect(await eventually { engine.state == .loading })
        await clock.settle()
        #expect(engine.plays == 0, "no sound starts behind Search")

        await open(.live)
        #expect(await eventually { engine.state == .playing })
        #expect(engine.loaded.count == 1)
    }

    @Test(
        "live-tv-on-iphone-ipad-mac/the-channel-pauses-behind-movies-series-and-search a channel picked in Search plays on Live"
    )
    func pickFromSearch() async {
        await playing()
        await open(.search)
        live.pick(channels[1])
        await open(.live)
        #expect(await eventually { engine.state == .playing })
        #expect(engine.loaded == [channels[0].streamURL, channels[1].streamURL], "loaded once")
        await clock.advance(by: .seconds(30))
        #expect(engine.state == .playing, "the earlier hold does not stop it")
    }

    @Test(
        "live-tv-on-iphone-ipad-mac/the-channel-pauses-behind-movies-series-and-search Picture in Picture keeps playing behind Movies"
    )
    func pictureInPicturePlaysOn() async {
        await playing()
        pictureInPicture.send(true)
        #expect(await eventually { live.player.pictureInPictureActive })
        await open(.movies)
        await clock.advance(by: .seconds(30))
        #expect(engine.pauses == 0)
        #expect(engine.state == .playing, "neither paused nor stopped")
        await open(.live)
        #expect(engine.state == .playing)
    }

    @Test(
        "live-tv-on-iphone-ipad-mac/the-channel-pauses-behind-movies-series-and-search Picture in Picture brought back on Movies pauses"
    )
    func pictureInPictureRestoredBehindMovies() async {
        await playing()
        pictureInPicture.send(true)
        #expect(await eventually { live.player.pictureInPictureActive })
        await open(.movies)
        #expect(engine.state == .playing)

        pictureInPicture.send(false)
        #expect(await eventually { engine.state == .paused }, "as if Movies had just opened")
        await open(.live)
        #expect(await eventually { engine.state == .playing })
        #expect(engine.loaded.count == 1)
    }

    @Test(
        "live-tv-on-iphone-ipad-mac/the-channel-pauses-behind-movies-series-and-search AirPlay keeps playing behind Movies"
    )
    func airPlayPlaysOn() async {
        await playing()
        airPlay.send(true)
        #expect(await eventually { live.player.airPlayActive })
        await open(.movies)
        await clock.advance(by: .seconds(30))
        #expect(engine.pauses == 0)
        #expect(engine.state == .playing)
    }

    @Test(
        "live-tv-on-iphone-ipad-mac/the-channel-pauses-behind-movies-series-and-search the hold leaves full screen"
    )
    func fullScreenEnds() async {
        await playing()
        live.setFullScreen(true)
        await open(.series)
        #expect(!live.fullScreen)
        #expect(engine.state == .paused)
    }

    @Test(
        "live-tv-on-iphone-ipad-mac/the-channel-pauses-behind-movies-series-and-search a movie's stop leaves the tune to Live"
    )
    func movieStoppedPausedChannel() async {
        await playing()
        await open(.movies)
        await live.suspend()
        await open(.live)
        live.appeared()
        #expect(await eventually { engine.loaded.count == 2 })
        #expect(await eventually { engine.state == .playing })
        await clock.advance(by: .seconds(30))
        #expect(engine.state == .playing)
        #expect(engine.loaded.count == 2, "tuned once")
    }
}

/// Holds every load until released.
@MainActor
final class LoadGate {
    private var open = false
    private var waiting: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        guard !open else { return }
        await withCheckedContinuation { waiting.append($0) }
    }

    func release() {
        open = true
        waiting.forEach { $0.resume() }
        waiting = []
    }
}
