import AntennaCore
import Foundation
import Network
import Observation
import Testing

@testable import Antenna

/// The phone's side of Play on against a scripted TV: which TVs show, when
/// the browser starts, and what a send does.
@MainActor
@Suite struct PlayDestinationTests {
    static let now = Date(timeIntervalSince1970: 1_800_000_000)
    static let livingRoom = UUID()
    static let bedroom = UUID()

    final class Browser: PlayOnBrowsing {
        var endpoints: [UUID: NWEndpoint] = [:]
        var denied = false
        var starts = 0
        var found: [UUID] = []

        func start() {
            starts += 1
            for id in found { endpoints[id] = .hostPort(host: "127.0.0.1", port: 9) }
        }

        func stop() {
            endpoints = [:]
        }
    }

    final class Sender: PlayOnSending {
        var outcomes: [PlaySendOutcome]
        var sent: [PlayRequest] = []
        /// Read when a request goes out.
        var onSend: () -> Void = {}

        init(_ outcomes: [PlaySendOutcome]) {
            self.outcomes = outcomes
        }

        /// Links handed back with an answer, in order; none leaves the phone unconnected.
        var links: [FakeLink] = []

        func send(_ request: PlayRequest, to tv: PlayDeviceInfo, at endpoint: NWEndpoint, within limit: Duration) async -> PlaySend {
            onSend()
            sent.append(request)
            let outcome = outcomes.isEmpty ? PlaySendOutcome.answered(.started) : outcomes.removeFirst()
            guard case .answered = outcome, !links.isEmpty else { return PlaySend(outcome: outcome) }
            return PlaySend(outcome: outcome, link: links.removeFirst())
        }

        func connect(to tv: PlayDeviceInfo, at endpoint: NWEndpoint, within limit: Duration) async -> (any PlayOnLinking)? {
            links.isEmpty ? nil : links.removeFirst()
        }
    }

    /// The phone's end of a link to a scripted TV: it keeps what was sent,
    /// and the test plays the TV's side with `tv(_:)`.
    final class FakeLink: PlayOnLinking {
        var received: @MainActor (Result<PlayMessage, PlayMessage.DecodeError>) -> Void = { _ in }
        func listen(_ handler: @escaping @MainActor (Result<PlayMessage, PlayMessage.DecodeError>) -> Void) { received = handler }
        var changed: @MainActor (PlayLink.State) -> Void = { _ in }
        var sent: [PlayMessage] = []
        var closed = false
        /// What the TV answers a `play` with, sent back at once; nil sends nothing.
        var answer: PlayAnswer.Result? = .started

        func send(_ message: PlayMessage) {
            sent.append(message)
            if case .play(let request) = message, let answer { tv(.answer(PlayAnswer(requestID: request.id, result: answer))) }
        }

        func close() {
            closed = true
        }

        /// A frame from the TV.
        func tv(_ message: PlayMessage) {
            received(.success(message))
        }

        /// The TV's end of the link drops.
        func drop() {
            changed(.ended(.unreachable))
        }
    }

    static func tv(_ id: UUID, _ name: String, created: TimeInterval = 0) -> PlayDeviceInfo {
        PlayDeviceInfo(
            id: id, kind: .tv, name: name, publicKey: Data([4]), keyDate: now, lastSeen: now, created: Date(timeIntervalSince1970: created))
    }

    struct Rig {
        let destination: PlayDestination
        let browser: Browser
        let sender: Sender
        let devices: InMemoryPlayDevices
        let defaults: UserDefaults
        let gate: StreamGate
    }

    static func rig(
        _ tvs: [PlayDeviceInfo], found: [UUID] = [livingRoom], outcomes: [PlaySendOutcome] = [],
        stopLocal: @escaping @MainActor () async -> Void = {}
    ) throws -> Rig {
        let defaults = try #require(UserDefaults(suiteName: "play-destination-\(UUID().uuidString)"))
        let browser = Browser()
        let gate = StreamGate()
        browser.found = found
        let sender = Sender(outcomes)
        let fixed = now
        let devices = InMemoryPlayDevices(tvs, now: { fixed })
        let device = PlayOnDevice(
            id: UUID(), kind: .phone, name: "Anna's iPhone",
            keys: try PlayOnKeyPair(rawRepresentation: Data(repeating: 3, count: 32), keyDate: now))
        var dependencies = PlayDestination.Dependencies(devices: devices, browser: browser, sender: sender, device: device)
        dependencies.stopLocal = stopLocal
        dependencies.gate = gate
        dependencies.stoppedShows = .milliseconds(10)
        dependencies.now = { now }
        dependencies.sleep = { _ in }
        dependencies.defaults = defaults
        dependencies.locale = Locale(identifier: "en_US")
        return Rig(
            destination: PlayDestination(dependencies), browser: browser, sender: sender, devices: devices, defaults: defaults, gate: gate)
    }

    static let channel = PlayOnItem(item: .channel(key: "4f1c"), source: UUID(), title: "Sport One", sourceName: "Acme TV")

    @Test("play-on-apple-tv/apple-tvs-on-the-same-icloud-account: no Apple TV on the account, no Play on")
    func noTV() async throws {
        let rig = try Self.rig([])
        await rig.destination.activate()
        #expect(rig.destination.choice == nil)
        rig.destination.opened()
        #expect(rig.browser.starts == 0)
    }

    @Test("play-on-apple-tv/apple-tvs-on-the-same-icloud-account: each TV says whether it starts now, ready ones first")
    func rows() async throws {
        let rig = try Self.rig([Self.tv(Self.bedroom, "Bedroom", created: 1), Self.tv(Self.livingRoom, "Living Room", created: 2)])
        await rig.destination.activate()
        rig.destination.opened()
        let choice = try #require(rig.destination.choice)
        #expect(choice.rows.map(\.name) == ["Living Room", "Bedroom"])
        #expect(choice.rows.map(\.ready) == [true, false])
        #expect(!choice.accessRefused)
    }

    @Test("play-on-apple-tv/the-local-network-is-asked-for-only-when-needed: the browser starts on the first Play on and on later launches")
    func browsesOnlyAfterOpening() async throws {
        let rig = try Self.rig([Self.tv(Self.livingRoom, "Living Room")])
        await rig.destination.activate()
        #expect(rig.browser.starts == 0)
        rig.destination.opened()
        #expect(rig.browser.starts == 1)
        rig.destination.deactivate()
        await rig.destination.activate()
        #expect(rig.browser.starts == 2)
    }

    @Test("play-on-apple-tv/the-local-network-is-asked-for-only-when-needed: access refused lists every TV as waiting with a Settings row")
    func refused() async throws {
        let rig = try Self.rig([Self.tv(Self.livingRoom, "Living Room")])
        rig.browser.denied = true
        await rig.destination.activate()
        let choice = try #require(rig.destination.choice)
        #expect(choice.rows.map(\.ready) == [false])
        #expect(choice.accessRefused)
    }

    @Test("play-on-apple-tv/starts-at-once-on-the-same-network: the phone stops its stream before the request goes out")
    func stopsBeforeSending() async throws {
        let engine = PlayerTestEngine()
        engine.send(.playing)
        let rig = try Self.rig([Self.tv(Self.livingRoom, "Living Room")]) { await engine.stop() }
        var stateAtSend: PlaybackState?
        rig.sender.onSend = { stateAtSend = engine.state }
        await rig.destination.activate()
        await rig.destination.send(Self.channel, to: Self.livingRoom)
        #expect(stateAtSend == .idle)
        #expect(rig.sender.sent.count == 1)
        #expect(rig.destination.notice?.text == "Playing on Living Room")
        #expect(rig.destination.notice?.kind == .sent)
    }

    @Test("play-on-apple-tv/a-request-holds-no-link-and-no-login: the request carries the item's key, the names and this device")
    func requestFields() async throws {
        let rig = try Self.rig([Self.tv(Self.livingRoom, "Living Room")])
        await rig.destination.activate()
        await rig.destination.send(Self.channel, to: Self.livingRoom)
        let sent = try #require(rig.sender.sent.first)
        #expect(sent.item == .channel(key: "4f1c"))
        #expect(sent.target == Self.livingRoom)
        #expect(sent.senderName == "Anna's iPhone")
        #expect(sent.created == Self.now)
    }

    @Test(
        "play-on-apple-tv/only-the-same-account-can-send-over-the-network: a refused handshake reads the devices again and tries once more")
    func retriesOnce() async throws {
        let rig = try Self.rig([Self.tv(Self.livingRoom, "Living Room")], outcomes: [.refused, .answered(.started)])
        await rig.destination.activate()
        let before = await rig.devices.fetches
        await rig.destination.send(Self.channel, to: Self.livingRoom)
        #expect(rig.sender.sent.count == 2)
        #expect(await rig.devices.fetches > before)
        #expect(rig.destination.notice?.kind == .sent)
    }

    @Test("play-on-apple-tv/the-phone-says-why-the-tv-cannot-play: each refusal reads in words")
    func refusals() async throws {
        let source = UUID()
        struct Case {
            var answer: PlayAnswer.Result
            var text: String
            var kind: PlayOnNotice.Kind
        }
        let cases = [
            Case(answer: .needsPasscode, text: "Enter the passcode on Living Room.", kind: .error),
            Case(answer: .noLogin(source: source), text: "Living Room isn't signed in to Acme TV.", kind: .error),
            Case(answer: .noSource(source: source), text: "Living Room doesn't have Acme TV yet. Try again in a minute.", kind: .error),
            Case(answer: .notFound, text: "Living Room couldn't find Sport One.", kind: .error),
            Case(answer: .unsupportedVersion, text: "Update Antuna on Living Room to play from here.", kind: .error),
            Case(answer: .waiting, text: "Sent. Living Room plays it once Antuna is ready there.", kind: .sent),
        ]
        for check in cases {
            let rig = try Self.rig([Self.tv(Self.livingRoom, "Living Room")], outcomes: [.answered(check.answer)])
            await rig.destination.activate()
            await rig.destination.send(Self.channel, to: Self.livingRoom)
            #expect(rig.destination.notice?.text == check.text)
            #expect(rig.destination.notice?.kind == check.kind)
        }
    }

    @Test("play-on-apple-tv/apple-tvs-on-the-same-icloud-account: each device writes its own record when the scene becomes active")
    func publishes() async throws {
        let rig = try Self.rig([Self.tv(Self.livingRoom, "Living Room")])
        await rig.destination.activate()
        let all = try await rig.devices.all()
        #expect(all.contains { $0.kind == .phone && $0.name == "Anna's iPhone" })
    }
}
