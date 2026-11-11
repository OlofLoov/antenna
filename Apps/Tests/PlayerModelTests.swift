import AntennaCore
import Foundation
import Testing

@testable import Antenna

/// The player model on a scripted engine, clock, connection and Keychain.
@MainActor
@Suite struct PlayerModelTests {
    let engine = PlayerTestEngine()
    let clock = SleepClock()
    let network = ScriptedNetwork()
    let lines = LogLines()
    let player: PlayerModel
    let source = UUID()
    let reloads = Counter()

    static let secretURL =
        URL(string: "http://olof77:hunter2pw@panel.acme-iptv.example:8080/live/olof77/hunter2pw/104.ts") ?? URL(fileURLWithPath: "/")
    static let secrets = [secretURL.absoluteString, "panel.acme-iptv.example", "acme-iptv", "olof77", "hunter2pw", "104.ts"]

    var channel: Channel {
        Channel(id: "sport-one", name: "Sport One", streamURL: Self.secretURL, sourceID: source)
    }

    init() {
        let clock = clock
        player = PlayerModel(
            .init(
                engine: engine, device: .other, sleep: { try await clock.sleep(for: $0) }, now: { Date(timeIntervalSince1970: 0) },
                network: network.watch, log: lines.playerLog))
        let reloads = reloads
        let engine = engine
        player.reload = { channel in
            reloads.value += 1
            Task { try? await engine.load(channel.streamURL) }
        }
    }

    private func tune() {
        player.tuned(PlayerSubject(channel: channel, source: "Acme TV", number: 104))
    }

    private func send(_ state: PlaybackState) async {
        engine.send(state)
        player.stateChanged(state)
        await clock.settle()
    }

    // MARK: Spinner

    @Test("player-controls-and-playback-errors/a-spinner-while-waiting-and-a-reason-if-it-is-slow the spinner waits half a second")
    func spinnerAfterHalfASecond() async {
        tune()
        await send(.loading)
        await clock.advance(by: .milliseconds(400))
        #expect(player.waiting == nil)

        await clock.advance(by: .milliseconds(100))
        #expect(player.waiting == .spinner)

        await send(.playing)
        #expect(player.waiting == nil)
    }

    @Test("player-controls-and-playback-errors/a-spinner-while-waiting-and-a-reason-if-it-is-slow buffering after playing shows it too")
    func spinnerWhileBuffering() async {
        tune()
        await send(.playing)
        await send(.buffering)
        await clock.advance(by: .milliseconds(500))
        #expect(player.waiting == .spinner)

        await send(.paused)
        #expect(player.waiting == nil, "paused, the spinner goes")
    }

    @Test("player-controls-and-playback-errors/a-spinner-while-waiting-and-a-reason-if-it-is-slow a quick start never shows it")
    func quickStart() async {
        tune()
        await send(.loading)
        await clock.advance(by: .milliseconds(300))
        await send(.playing)
        await clock.advance(by: .seconds(20))
        #expect(player.waiting == nil)
    }

    @Test("player-controls-and-playback-errors/a-spinner-while-waiting-and-a-reason-if-it-is-slow ten seconds on, the source is slow")
    func slowSource() async {
        tune()
        await send(.loading)
        await clock.advance(by: .milliseconds(500))
        await clock.advance(by: .milliseconds(9900))
        #expect(player.waiting == .spinner)

        await clock.advance(by: .milliseconds(100))
        #expect(player.waiting == .slow(caption: "Still buffering. Acme TV is sending data slowly."))

        await send(.failed(.timedOut))
        #expect(player.waiting == nil, "failing, the spinner goes")
    }

    // MARK: Reconnecting

    @Test("player-controls-and-playback-errors/a-dropped-stream-shows-that-it-is-reconnecting the count replaces the spinner")
    func reconnectCount() async {
        tune()
        await send(.playing)
        await send(.reconnecting(attempt: 1, of: 3))
        #expect(player.waiting == .reconnecting(caption: "Reconnecting… attempt 1 of 3"))
        await clock.advance(by: .seconds(30))
        #expect(player.waiting == .reconnecting(caption: "Reconnecting… attempt 1 of 3"), "no spinner or slow line over it")

        await send(.reconnecting(attempt: 2, of: 3))
        #expect(player.waiting == .reconnecting(caption: "Reconnecting… attempt 2 of 3"))
        #expect(player.failure == nil, "no error while it reconnects")

        await send(.playing)
        #expect(player.waiting == nil)
        #expect(player.failure == nil)
    }

    @Test("player-controls-and-playback-errors/a-dropped-stream-shows-that-it-is-reconnecting the error shows when the engine gives up")
    func givingUp() async {
        tune()
        await send(.playing)
        await send(.reconnecting(attempt: 3, of: 3))
        await send(.failed(.stoppedSendingData))

        #expect(player.waiting == nil)
        #expect(player.failure == .stoppedSendingData)
        #expect(player.message == FailureMessage(title: "Stream stopped", explanation: "Acme TV stopped sending data."))
        #expect(player.failedAt == Date(timeIntervalSince1970: 0))
    }

    // MARK: Recovery

    @Test("player-controls-and-playback-errors/try-again-or-recover-on-its-own Try again loads the same channel once, with the spinner")
    func tryAgain() async {
        tune()
        await send(.failed(.notFound))
        #expect(player.message?.title == "Stream not found")

        player.retry()

        #expect(reloads.value == 1)
        #expect(player.failure == nil, "the error goes")
        #expect(player.waiting == .spinner, "the spinner shows at once")
        #expect(player.subject?.channel == channel, "the same channel")
        #expect(await eventually { engine.loaded == [Self.secretURL] })
    }

    @Test("player-controls-and-playback-errors/try-again-or-recover-on-its-own the network coming back loads again")
    func networkReturns() async {
        tune()
        network.set(online: false)
        await send(.failed(.offline))
        #expect(player.message?.title == "You're offline")
        await clock.settle()
        #expect(reloads.value == 0, "nothing loads while offline")

        network.set(online: true)

        #expect(await eventually(timeout: .seconds(1)) { reloads.value == 1 }, "within a second of the connection returning")
        #expect(player.failure == nil)
    }

    @Test("player-controls-and-playback-errors/try-again-or-recover-on-its-own an arriving login loads again")
    func loginArrives() async {
        let arrived = Counter()
        player.hasLogin = { [source] id in id == source && arrived.value > 0 }
        tune()
        await send(.failed(.loginNotOnDevice))
        #expect(player.message?.title == "Waiting for login")
        await clock.advance(by: .seconds(5))
        #expect(reloads.value == 0)

        arrived.value = 1
        await clock.advance(by: .seconds(5))

        #expect(reloads.value == 1)
        #expect(player.failure == nil)
    }

    @Test("player-controls-and-playback-errors/try-again-or-recover-on-its-own other failures wait for the user")
    func noRecoveryForOtherFailures() async {
        tune()
        await send(.failed(.notAllowed))
        network.set(online: false)
        network.set(online: true)
        await clock.advance(by: .seconds(60))
        #expect(reloads.value == 0)
        #expect(player.failure == .notAllowed)
    }

    @Test("player-controls-and-playback-errors/try-again-or-recover-on-its-own changing channel from the error starts fresh")
    func changingChannel() async {
        tune()
        await send(.failed(.offline))
        var other = channel
        other.id = "news"
        player.tuned(PlayerSubject(channel: other, source: "Acme TV", number: 1))

        #expect(player.failure == nil)
        network.set(online: false)
        network.set(online: true)
        await clock.settle()
        #expect(reloads.value == 0, "the old channel's recovery stopped")
    }

    @Test("player-controls-and-playback-errors/try-again-or-recover-on-its-own a load that throws shows the error")
    func loadThrows() async {
        tune()
        player.loadFailed(.serverBusy)
        #expect(player.message == FailureMessage(title: "Provider busy", explanation: "Acme TV is busy right now. Try again in a moment."))
    }

    // MARK: Secrets

    @Test("player-controls-and-playback-errors/error-messages-for-each-reason no message, caption or log line holds the address")
    func noSecrets() async {
        var strings: [String] = []
        for reason in FailureMessageTestReasons.all {
            tune()
            await send(.loading)
            await clock.advance(by: .seconds(11))
            strings += [player.waiting?.caption].compactMap(\.self)
            await send(.reconnecting(attempt: 1, of: 3))
            strings += [player.waiting?.caption].compactMap(\.self)
            await send(.failed(reason))
            strings += [player.message?.title, player.message?.explanation].compactMap(\.self)
            player.retry()
        }
        strings += lines.all
        #expect(lines.all.contains("playback failed: offline"))
        for string in strings {
            for secret in Self.secrets {
                #expect(!string.contains(secret), "\(string) holds \(secret)")
            }
        }
    }
}

enum FailureMessageTestReasons {
    static let all: [PlaybackFailure] = [
        .offline, .unreachable, .secureConnectionFailed, .loginNotOnDevice, .notAllowed, .notFound, .serverBusy,
        .serverError, .refused(status: 451), .timedOut, .stoppedSendingData, .unreadable, .cannotDecode(codec: "vc1"),
        .noDecoderFree,
    ]
}

extension SleepClock {
    func sleep(for duration: Duration) async throws {
        try await sleep(duration)
    }
}

#if os(iOS) || os(macOS)
    /// The player model inside Live, on a scripted engine.
    @MainActor
    @Suite struct LivePlayerTests {
        let engine = PlayerTestEngine()
        let live: LiveModel
        let source = UUID()
        let channel = Channel(id: "news", name: "News One", streamURL: URL(fileURLWithPath: "/news.ts"))

        init() async {
            let channels = [channel]
            live = LiveModel(
                .init(
                    engine: engine, load: { _ in Playlist(channels: channels) }, hasLogin: { _ in true }, guide: nil,
                    programmes: UITestingLive.guide, network: .online))
            live.sourcesChanged([SourceDescriptor(id: source, name: "Home", kind: .m3u, url: URL(fileURLWithPath: "/home.m3u"))])
            await live.settled()
        }

        @Test("player-controls-and-playback-errors/try-again-or-recover-on-its-own Try again on Live loads the channel in place")
        func retryInPlace() async throws {
            let tagged = try #require(live.channels.first)
            engine.failNextLoad = .notFound
            live.pick(tagged)
            #expect(await eventually { live.player.failure == .notFound })
            #expect(live.player.message?.explanation.hasPrefix("Home returned 404") == true, "the message names the source")

            live.player.retry()

            #expect(await eventually { engine.loaded.count == 2 && engine.state == .playing })
            #expect(live.playing == tagged)
            #expect(live.player.failure == nil)
        }
    }
#endif
