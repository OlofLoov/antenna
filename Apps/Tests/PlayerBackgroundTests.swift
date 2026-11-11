import AntennaCore
import Foundation
import Testing

@testable import Antenna

/// Picture in Picture, background sound and the lock screen around Live,
/// on scripted engines and sinks. What only a device shows (the Home
/// gesture, a real call, the lock screen itself) is left to device tests.
@MainActor
@Suite struct PlayerBackgroundTests {
    let engine = PlayerTestEngine()

    // MARK: Picture in Picture

    @Test("player-controls-and-playback-errors/picture-in-picture-on-iphone-and-ipad the player area knows the window is open")
    func windowState() async {
        let (stream, continuation) = AsyncStream.makeStream(of: Bool.self)
        let player = PlayerModel(
            .init(
                engine: engine, network: .online, log: PlayerLog { _ in },
                pictureInPicture: PictureInPictureHooks(activity: { stream }, stop: {})))
        let task = Task { await player.observePictureInPicture() }
        continuation.yield(true)
        #expect(await eventually { player.pictureInPictureActive })
        continuation.yield(false)
        #expect(await eventually { !player.pictureInPictureActive })
        task.cancel()
        continuation.finish()
    }

    @Test("player-controls-and-playback-errors/picture-in-picture-on-iphone-and-ipad giving up closes the window for the error")
    func givingUpClosesTheWindow() {
        let stops = Counter()
        let player = PlayerModel(
            .init(
                engine: engine, network: .online, log: PlayerLog { _ in },
                pictureInPicture: PictureInPictureHooks(activity: { AsyncStream { $0.yield(true) } }, stop: { stops.value += 1 })))
        let channel = Channel(id: "news", name: "News", streamURL: URL(fileURLWithPath: "/news.ts"))
        player.tuned(PlayerSubject(channel: channel, source: "Home", number: 1))
        player.stateChanged(.reconnecting(attempt: 3, of: 3))

        player.stateChanged(.failed(.stoppedSendingData))

        #expect(stops.value == 1)
        #expect(player.failure == .stoppedSendingData, "the error shows in the app")
    }

    #if os(iOS)
        @Test("player-controls-and-playback-errors/picture-in-picture-on-iphone-and-ipad closing the window pauses, restoring plays on")
        func closeAndRestore() async {
            let watch = PictureInPictureWatch(engine: engine)
            await engine.play()
            watch.started()

            watch.restoringApp()
            watch.stopped()
            await Task.yield()
            #expect(engine.pauses == 0, "restoring the app plays on with no reload")
            #expect(engine.loaded.isEmpty)

            watch.started()
            watch.stopped()
            #expect(await eventually { engine.pauses == 1 }, "closing the window pauses")
        }
    #endif

    // MARK: Background sound

    @Test("player-controls-and-playback-errors/keep-listening-in-the-background leaving the app keeps the sound")
    func leavingKeepsPlaying() async {
        let lifecycle = PlaybackLifecycle(engine: engine, continuesInBackground: { true }, pausesInBackground: true)
        await engine.play()

        await lifecycle.enteredBackground()

        #expect(engine.state == .playing)
        #expect(engine.pauses == 0)
    }

    @Test("player-controls-and-playback-errors/keep-listening-in-the-background a call pauses and its end resumes when allowed")
    func callPausesAndResumes() async {
        let lifecycle = PlaybackLifecycle(engine: engine, continuesInBackground: { true }, pausesInBackground: true)
        await engine.play()
        await lifecycle.enteredBackground()

        await lifecycle.handle(.began)
        #expect(engine.state == .paused)
        await lifecycle.handle(.ended(shouldResume: true))
        #expect(engine.state == .playing)

        await lifecycle.handle(.began)
        await lifecycle.handle(.ended(shouldResume: false))
        #expect(engine.state == .paused, "the system said not to resume")
    }
}

#if os(iOS) || os(macOS)
    /// What Live sends to the lock screen and Control Center.
    @MainActor
    @Suite struct LiveNowPlayingTests {
        let engine = PlayerTestEngine()
        let published = Published()
        let live: LiveModel
        static let secretURL =
            URL(string: "http://olof77:hunter2pw@panel.acme-iptv.example:8080/live/olof77/hunter2pw/104.ts") ?? URL(fileURLWithPath: "/")

        @MainActor
        final class Published {
            var infos: [NowPlayingInfo?] = []
            var play: (@MainActor () -> Void)?
            var pause: (@MainActor () -> Void)?
        }

        init() async {
            let published = published
            let channels = [
                Channel(id: "news-one", name: "News One", streamURL: Self.secretURL, number: 104),
                Channel(id: "kids-one", name: "Kids One", streamURL: URL(fileURLWithPath: "/kids-one.ts")),
            ]
            var dependencies = LiveModel.Dependencies(
                engine: engine, load: { _ in Playlist(channels: channels) }, hasLogin: { _ in true }, guide: nil,
                programmes: Self.guide, network: .online)
            dependencies.nowPlaying = NowPlayingSink(
                publish: { published.infos.append($0) },
                listen: { play, pause in
                    published.play = play
                    published.pause = pause
                })
            dependencies.nowPlayingInterval = .milliseconds(20)
            dependencies.pictureInPicture = .none
            live = LiveModel(dependencies)
            live.sourcesChanged([SourceDescriptor(id: UUID(), name: "Home", kind: .m3u, url: URL(fileURLWithPath: "/home.m3u"))])
            await live.settled()
        }

        /// News One has Morning News from 0 to 1800 seconds after the
        /// reference date and Weather after it; Kids One has no guide.
        static let start = Date(timeIntervalSinceReferenceDate: 0)
        static var guide: OverlayGuide {
            OverlayGuide(
                state: { _ in .loaded },
                current: { channel, date in programmes(channel).first { $0.start <= date && date < $0.stop } },
                next: { channel, date, count in Array(programmes(channel).filter { $0.start >= date }.prefix(count)) })
        }

        static func programmes(_ channel: Channel) -> [Programme] {
            guard channel.id == "news-one" else { return [] }
            return [
                Programme(channelID: channel.id, start: start, stop: start.addingTimeInterval(1800), title: "Morning News"),
                Programme(
                    channelID: channel.id, start: start.addingTimeInterval(1800), stop: start.addingTimeInterval(3600), title: "Weather"),
            ]
        }

        private func channel(_ name: String) throws -> Channel {
            try #require(live.channels.first { $0.name == name })
        }

        @Test("player-controls-and-playback-errors/the-channel-shows-on-the-lock-screen the programme, the channel line and play state")
        func info() async throws {
            live.pick(try channel("News One"))
            #expect(await eventually { engine.state == .playing })

            let info = try #require(live.nowPlayingInfo(at: Self.start.addingTimeInterval(60)))

            #expect(info.title == "Morning News")
            #expect(info.channelLine.hasSuffix("News One"))
            #expect(info.isPlaying)
            #expect(live.nowPlayingInfo(at: Self.start.addingTimeInterval(1860))?.title == "Weather", "the next programme")

            live.pick(try channel("Kids One"))
            #expect(live.nowPlayingInfo(at: Self.start)?.title == "Kids One", "the channel name without a programme")
        }

        @Test("player-controls-and-playback-errors/the-channel-shows-on-the-lock-screen a channel change reaches it within the interval")
        func updates() async throws {
            let task = Task { await live.publishNowPlaying() }
            #expect(await eventually { published.infos.count == 1 })
            #expect(published.infos.first == .some(nil), "nothing playing clears it")

            live.pick(try channel("Kids One"))

            #expect(await eventually(timeout: .seconds(5)) { published.infos.last??.title == "Kids One" })
            task.cancel()
        }

        @Test("player-controls-and-playback-errors/the-channel-shows-on-the-lock-screen play and pause there work")
        func commands() async throws {
            let task = Task { await live.publishNowPlaying() }
            let states = Task { await live.observeEngine() }
            defer { states.cancel() }
            #expect(await eventually { published.pause != nil })
            live.pick(try channel("Kids One"))
            #expect(await eventually { engine.state == .playing })

            published.pause?()
            #expect(await eventually { engine.state == .paused })
            published.play?()
            #expect(await eventually { engine.state == .playing })
            task.cancel()
        }

        @Test("player-controls-and-playback-errors/error-messages-for-each-reason no lock-screen field holds the address")
        func noSecrets() throws {
            live.pick(try channel("News One"))
            let info = try #require(live.nowPlayingInfo(at: Self.start))
            for secret in ["olof77", "hunter2pw", "panel.acme-iptv.example", "104.ts"] {
                #expect(!info.title.contains(secret))
                #expect(!info.channelLine.contains(secret))
            }
        }
    }
#endif
