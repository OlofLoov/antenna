import AntennaCore
import Foundation
import Testing

@testable import Antenna

/// The phone connected to an Apple TV, against a scripted TV on a fake link.
@MainActor
@Suite struct PlayOnConnectionTests {
    typealias Link = PlayDestinationTests.FakeLink
    static let livingRoom = PlayDestinationTests.livingRoom
    static let channel = PlayDestinationTests.channel

    /// A rig whose sends come back with an open link, so the phone connects.
    static func connected(answer: PlayAnswer.Result = .started) async throws -> (PlayDestinationTests.Rig, Link) {
        let rig = try PlayDestinationTests.rig([PlayDestinationTests.tv(livingRoom, "Living Room")], outcomes: [.answered(answer)])
        let link = Link()
        rig.sender.links = [link]
        await rig.destination.activate()
        await rig.destination.send(Self.channel, to: Self.livingRoom)
        return (rig, link)
    }

    static func status(_ state: PlayStatus.State, request: UUID? = nil, position: TimeInterval? = nil) -> PlayStatus {
        PlayStatus(state: state, requestID: request, source: channel.source, item: channel.item, title: "Sport One", position: position)
    }

    @Test("play-on-apple-tv/connected-to-a-tv: a request over the network connects the phone and shows what the TV plays")
    func connects() async throws {
        let (rig, link) = try await Self.connected()
        let connection = try #require(rig.destination.connection)
        #expect(connection.tv.name == "Living Room")
        #expect(rig.destination.notice == nil, "the bar says it, so no line shows")
        link.tv(.status(Self.status(.playing)))
        #expect(connection.status?.title == "Sport One")
        #expect(connection.isPlaying)
    }

    @Test("play-on-apple-tv/connected-to-a-tv: pause from the phone, and the TV changing on its own, show in the bar")
    func pauseAndFollow() async throws {
        let (rig, link) = try await Self.connected()
        link.tv(.status(Self.status(.playing)))
        rig.destination.playPause()
        #expect(link.sent.last == .control(.pause))
        link.tv(.status(Self.status(.paused)))
        #expect(rig.destination.connection?.isPlaying == false)
        rig.destination.playPause()
        #expect(link.sent.last == .control(.play))
    }

    @Test("play-on-apple-tv/connected-to-a-tv: a request through iCloud leaves the phone unconnected")
    func iCloudDoesNotConnect() async throws {
        let rig = try PlayDestinationTests.rig([PlayDestinationTests.tv(Self.livingRoom, "Living Room")], found: [])
        await rig.destination.activate()
        await rig.destination.send(Self.channel, to: Self.livingRoom)
        #expect(rig.destination.connection == nil)
        #expect(!rig.gate.isClosed)
    }

    @Test("play-on-apple-tv/play-goes-to-the-tv-while-connected: a play while connected goes over the same link")
    func playGoesToTheTV() async throws {
        let (rig, link) = try await Self.connected()
        let film = PlayOnItem(item: .movie(key: "m"), source: UUID(), title: "Salt Road", sourceName: "Acme TV")
        #expect(rig.destination.playOnTV(film))
        for _ in 0..<50 where link.sent.count < 1 { await Task.yield() }
        while rig.destination.sending { await Task.yield() }
        guard case .play(let request) = link.sent.last else {
            Issue.record("no play on the link")
            return
        }
        #expect(request.item == .movie(key: "m"))
        #expect(rig.sender.sent.count == 1, "no second connection")
    }

    @Test("play-on-apple-tv/play-goes-to-the-tv-while-connected: a refusal while connected says why and plays nothing here")
    func refusedWhileConnected() async throws {
        let (rig, link) = try await Self.connected()
        link.answer = .needsPasscode
        await rig.destination.send(Self.channel, to: Self.livingRoom)
        #expect(rig.destination.notice?.text == "Enter the passcode on Living Room.")
        #expect(rig.destination.connection != nil)
        #expect(rig.gate.isClosed)
    }

    @Test("play-on-apple-tv/the-phone-opens-no-stream-while-connected: the stream gate is shut while connected")
    func gate() async throws {
        let (rig, _) = try await Self.connected()
        #expect(rig.gate.isClosed)
        rig.destination.disconnect()
        #expect(!rig.gate.isClosed)
    }

    @Test("play-on-apple-tv/the-phone-opens-no-stream-while-connected: no engine opens a stream through the gate while connected")
    func noStreamOpens() async throws {
        let (rig, _) = try await Self.connected()
        let counting = StreamGateTestEngine()
        let engine = RoutedEngine(system: counting, demuxer: counting, gate: rig.gate)
        // Live, the Guide, a title page, an episode, Search, a reminder and multi-view all load through an app engine.
        for address in ["http://p.example/live/1.ts", "http://p.example/2.m3u8", "http://p.example/movie/3.mkv", "http://p.example/4.mp4"] {
            try? await engine.load(try #require(URL(string: address)), options: PlaybackOptions())
        }
        #expect(counting.loads == 0)
        #expect(rig.gate.refused == 4)
    }

    @Test("play-on-apple-tv/play-on-this-iphone: the TV stops, the phone disconnects and plays from the TV's place")
    func moveHere() async throws {
        let (rig, link) = try await Self.connected()
        var played: PlayStatus?
        rig.destination.playHere = { played = $0 }
        link.tv(.status(Self.status(.playing, position: 100)))
        let moving = Task { await rig.destination.moveHere() }
        for _ in 0..<50 where link.sent.last != .control(.handOff) { await Task.yield() }
        #expect(link.sent.last == .control(.handOff))
        link.tv(.status(Self.status(.stopped, position: 4320)))
        await moving.value
        #expect(played?.position == 4320)
        #expect(rig.destination.connection == nil)
        #expect(!rig.gate.isClosed)
    }

    @Test("play-on-apple-tv/the-connection-ends-cleanly: Disconnect leaves the TV playing and the phone plays here again")
    func disconnect() async throws {
        let (rig, link) = try await Self.connected()
        rig.destination.disconnect()
        #expect(link.sent.last == .control(.disconnect))
        #expect(link.closed)
        #expect(rig.destination.connection == nil)
    }

    @Test("play-on-apple-tv/the-connection-ends-cleanly: the TV stopping shows Stopped, then the connection ends")
    func tvStops() async throws {
        let (rig, link) = try await Self.connected()
        let connection = try #require(rig.destination.connection)
        link.tv(.status(Self.status(.stopped)))
        #expect(connection.stopped)
        for _ in 0..<100 where rig.destination.connection != nil { try await Task.sleep(for: .milliseconds(10)) }
        #expect(rig.destination.connection == nil)
    }

    @Test("play-on-apple-tv/the-connection-ends-cleanly: a dropped link, as when leaving the house, ends the connection")
    func linkDrops() async throws {
        let (rig, link) = try await Self.connected()
        link.drop()
        #expect(rig.destination.connection == nil)
        #expect(!rig.gate.isClosed)
    }

    @Test("play-on-apple-tv/the-connection-ends-cleanly: back from the background the phone connects again without a stream in between")
    func reconnects() async throws {
        let (rig, link) = try await Self.connected()
        let request = try #require(rig.sender.sent.first)
        link.tv(.status(Self.status(.playing, request: request.id)))
        rig.destination.deactivate()
        #expect(rig.destination.connection == nil)
        #expect(rig.gate.isClosed, "no stream opens while the phone may connect again")
        let again = Link()
        rig.sender.links = [again]
        let activating = Task { await rig.destination.activate() }
        for _ in 0..<200 { await Task.yield() }
        again.tv(.status(Self.status(.playing, request: request.id)))
        await activating.value
        #expect(rig.destination.connection?.status?.requestID == request.id)
        #expect(rig.gate.isClosed)
    }
}

/// Counts loads and plays nothing.
final class StreamGateTestEngine: PlaybackEngine, @unchecked Sendable {
    private(set) var loads = 0
    var state: PlaybackState { get async { .idle } }
    var capabilities: EngineCapabilities { get async { EngineCapabilities(supportsPictureInPicture: false) } }
    func load(_ url: URL, options: PlaybackOptions) async throws { loads += 1 }
    func play() async {}
    func pause() async {}
    func stop() async {}
    func handOver() async {}
    func seek(to time: Duration) async throws {}
    func selectAudio(_ id: MediaTrack.ID) async {}
    func selectSubtitle(_ id: MediaTrack.ID?) async {}
    func states() async -> AsyncStream<PlaybackState> { AsyncStream { $0.finish() } }
    func presentation() async -> AsyncStream<PresentationInfo?> { AsyncStream { $0.finish() } }
    func tracks() async -> AsyncStream<TrackList> { AsyncStream { $0.finish() } }
    func position() async -> AsyncStream<PlaybackPosition> { AsyncStream { $0.finish() } }
    func subtitleCues() async -> AsyncStream<[SubtitleCue]> { AsyncStream { $0.finish() } }
}
