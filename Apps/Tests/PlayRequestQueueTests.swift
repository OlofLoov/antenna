import AntennaCore
import Foundation
import Network
import Testing

#if os(tvOS)
    @testable import AntennaTV
#else
    @testable import Antenna
#endif

/// The iCloud queue for requests a TV could not take over the network, on
/// the in-memory store. Runs in both the iOS and tvOS unit tests.
@Suite struct PlayRequestQueueTests {
    static let now = Date(timeIntervalSince1970: 1_800_000_000)
    static let livingRoom = UUID()
    static let bedroom = UUID()

    static let film = PlayRequest.Item.movie(key: "m")

    static func request(_ title: String, to target: UUID = livingRoom, item: PlayRequest.Item = film, sent: Date = now) -> PlayRequest {
        PlayRequest(
            sender: UUID(), senderName: "Anna's iPhone", target: target, source: UUID(), item: item, displayTitle: title, created: sent)
    }

    @Test("play-on-apple-tv/waits-in-icloud-when-the-tv-is-not-reachable: a second request replaces the first")
    func replaces() async throws {
        let queue = InMemoryPlayRequests()
        try await queue.save(Self.request("Salt Road"))
        let second = Self.request("Harbour")
        try await queue.save(second)
        try await queue.save(Self.request("News", to: Self.bedroom))
        #expect(try await queue.waiting(for: Self.livingRoom) == second)
        #expect(await queue.all.count == 2)
    }

    @Test("play-on-apple-tv/requests-expire-and-leave-no-trace: deleting an old request leaves the newer one")
    func deletesOnlyItsOwn() async throws {
        let first = Self.request("Salt Road")
        let queue = InMemoryPlayRequests([first])
        let second = Self.request("Harbour")
        try await queue.save(second)
        try await queue.delete(first)
        #expect(try await queue.waiting(for: Self.livingRoom) == second)
        try await queue.delete(second)
        #expect(try await queue.waiting(for: Self.livingRoom) == nil)
    }

    @Test("play-on-apple-tv/requests-expire-and-leave-no-trace: the sweep deletes what expired and keeps the rest")
    func sweeps() async throws {
        let channel = Self.request("Sport One", item: .channel(key: "c"), sent: Self.now.addingTimeInterval(-3600))
        let film = Self.request("Salt Road", to: Self.bedroom, sent: Self.now.addingTimeInterval(-3 * 3600))
        let queue = InMemoryPlayRequests([channel, film])
        #expect(try await queue.sweep(now: Self.now) == 1)
        #expect(try await queue.waiting(for: Self.livingRoom) == nil)
        #expect(try await queue.waiting(for: Self.bedroom) == film)
    }
}

#if !os(tvOS)
    /// The phone falling back to iCloud.
    @MainActor
    @Suite struct PlayDestinationQueueTests {
        static let now = PlayRequestQueueTests.now
        static let livingRoom = PlayRequestQueueTests.livingRoom

        static func destination(
            reachable: Bool, outcome: PlaySendOutcome = .answered(.started), queue: InMemoryPlayRequests
        ) throws -> (PlayDestination, PlayDestinationTests.Sender) {
            let browser = PlayDestinationTests.Browser()
            browser.found = reachable ? [livingRoom] : []
            let sender = PlayDestinationTests.Sender([outcome, outcome])
            let device = PlayOnDevice(
                id: UUID(), kind: .phone, name: "Anna's iPhone",
                keys: try PlayOnKeyPair(rawRepresentation: Data(repeating: 3, count: 32), keyDate: now))
            let fixed = now
            var dependencies = PlayDestination.Dependencies(
                devices: InMemoryPlayDevices([PlayDestinationTests.tv(livingRoom, "Living Room")], now: { fixed }), browser: browser,
                sender: sender, device: device, queue: queue)
            dependencies.stopLocal = {}
            dependencies.gate = StreamGate()
            dependencies.now = { now }
            dependencies.sleep = { _ in }
            dependencies.defaults = try #require(UserDefaults(suiteName: "play-queue-\(UUID().uuidString)"))
            dependencies.locale = Locale(identifier: "en_US")
            return (PlayDestination(dependencies), sender)
        }

        static let film = PlayOnItem(item: .movie(key: "m"), source: UUID(), title: "Salt Road", sourceName: "Acme TV", start: 2400)

        @Test("play-on-apple-tv/waits-in-icloud-when-the-tv-is-not-reachable: a TV that is not open gets the request through iCloud")
        func closedTV() async throws {
            let queue = InMemoryPlayRequests()
            let (destination, sender) = try Self.destination(reachable: false, queue: queue)
            await destination.activate()
            await destination.send(Self.film, to: Self.livingRoom)
            #expect(sender.sent.isEmpty)
            #expect(destination.notice?.text == "Sent. Living Room offers it when Antuna opens there.")
            #expect(destination.notice?.kind == .sent)
            let waiting = try #require(try await queue.waiting(for: Self.livingRoom))
            #expect(waiting.item == .movie(key: "m"))
            #expect(waiting.startPosition == 2400)
        }

        @Test("play-on-apple-tv/starts-at-once-on-the-same-network: no answer on the network goes through iCloud instead")
        func noAnswer() async throws {
            let queue = InMemoryPlayRequests()
            let (destination, sender) = try Self.destination(reachable: true, outcome: .noAnswer, queue: queue)
            await destination.activate()
            await destination.send(Self.film, to: Self.livingRoom)
            #expect(sender.sent.count == 1)
            // The same request, so a TV that took it from the network plays it once.
            #expect(try await queue.waiting(for: Self.livingRoom)?.id == sender.sent.first?.id)
            #expect(destination.notice?.text == "Sent. Living Room offers it when Antuna opens there.")
        }

        @Test("play-on-apple-tv/waits-in-icloud-when-the-tv-is-not-reachable: offline, nothing is sent")
        func offline() async throws {
            let queue = InMemoryPlayRequests(failure: .offline)
            let (destination, _) = try Self.destination(reachable: false, queue: queue)
            await destination.activate()
            await destination.send(Self.film, to: Self.livingRoom)
            #expect(destination.notice?.text == "You're offline. Nothing was sent.")
            #expect(destination.notice?.kind == .error)
            await queue.fail(with: nil)
            #expect(try await queue.waiting(for: Self.livingRoom) == nil)
        }

        @Test("play-on-apple-tv/requests-expire-and-leave-no-trace: the phone deletes expired requests when it opens")
        func phoneSweeps() async throws {
            let old = PlayRequestQueueTests.request("Sport One", item: .channel(key: "c"), sent: Self.now.addingTimeInterval(-3600))
            let queue = InMemoryPlayRequests([old])
            let (destination, _) = try Self.destination(reachable: false, queue: queue)
            await destination.activate()
            #expect(await queue.all.isEmpty)
        }
    }
#endif
