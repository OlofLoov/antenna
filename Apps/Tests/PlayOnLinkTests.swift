import AntennaCore
import Foundation
import Network
import Testing

#if os(tvOS)
    @testable import AntennaTV
#else
    @testable import Antenna
#endif

/// The home-network link between a phone and an Apple TV, through the real
/// TLS-PSK setup over loopback in this process. Runs in both the iOS and
/// tvOS unit tests.
@MainActor
@Suite(.serialized) struct PlayOnLinkTests {
    static let keyDate = Date(timeIntervalSince1970: 1_800_000_000)

    static func device(_ kind: PlayDeviceInfo.Kind, _ seed: UInt8, name: String) throws -> PlayOnDevice {
        let keys = try PlayOnKeyPair(rawRepresentation: Data(repeating: seed, count: 32), keyDate: keyDate)
        return PlayOnDevice(id: UUID(), kind: kind, name: name, keys: keys)
    }

    let phone: PlayOnDevice
    let tv: PlayOnDevice
    let guest: PlayOnDevice

    init() throws {
        phone = try Self.device(.phone, 7, name: "Anna's iPhone")
        tv = try Self.device(.tv, 9, name: "Living Room")
        guest = try Self.device(.phone, 11, name: "Guest's iPhone")
    }

    func request(from sender: PlayOnDevice, version: Int = PlayRequest.currentVersion) -> PlayRequest {
        PlayRequest(
            version: version, sender: sender.id, senderName: sender.name, target: tv.id, source: UUID(), item: .channel(key: "4f1c"),
            displayTitle: "Sport One", created: Self.keyDate)
    }

    /// Waits for the listener's port, with a deadline only as a hang guard.
    func port(of listener: PlayOnListener) async throws -> NWEndpoint.Port {
        for _ in 0..<200 {
            if let port = listener.port { return port }
            try await Task.sleep(for: .milliseconds(10))
        }
        throw CancellationError()
    }

    func endpoint(_ port: NWEndpoint.Port) -> NWEndpoint {
        .hostPort(host: "127.0.0.1", port: port)
    }

    @Test("play-on-apple-tv/only-the-same-account-can-send-over-the-network: both ends derive the same key, a third key another")
    func keysAgree() throws {
        let phoneInfo = phone.info(now: Self.keyDate)
        let tvInfo = tv.info(now: Self.keyDate)
        let sent = try phone.linkKey(sendingTo: tvInfo)
        #expect(sent.count == 32)
        #expect(try tv.linkKey(receivingFrom: phoneInfo) == sent)
        #expect(try guest.linkKey(sendingTo: tvInfo) != sent)
        var later = tvInfo
        later.keyDate = Self.keyDate.addingTimeInterval(60)
        #expect(try phone.linkKey(sendingTo: later) != sent)
        #expect(!String(describing: phone.keys).contains("Key("))
    }

    @Test("play-on-apple-tv/starts-at-once-on-the-same-network: a play over the link gets the TV's answer")
    func playAndAnswer() async throws {
        let listener = PlayOnListener(device: tv, advertises: false)
        var received: [PlayRequest] = []
        listener.request = { request, reply in
            received.append(request)
            reply(.needsPasscode)
        }
        listener.accept([phone.info(now: Self.keyDate), tv.info(now: Self.keyDate)])
        listener.start()
        defer { listener.stop() }
        let port = try await port(of: listener)
        let sent = request(from: phone)
        let outcome = await NetworkPlaySender(device: phone).send(
            sent, to: tv.info(now: Self.keyDate), at: endpoint(port), limits: PlaySendLimits())
        #expect(outcome.outcome == .answered(.needsPasscode))
        #expect(received == [sent])
    }

    @Test("play-on-apple-tv/only-the-same-account-can-send-over-the-network: a device the TV does not know is refused and nothing plays")
    func refusesUnknownDevice() async throws {
        let listener = PlayOnListener(device: tv, advertises: false)
        var received = 0
        var refusals = 0
        listener.request = { _, reply in
            received += 1
            reply(.started)
        }
        listener.refused = { refusals += 1 }
        listener.accept([phone.info(now: Self.keyDate)])
        listener.start()
        defer { listener.stop() }
        let port = try await port(of: listener)
        let outcome = await NetworkPlaySender(device: guest).send(
            request(from: guest), to: tv.info(now: Self.keyDate), at: endpoint(port), limits: PlaySendLimits())
        #expect(outcome.outcome == .refused)
        #expect(received == 0)
        // The TV hears about the failed handshake, so it can read the device list again.
        for _ in 0..<100 where refusals == 0 { try await Task.sleep(for: .milliseconds(10)) }
        #expect(refusals > 0)
    }

    @Test("play-on-apple-tv/only-the-same-account-can-send-over-the-network: a phone holding the TV's old key is refused")
    func refusesOldKey() async throws {
        let listener = PlayOnListener(device: tv, advertises: false)
        listener.request = { _, reply in reply(.started) }
        listener.accept([phone.info(now: Self.keyDate)])
        listener.start()
        defer { listener.stop() }
        let port = try await port(of: listener)
        var stale = tv.info(now: Self.keyDate)
        stale.keyDate = Self.keyDate.addingTimeInterval(-3600)
        let outcome = await NetworkPlaySender(device: phone).send(
            request(from: phone), to: stale, at: endpoint(port), limits: PlaySendLimits())
        #expect(outcome.outcome == .refused)
    }

    @Test("play-on-apple-tv/the-phone-says-why-the-tv-cannot-play: a request from a newer Antuna is answered unsupportedVersion")
    func newerVersion() async throws {
        let listener = PlayOnListener(device: tv, advertises: false)
        var received = 0
        listener.request = { _, reply in
            received += 1
            reply(.started)
        }
        listener.accept([phone.info(now: Self.keyDate)])
        listener.start()
        defer { listener.stop() }
        let port = try await port(of: listener)
        let outcome = await NetworkPlaySender(device: phone).send(
            request(from: phone, version: 2), to: tv.info(now: Self.keyDate), at: endpoint(port), limits: PlaySendLimits())
        #expect(outcome.outcome == .answered(.unsupportedVersion))
        #expect(received == 0)
    }

    @Test("play-on-apple-tv/the-phone-can-take-a-request-back: a cancel over the link reaches the TV and is answered")
    func cancelOverTheLink() async throws {
        let listener = PlayOnListener(device: tv, advertises: false)
        var asked: [UUID] = []
        listener.cancel = { id in
            asked.append(id)
            return asked.count == 1
        }
        listener.accept([phone.info(now: Self.keyDate)])
        listener.start()
        defer { listener.stop() }
        let port = try await port(of: listener)
        let id = UUID()
        let sender = NetworkPlaySender(device: phone)
        #expect(await sender.cancel(id, on: tv.info(now: Self.keyDate), at: endpoint(port), limits: PlaySendLimits()))
        #expect(!(await sender.cancel(id, on: tv.info(now: Self.keyDate), at: endpoint(port), limits: PlaySendLimits())), "too late")
        #expect(asked == [id, id])
    }

    @Test("play-on-apple-tv/starts-at-once-on-the-same-network: no answer within the limit is no answer")
    func silentTV() async throws {
        let listener = PlayOnListener(device: tv, advertises: false)
        listener.request = { _, _ in }
        listener.accept([phone.info(now: Self.keyDate)])
        listener.start()
        defer { listener.stop() }
        let port = try await port(of: listener)
        let outcome = await NetworkPlaySender(device: phone).send(
            request(from: phone), to: tv.info(now: Self.keyDate), at: endpoint(port),
            limits: PlaySendLimits(reach: .seconds(3), answer: .milliseconds(500)))
        #expect(outcome.outcome == .noAnswer)
    }

    @Test("play-on-apple-tv/connected-to-a-tv: a connected phone hears what the TV plays and its play and pause reach the TV")
    func listenerStatusAndControl() async throws {
        let listener = PlayOnListener(device: tv, advertises: false)
        let tvSide = TVSide()
        let playing = PlayStatus(state: .playing, title: "Sport One")
        listener.currentStatus = { playing }
        listener.control = { tvSide.controls.append($0) }
        listener.accept([phone.info(now: Self.keyDate)])
        listener.start()
        defer { listener.stop() }
        let port = try await port(of: listener)
        let link = try #require(
            await NetworkPlaySender(device: phone).connect(to: tv.info(now: Self.keyDate), at: endpoint(port), within: .seconds(3)))
        defer { link.close() }
        var statuses: [PlayStatus] = []
        link.listen { result in
            if case .success(.status(let status)) = result { statuses.append(status) }
        }
        for _ in 0..<300 where statuses.isEmpty { try await Task.sleep(for: .milliseconds(10)) }
        #expect(statuses.first == playing, "the TV says what plays as soon as the phone connects")
        link.send(.control(.pause))
        for _ in 0..<300 where tvSide.controls.isEmpty { try await Task.sleep(for: .milliseconds(10)) }
        #expect(tvSide.controls == [.pause])
        let paused = PlayStatus(state: .paused, title: "Sport One")
        listener.broadcast(paused)
        for _ in 0..<300 where statuses.count < 2 { try await Task.sleep(for: .milliseconds(10)) }
        #expect(statuses.last == paused)
        link.send(.control(.disconnect))
        for _ in 0..<300 where listener.connectedCount > 0 { try await Task.sleep(for: .milliseconds(10)) }
        #expect(listener.connectedCount == 0, "Disconnect makes the TV forget the phone")
    }

    @Test("play-on-apple-tv/a-request-holds-no-link-and-no-login: status and control frames cross the encrypted link")
    func statusAndControl() async throws {
        let tvInfo = tv.info(now: Self.keyDate)
        let key = try phone.linkKey(sendingTo: tvInfo)
        let identity = PlayOnKey.identity(sender: phone.id)
        let server = try NWListener(using: PlayLinkParameters.server(keys: [(identity, key)]), on: .any)
        let tvSide = TVSide()
        let status = PlayStatus(state: .paused, title: "Salt Road", position: 4320, duration: 5520, artworkKey: "77ab")
        server.newConnectionHandler = { connection in
            MainActor.assumeIsolated {
                let link = PlayLink(connection)
                link.received = { result in
                    if case .success(.control(let control)) = result { tvSide.controls.append(control) }
                }
                link.changed = { state in if state == .ready { link.send(.status(status)) } }
                tvSide.links.append(link)
                link.start()
            }
        }
        server.start(queue: .main)
        defer { server.cancel() }
        var port: NWEndpoint.Port?
        for _ in 0..<200 where port == nil {
            try await Task.sleep(for: .milliseconds(10))
            if case .ready = server.state { port = server.port }
        }
        let client = PlayLink(to: endpoint(try #require(port)), key: key, identity: identity)
        var statuses: [PlayStatus] = []
        client.received = { result in
            if case .success(.status(let status)) = result { statuses.append(status) }
        }
        client.changed = { state in if state == .ready { client.send(.control(.pause)) } }
        client.start()
        defer { client.close() }
        for _ in 0..<300 where statuses.isEmpty || tvSide.controls.isEmpty { try await Task.sleep(for: .milliseconds(10)) }
        #expect(statuses == [status])
        #expect(tvSide.controls == [.pause])
    }
}

/// What the test's stand-in TV saw, on the main actor.
@MainActor
private final class TVSide {
    var links: [PlayLink] = []
    var controls: [PlayControl] = []
}
