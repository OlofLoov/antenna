import AntennaCore
import Foundation
import Testing

@testable import Antenna

#if os(iOS)
    import UIKit
#endif

#if os(iOS) || os(macOS)
    /// Multi-view in the Mac window, through the Live model the window
    /// reads. The model is shared, so these run wherever the tests do;
    /// `offered: true` stands in for a Mac with a wide enough screen.
    @MainActor
    @Suite(.serialized, .timeLimit(.minutes(1))) struct LiveMultiViewTests {
        let playing = PlayerTestEngine()
        let live: LiveModel
        let published = Published()

        @MainActor
        final class Published {
            var infos: [NowPlayingInfo?] = []
            var made: [PlayerTestEngine] = []
        }

        init() async throws {
            let published = published
            let channels = (1...4).map { (number: Int) in
                Channel(id: "c\(number)", name: "C\(number)", streamURL: URL(fileURLWithPath: "/c\(number).ts"), number: number)
            }
            var dependencies = LiveModel.Dependencies(
                engine: RoutedEngine(system: playing, demuxer: playing), load: { _ in Playlist(channels: channels) },
                hasLogin: { _ in true }, guide: nil, programmes: UITestingLive.guide, network: .online)
            dependencies.nowPlaying = NowPlayingSink(publish: { published.infos.append($0) }, listen: { _, _ in })
            dependencies.nowPlayingInterval = .milliseconds(20)
            dependencies.pictureInPicture = .none
            dependencies.multiView.cap = MultiViewCap(limit: 3)
            dependencies.multiView.tiles.make = {
                let engine = PlayerTestEngine()
                published.made.append(engine)
                return RoutedEngine(system: engine, demuxer: engine)
            }
            dependencies.multiView.tiles.lifecycle = { _ in nil }
            dependencies.multiView.sleep = { _ in try await Task.sleep(for: .seconds(3600)) }
            live = LiveModel(dependencies)
            live.sourcesChanged([SourceDescriptor(id: UUID(), name: "Home", kind: .m3u, url: URL(fileURLWithPath: "/home.m3u"))])
            await live.settled()
            Task { [live] in await live.observeEngine() }
            live.pick(try channel(1))
            #expect(await eventually { live.playback == .playing })
        }

        private func channel(_ number: Int) throws -> Channel {
            try #require(live.channels.first { $0.number == number })
        }

        @Test("multi-view/start-multi-view-on-a-mac the menu offers another channel while one plays, never the playing one")
        func menu() throws {
            #expect(live.multiViewMenu(for: try channel(2), offered: true) == .add)
            #expect(live.multiViewMenu(for: try channel(1), offered: true) == nil, "not on the playing channel")
            #expect(live.multiViewMenu(for: try channel(2), offered: false) == nil, "not on iPhone, iPad or a narrow screen")
        }

        @Test("multi-view/start-multi-view-on-an-ipad offered on an iPad at regular width, never compact or on iPhone")
        func offeredOnIPad() throws {
            #if os(iOS)
                #expect(!LiveModel.offersMultiView, "the Mac's screen check stays off")
                #expect(live.multiViewMenu(for: try channel(2)) == nil)
                #expect(!LiveModel.offersMultiView(regularWidth: false))
                #expect(LiveModel.offersMultiView(regularWidth: true) == (UIDevice.current.userInterfaceIdiom == .pad))
            #endif
        }

        @Test("multi-view/start-multi-view-on-a-mac adding a channel makes the playing one tile 1 with no reload and the new one tile 2")
        func start() async throws {
            await live.addToMultiView(try channel(2), offered: true)
            let multiView = try #require(live.multiView)
            #expect(multiView.session.tiles.count == 2)
            #expect(multiView.engine(of: 1)?.demuxer === playing)
            #expect(playing.loaded.count == 1)
            #expect(live.listedChannel == (try channel(2)))
            #expect(multiView.count == "2 of 3")
        }

        @Test("multi-view/change-a-tile-s-channel a channel picked in the list fills the selected tile")
        func listFillsTile() async throws {
            await live.addToMultiView(try channel(2), offered: true)
            live.pick(try channel(3))
            let multiView = try #require(live.multiView)
            #expect(await eventually { multiView.channel(of: 2) == (try? channel(3)) })
            #expect(multiView.channel(of: 1) == (try channel(1)))
            #expect(live.playing == (try channel(1)), "the single channel stays as it was")
        }

        @Test("multi-view/add-more-tiles-up-to-the-limit at the limit the menu shows Multi-view is full")
        func full() async throws {
            await live.addToMultiView(try channel(2), offered: true)
            await live.addToMultiView(try channel(3), offered: true)
            #expect(live.multiViewMenu(for: try channel(4), offered: true) == .full)
            #expect(live.multiViewMenu(for: try channel(2), offered: true) == nil, "a channel already in a tile")
        }

        @Test(
            "multi-view/sound-follows-the-highlighted-tile Space pauses no tile and the lock screen follows the selected tile"
        )
        func nowPlayingFollows() async throws {
            await live.addToMultiView(try channel(2), offered: true)
            let multiView = try #require(live.multiView)
            #expect(await eventually { published.made.count == 2 && published.made[1].state == .playing })
            live.playPause()
            #expect(published.made[1].pauses == 0)
            #expect(playing.pauses == 0)
            #expect(await eventually { live.nowPlayingInfo(at: .now)?.channelLine.hasSuffix("C2") == true })
            await multiView.select(1)
            #expect(live.nowPlayingInfo(at: .now)?.channelLine.hasSuffix("C1") == true)
        }

        @Test("multi-view/leave-multi-view exit keeps the selected tile's channel playing in the window with no reload")
        func exit() async throws {
            await live.addToMultiView(try channel(2), offered: true)
            let multiView = try #require(live.multiView)
            #expect(await eventually { published.made.count == 2 && published.made[1].state == .playing })
            let tile = published.made[1]
            await multiView.leave()
            #expect(await eventually { live.multiView == nil })
            #expect(live.playing == (try channel(2)))
            let routed = try #require(live.engine as? RoutedEngine)
            #expect(routed.demuxer === tile)
            #expect(tile.loaded.count == 1)
            #expect(live.playback == .playing)
        }

        @Test("multi-view/leaving-the-app on a Mac nothing pauses when the app goes to the background")
        func macKeepsPlaying() async {
            let lifecycle = PlaybackLifecycle(engine: playing, pausesInBackground: false)
            await lifecycle.enteredBackground()
            #expect(playing.pauses == 0)
            #if os(macOS)
                #expect(!PlaybackLifecycle.platformPausesInBackground)
            #endif
        }
    }
#endif
