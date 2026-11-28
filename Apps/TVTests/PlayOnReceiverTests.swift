import AntennaCore
import Foundation
import Testing

@testable import AntennaTV

/// The Apple TV picking up requests that waited in iCloud.
@MainActor
@Suite struct PlayOnReceiverTests {
    struct Rig {
        let receiver: PlayOnReceiver
        let queue: InMemoryPlayRequests
        let inbox: PlayRequestInbox
    }

    static func rig(_ waiting: [PlayRequest], tv: PlayOnDevice) -> Rig {
        let queue = InMemoryPlayRequests(waiting)
        let inbox = PlayRequestInbox()
        let receiver = PlayOnReceiver(inbox: inbox, device: tv, devices: InMemoryPlayDevices(), queue: queue, advertises: false)
        return Rig(receiver: receiver, queue: queue, inbox: inbox)
    }

    static func tv() throws -> PlayOnDevice {
        PlayOnDevice(
            id: UUID(), kind: .tv, name: "Living Room",
            keys: try PlayOnKeyPair(rawRepresentation: Data(repeating: 5, count: 32), keyDate: .now))
    }

    static func request(to target: UUID, item: PlayRequest.Item = .movie(key: "m"), sent: Date = .now) -> PlayRequest {
        PlayRequest(
            sender: UUID(), senderName: "Anna's iPhone", target: target, source: UUID(), item: item, displayTitle: "Salt Road",
            created: sent)
    }

    @Test("play-on-apple-tv/the-tv-counts-down-a-waiting-request: a waiting request is deleted and counted down")
    func countsDown() async throws {
        let tv = try Self.tv()
        let request = Self.request(to: tv.id)
        let rig = Self.rig([request], tv: tv)
        rig.inbox.attach()
        await rig.receiver.pickUp()
        #expect(rig.inbox.countdown?.request == request)
        #expect(await rig.queue.all.isEmpty)
        rig.inbox.tick(now: .now.addingTimeInterval(PlayCountdown.length))
        #expect(rig.inbox.countdown == nil)
        #expect(rig.inbox.take()?.request == request)
    }

    @Test("play-on-apple-tv/the-tv-counts-down-a-waiting-request: Cancel leaves the TV where it was")
    func cancel() async throws {
        let tv = try Self.tv()
        let rig = Self.rig([Self.request(to: tv.id)], tv: tv)
        rig.inbox.attach()
        await rig.receiver.pickUp()
        rig.inbox.cancelCountdown()
        #expect(rig.inbox.countdown == nil)
        #expect(rig.inbox.take()?.request == nil)
    }

    @Test("play-on-apple-tv/the-tv-counts-down-a-waiting-request: a request for another TV is not counted down")
    func otherTV() async throws {
        let tv = try Self.tv()
        let bedroom = Self.request(to: UUID())
        let rig = Self.rig([bedroom], tv: tv)
        await rig.receiver.pickUp()
        #expect(rig.inbox.countdown == nil)
        #expect(await rig.queue.all == [bedroom])
    }

    @Test("play-on-apple-tv/requests-expire-and-leave-no-trace: a live channel sent an hour ago is deleted with no countdown")
    func expired() async throws {
        let tv = try Self.tv()
        let old = Self.request(to: tv.id, item: .channel(key: "c"), sent: .now.addingTimeInterval(-3600))
        let rig = Self.rig([old], tv: tv)
        await rig.receiver.pickUp()
        #expect(rig.inbox.countdown == nil)
        #expect(await rig.queue.all.isEmpty)
    }

    @Test("play-on-apple-tv/requests-expire-and-leave-no-trace: a film sent in the afternoon is deleted with no countdown")
    func oldFilm() async throws {
        let tv = try Self.tv()
        let old = Self.request(to: tv.id, sent: .now.addingTimeInterval(-3 * 3600))
        let rig = Self.rig([old], tv: tv)
        rig.inbox.attach()
        await rig.receiver.pickUp()
        #expect(rig.inbox.countdown == nil)
        #expect(await rig.queue.all.isEmpty)
    }

    @Test("play-on-apple-tv/waits-in-icloud-when-the-tv-is-not-reachable: a request sent both ways plays once")
    func bothWaysPlaysOnce() async throws {
        let tv = try Self.tv()
        let request = Self.request(to: tv.id)
        let rig = Self.rig([request], tv: tv)
        rig.inbox.attach()
        rig.inbox.receive(request) { _ in }
        #expect(rig.inbox.take()?.request == request)
        await rig.receiver.pickUp()
        #expect(rig.inbox.countdown == nil)
        #expect(await rig.queue.all.isEmpty)
    }
}
