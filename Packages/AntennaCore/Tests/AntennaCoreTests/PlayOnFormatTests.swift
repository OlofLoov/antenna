import Foundation
import Synchronization
import Testing

@testable import AntennaCore

@Suite struct PlayOnFormatTests {
    static let sent = Date(timeIntervalSince1970: 1_800_000_000)
    static let source = UUID()

    static func request(_ item: PlayRequest.Item, start: TimeInterval? = nil, id: UUID = UUID()) -> PlayRequest {
        PlayRequest(
            id: id, sender: UUID(), senderName: "Anna's iPhone", target: UUID(), source: source, item: item, startPosition: start,
            displayTitle: "Salt Road", created: sent)
    }

    static let items: [PlayRequest.Item] = [
        .channel(key: "4f1c9a"),
        .programme(channelKey: "4f1c9a", start: sent.addingTimeInterval(-3600), end: sent.addingTimeInterval(-60)),
        .movie(key: "77ab"),
        .episode(seriesKey: "s1", episodeKey: "e9"),
    ]

    @Test("play-on-apple-tv/a-request-holds-no-link-and-no-login: every item kind survives a round trip", arguments: items)
    func requestRoundTrip(item: PlayRequest.Item) throws {
        let request = Self.request(item, start: 2400)
        #expect(try PlayRequest(decoding: request.encoded()) == request)
    }

    @Test("play-on-apple-tv/starts-at-once-on-the-same-network: every frame survives a round trip through the reader")
    func framesRoundTrip() throws {
        let request = Self.request(.movie(key: "77ab"))
        let messages: [PlayMessage] = [
            .play(request),
            .answer(PlayAnswer(requestID: request.id, result: .started)),
            .answer(PlayAnswer(requestID: request.id, result: .needsPasscode)),
            .answer(PlayAnswer(requestID: request.id, result: .noLogin(source: Self.source))),
            .answer(PlayAnswer(requestID: request.id, result: .noSource(source: Self.source))),
            .answer(PlayAnswer(requestID: request.id, result: .notFound)),
            .answer(PlayAnswer(requestID: request.id, result: .waiting)),
            .answer(PlayAnswer(requestID: request.id, result: .unsupportedVersion)),
            .status(
                PlayStatus(
                    state: .playing, requestID: request.id, source: Self.source, item: request.item, title: "Salt Road", subtitle: nil,
                    position: 4320, duration: 5520, artworkKey: "77ab")),
            .status(PlayStatus(state: .stopped, title: "Sport One")),
            .control(.play), .control(.pause), .control(.handOff), .control(.disconnect),
        ]
        var bytes = Data()
        for message in messages { bytes.append(try PlayFrames.frame(message)) }
        var reader = PlayFrames.Reader()
        // Bytes arrive in uneven pieces, as TCP hands them over.
        var read: [PlayMessage] = []
        var offset = 0
        for size in [1, 3, 7, 100, 2, 500, 4096] where offset < bytes.count {
            let end = min(offset + size, bytes.count)
            read += reader.append(bytes[offset..<end]).compactMap { try? $0.get() }
            offset = end
        }
        read += reader.append(bytes[offset...]).compactMap { try? $0.get() }
        #expect(read == messages)
    }

    @Test("play-on-apple-tv/the-phone-says-why-the-tv-cannot-play: a newer frame or request is refused with its id")
    func unknownVersion() throws {
        let id = UUID()
        let newerRequest = #"{"type":"play","v":1,"request":{"v":2,"id":"\#(id.uuidString)","shape":"new"}}"#
        #expect(throws: PlayMessage.DecodeError.unsupportedVersion(requestID: id)) { try PlayMessage(decoding: Data(newerRequest.utf8)) }
        let newerFrame = #"{"type":"play","v":2,"request":{"id":"\#(id.uuidString)"}}"#
        #expect(throws: PlayMessage.DecodeError.unsupportedVersion(requestID: id)) { try PlayMessage(decoding: Data(newerFrame.utf8)) }
        #expect(throws: PlayMessage.DecodeError.unsupportedVersion(requestID: nil)) {
            try PlayMessage(decoding: Data(#"{"type":"wave","v":3}"#.utf8))
        }
        #expect(throws: PlayMessage.DecodeError.unknownType) { try PlayMessage(decoding: Data(#"{"type":"wave","v":1}"#.utf8)) }
        #expect(throws: PlayMessage.DecodeError.malformed) { try PlayMessage(decoding: Data("not json".utf8)) }
        #expect(throws: PlayMessage.DecodeError.unsupportedVersion(requestID: id)) {
            try PlayRequest(decoding: Data(#"{"v":2,"id":"\#(id.uuidString)"}"#.utf8))
        }
    }

    @Test("play-on-apple-tv/starts-at-once-on-the-same-network: a frame longer than the limit ends the read")
    func tooLong() {
        var reader = PlayFrames.Reader()
        var length = UInt32(PlayFrames.maximumLength + 1).bigEndian
        let results = reader.append(Data(bytes: &length, count: 4))
        #expect(results.count == 1)
        if case .failure(let error) = results.first { #expect(error == .tooLong) } else { Issue.record("expected tooLong") }
    }

    @Test("play-on-apple-tv/a-request-holds-no-link-and-no-login: the encoded request holds no URL-shaped string", arguments: items)
    func noLink(item: PlayRequest.Item) throws {
        let json = String(decoding: try PlayMessage.play(Self.request(item, start: 60)).encoded(), as: UTF8.self)
        for pattern in ["://", "http", "www.", "@", "username", "password", "token"] {
            #expect(!json.lowercased().contains(pattern), "\(pattern) in \(json)")
        }
        let printed = String(describing: Self.request(item))
        #expect(!printed.contains("Anna"))
        #expect(!printed.contains("Salt Road"))
    }

    @Test("play-on-apple-tv/requests-expire-and-leave-no-trace: live TV waits 5 minutes, anything else 6 hours")
    func expiry() {
        let onNow = PlayRequest.Item.programme(
            channelKey: "c", start: Self.sent.addingTimeInterval(-600), end: Self.sent.addingTimeInterval(600))
        let ended = PlayRequest.Item.programme(
            channelKey: "c", start: Self.sent.addingTimeInterval(-7200), end: Self.sent.addingTimeInterval(-1))
        let lifetimes: [(PlayRequest.Item, TimeInterval)] = [
            (.channel(key: "c"), 300), (onNow, 300), (ended, 21_600), (.movie(key: "m"), 21_600),
            (.episode(seriesKey: "s", episodeKey: "e"), 21_600),
        ]
        for (item, lifetime) in lifetimes {
            let request = Self.request(item)
            #expect(request.expires == Self.sent.addingTimeInterval(lifetime))
            #expect(!request.isExpired(at: Self.sent.addingTimeInterval(lifetime - 1)))
            #expect(request.isExpired(at: Self.sent.addingTimeInterval(lifetime)))
        }
        // A live channel sent an hour ago, a film three hours ago.
        #expect(Self.request(.channel(key: "c")).isExpired(at: Self.sent.addingTimeInterval(3600)))
        #expect(!Self.request(.movie(key: "m")).isExpired(at: Self.sent.addingTimeInterval(3 * 3600)))
    }
}

@Suite struct PlayDeviceListTests {
    static let now = Date(timeIntervalSince1970: 1_800_000_000)

    static func device(_ name: String, kind: PlayDeviceInfo.Kind = .tv, created: TimeInterval, seen: TimeInterval = 0) -> PlayDeviceInfo {
        PlayDeviceInfo(
            id: UUID(), kind: kind, name: name, publicKey: Data([4]), keyDate: now, lastSeen: now.addingTimeInterval(-seen),
            created: now.addingTimeInterval(created))
    }

    @Test("play-on-apple-tv/apple-tvs-on-the-same-icloud-account: two TVs called Apple TV are numbered by when they joined")
    func sameName() {
        let first = Self.device("Apple TV", created: -900)
        let second = Self.device("Apple TV", created: -100)
        let third = Self.device("apple tv", created: -50)
        let listed = PlayTV.listed([second, third, first], now: Self.now, locale: .english)
        #expect(listed.map(\.name) == ["Apple TV", "Apple TV 2", "apple tv 3"])
        #expect(listed.map(\.id) == [first.id, second.id, third.id])
    }

    @Test("play-on-apple-tv/apple-tvs-on-the-same-icloud-account: only TVs seen in the last 60 days are listed")
    func onlyRecentTVs() {
        let room = Self.device("Living Room", created: -10, seen: 59 * 86_400)
        let old = Self.device("Cabin", created: -20, seen: 60 * 86_400)
        let phone = Self.device("Anna's iPhone", kind: .phone, created: -30)
        #expect(PlayTV.listed([room, old, phone], now: Self.now, locale: .english).map(\.name) == ["Living Room"])
        #expect(PlayTV.listed([phone], now: Self.now, locale: .english).isEmpty)
        #expect(old.isForgotten(at: Self.now))
    }

    @Test("play-on-apple-tv/apple-tvs-on-the-same-icloud-account: TVs ready now come first, then by name")
    func order() {
        let bedroom = PlayTV(device: Self.device("Bedroom", created: 0), name: "Bedroom")
        let room = PlayTV(device: Self.device("Living Room", created: 0), name: "Living Room")
        let attic = PlayTV(device: Self.device("Attic", created: 0), name: "Attic")
        #expect(
            PlayTV.ordered([attic, bedroom, room], ready: [room.id], locale: .english).map(\.name) == ["Living Room", "Attic", "Bedroom"])
    }

    @Test("play-on-apple-tv/apple-tvs-on-the-same-icloud-account: a record is written again with a new key or after a day")
    func refresh() {
        let device = Self.device("Living Room", created: 0, seen: 3600)
        #expect(!device.needsRefresh(keyDate: Self.now, now: Self.now))
        #expect(device.needsRefresh(keyDate: Self.now.addingTimeInterval(1), now: Self.now))
        #expect(device.needsRefresh(keyDate: Self.now, now: Self.now.addingTimeInterval(86_400)))
    }
}

@Suite struct PlayOnKeyTests {
    @Test("play-on-apple-tv/only-the-same-account-can-send-over-the-network: HKDF info matches the fixed vector")
    func infoVector() throws {
        let sender = try #require(UUID(uuidString: "00112233-4455-6677-8899-AABBCCDDEEFF"))
        let target = try #require(UUID(uuidString: "FFEEDDCC-BBAA-9988-7766-554433221100"))
        let info = PlayOnKey.info(
            sender: sender, target: target, senderKeyDate: Date(timeIntervalSince1970: 1_800_000_000.75),
            targetKeyDate: Date(timeIntervalSince1970: 1_700_000_000))
        let hex = info.map { String(format: "%02x", $0) }.joined()
        #expect(hex == "00112233445566778899aabbccddeeff" + "ffeeddccbbaa99887766554433221100" + "000000006b49d200" + "000000006553f100")
        #expect(PlayOnKey.salt == Data("antenna-play-v1".utf8))
    }

    @Test("play-on-apple-tv/only-the-same-account-can-send-over-the-network: each pair of keys gives its own info")
    func infoDiffers() {
        let phone = UUID(), tv = UUID(), date = Date(timeIntervalSince1970: 1_800_000_000)
        let base = PlayOnKey.info(sender: phone, target: tv, senderKeyDate: date, targetKeyDate: date)
        #expect(base != PlayOnKey.info(sender: tv, target: phone, senderKeyDate: date, targetKeyDate: date))
        #expect(base != PlayOnKey.info(sender: phone, target: tv, senderKeyDate: date.addingTimeInterval(1), targetKeyDate: date))
        #expect(base != PlayOnKey.info(sender: phone, target: tv, senderKeyDate: date, targetKeyDate: date.addingTimeInterval(1)))
        #expect(base.count == 48)
    }

    @Test("play-on-apple-tv/only-the-same-account-can-send-over-the-network: the identity names the sender and nothing else")
    func identity() {
        let id = UUID()
        #expect(PlayOnKey.sender(identity: PlayOnKey.identity(sender: id)) == id)
        #expect(PlayOnKey.sender(identity: Data("guest".utf8)) == nil)
        #expect(PlayOnKey.keyDate(Date(timeIntervalSince1970: 12.9)) == Date(timeIntervalSince1970: 12))
    }
}

@Suite struct PlayOnConnectedTextTests {
    @Test("play-on-apple-tv/connected-to-a-tv: the bar names the TV, the item and the programme")
    func bar() {
        let status = PlayStatus(state: .playing, title: "Sport One", subtitle: "Premier League: Arsenal v Liverpool")
        #expect(PlayOnText.playing(on: "Living Room", locale: .english) == "Playing on Living Room")
        #expect(PlayOnText.statusLine(status, locale: .english) == "Sport One · Premier League: Arsenal v Liverpool")
        #expect(PlayOnText.statusLine(PlayStatus(state: .paused, title: "Salt Road"), locale: .english) == "Salt Road")
        #expect(PlayOnText.stopped(on: "Living Room", locale: .english) == "Stopped on Living Room")
    }

    @Test("play-on-apple-tv/play-on-this-iphone: the button names the device it moves to")
    func playHere() {
        #expect(PlayOnText.playHere(.phone, locale: .english) == "Play on this iPhone")
        #expect(PlayOnText.playHere(.pad, locale: .english) == "Play on this iPad")
        #expect(PlayOnText.playHere(.mac, locale: .english) == "Play on this Mac")
        #expect(PlayOnText.resumeOn("Living Room", locale: .english) == "Resume on Living Room")
    }
}

@Suite struct StreamGateTests {
    /// Counts loads; plays nothing.
    final class Counting: PlaybackEngine, @unchecked Sendable {
        private let loads = Mutex(0)
        var count: Int { loads.withLock { $0 } }
        var state: PlaybackState { get async { .idle } }
        var capabilities: EngineCapabilities { get async { EngineCapabilities(supportsPictureInPicture: false) } }
        func load(_ url: URL, options: PlaybackOptions) async throws { loads.withLock { $0 += 1 } }
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

    @Test("play-on-apple-tv/the-phone-opens-no-stream-while-connected: a closed gate turns every load away")
    func closedGate() async throws {
        let system = Counting(), demuxer = Counting(), gate = StreamGate()
        let engine = RoutedEngine(system: system, demuxer: demuxer, gate: gate)
        gate.close()
        for address in ["http://a.example/1.ts", "http://a.example/2.m3u8", "http://a.example/3.mkv"] {
            let url = try #require(URL(string: address))
            await #expect(throws: CancellationError.self) { try await engine.load(url, options: PlaybackOptions()) }
        }
        #expect(system.count + demuxer.count == 0)
        #expect(gate.refused == 3)
        gate.open()
        try await engine.load(URL(filePath: "/a/1.ts"), options: PlaybackOptions())
        #expect(system.count + demuxer.count == 1)
    }
}

@Suite struct PlayOnOfferTextTests {
    @Test("play-on-apple-tv/the-tv-offers-a-waiting-request: the facts line names the kind and where a film resumes")
    func facts() {
        let sent = PlayOnFormatTests.sent
        func facts(_ item: PlayRequest.Item, start: TimeInterval? = nil) -> String {
            PlayOnText.offerFacts(PlayOnFormatTests.request(item, start: start), locale: .english)
        }
        #expect(facts(.channel(key: "c")) == "Live channel")
        #expect(facts(.programme(channelKey: "c", start: sent.addingTimeInterval(-60), end: sent.addingTimeInterval(60))) == "Live channel")
        #expect(facts(.programme(channelKey: "c", start: sent.addingTimeInterval(-7200), end: sent.addingTimeInterval(-60))) == "Catch-up")
        #expect(facts(.movie(key: "m"), start: 2400) == "Movie · Resumes at 40 min")
        #expect(facts(.episode(seriesKey: "s", episodeKey: "e")) == "Episode")
        #expect(PlayOnText.offline(.english) == "You're offline. Nothing was sent.")
    }
}

@Suite struct PlayOnTextTests {
    @Test("play-on-apple-tv/the-phone-says-why-the-tv-cannot-play: each answer reads as the copy table says")
    func lines() {
        let source = UUID()
        func line(_ result: PlayAnswer.Result) -> String {
            PlayOnText.line(for: result, tv: "Living Room", item: "Salt Road", sourceName: "Acme TV", locale: .english)
        }
        #expect(line(.started) == "Playing on Living Room")
        #expect(line(.needsPasscode) == "Enter the passcode on Living Room.")
        #expect(line(.noLogin(source: source)) == "Living Room isn't signed in to Acme TV.")
        #expect(line(.noSource(source: source)) == "Living Room doesn't have Acme TV yet. Try again in a minute.")
        #expect(line(.notFound) == "Living Room couldn't find Salt Road.")
        #expect(line(.unsupportedVersion) == "Update Antuna on Living Room to play from here.")
        #expect(PlayOnText.sent(to: "Living Room", locale: .english) == "Sent. Living Room offers it when Antuna opens there.")
        #expect(PlayOnText.from("Anna's iPhone", locale: .english) == "From Anna's iPhone")
        #expect(PlayOnText.playOn("Living Room", locale: .english) == "Play on Living Room")
        #expect(PlayOnText.watchOn("Living Room", locale: .english) == "Watch on Living Room")
    }
}
