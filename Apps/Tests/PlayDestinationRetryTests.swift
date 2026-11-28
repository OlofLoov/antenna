import AntennaCore
import Foundation
import Testing

@testable import Antenna

/// The phone trying the network again before iCloud, and taking a request
/// back, against the scripted TV of `PlayDestinationTests`.
@MainActor
@Suite struct PlayDestinationRetryTests {
    // MARK: Fallback

    @Test("play-on-apple-tv/starts-at-once-on-the-same-network: a refused handshake is tried twice more before iCloud")
    func refusedThreeTimes() async throws {
        let rig = try PlayDestinationTests.rig(
            [PlayDestinationTests.tv(PlayDestinationTests.livingRoom, "Living Room")], outcomes: [.refused, .refused, .refused])
        await rig.destination.activate()
        let before = await rig.devices.fetches
        await rig.destination.send(PlayDestinationTests.channel, to: PlayDestinationTests.livingRoom)
        #expect(rig.sender.sent.count == 3)
        #expect(await rig.devices.fetches >= before + 2, "the device list is read again before each new try")
        #expect(Set(rig.sender.sent.map(\.id)).count == 1, "the same request each time, so the TV plays it once")
    }

    @Test("play-on-apple-tv/starts-at-once-on-the-same-network: the iPhone app was restarted, and the second try gets through")
    func restartedPhone() async throws {
        let rig = try PlayDestinationTests.rig(
            [PlayDestinationTests.tv(PlayDestinationTests.livingRoom, "Living Room")], outcomes: [.refused, .refused, .answered(.started)])
        await rig.destination.activate()
        await rig.destination.send(PlayDestinationTests.channel, to: PlayDestinationTests.livingRoom)
        #expect(rig.sender.sent.count == 3)
        #expect(rig.destination.notice?.text == "Playing on Living Room")
    }

    @Test("play-on-apple-tv/starts-at-once-on-the-same-network: a dropped connection is tried again")
    func droppedConnection() async throws {
        let rig = try PlayDestinationTests.rig(
            [PlayDestinationTests.tv(PlayDestinationTests.livingRoom, "Living Room")], outcomes: [.unreachable, .answered(.started)])
        await rig.destination.activate()
        await rig.destination.send(PlayDestinationTests.channel, to: PlayDestinationTests.livingRoom)
        #expect(rig.sender.sent.count == 2)
        #expect(rig.destination.notice?.kind == .sent)
    }

    @Test("play-on-apple-tv/starts-at-once-on-the-same-network: no answer and no TV on the network are not tried again")
    func noRetry() async throws {
        let silent = try PlayDestinationTests.rig(
            [PlayDestinationTests.tv(PlayDestinationTests.livingRoom, "Living Room")], outcomes: [.noAnswer])
        await silent.destination.activate()
        await silent.destination.send(PlayDestinationTests.channel, to: PlayDestinationTests.livingRoom)
        #expect(silent.sender.sent.count == 1)
        let absent = try PlayDestinationTests.rig([PlayDestinationTests.tv(PlayDestinationTests.livingRoom, "Living Room")], found: [])
        await absent.destination.activate()
        await absent.destination.send(PlayDestinationTests.channel, to: PlayDestinationTests.livingRoom)
        #expect(absent.sender.sent.isEmpty)
    }

    @Test("play-on-apple-tv/starts-at-once-on-the-same-network: the phone browses before it reads iCloud")
    func browsesFirst() async throws {
        let rig = try PlayDestinationTests.rig([PlayDestinationTests.tv(PlayDestinationTests.livingRoom, "Living Room")])
        rig.destination.browsing = true
        await rig.devices.fail(with: .busy)
        await rig.destination.activate()
        #expect(rig.browser.starts == 1, "the browser runs before, and without, an answer from iCloud")
    }

    // MARK: Cancel

    @Test("play-on-apple-tv/the-phone-can-take-a-request-back: a request the TV keeps behind a gate is taken back over the network")
    func cancelKept() async throws {
        let rig = try PlayDestinationTests.rig(
            [PlayDestinationTests.tv(PlayDestinationTests.livingRoom, "Living Room")], outcomes: [.answered(.waiting)])
        await rig.destination.activate()
        await rig.destination.send(PlayDestinationTests.channel, to: PlayDestinationTests.livingRoom)
        let id = try #require(rig.sender.sent.first?.id)
        #expect(rig.destination.notice?.cancel == id)
        await rig.destination.cancel()
        #expect(rig.sender.canceled == [id])
        #expect(rig.destination.notice?.text == "Canceled.")
        #expect(rig.destination.notice?.cancel == nil)
    }

    @Test("play-on-apple-tv/the-phone-can-take-a-request-back: too late, the phone says the TV already has it")
    func cancelTooLate() async throws {
        let rig = try PlayDestinationTests.rig(
            [PlayDestinationTests.tv(PlayDestinationTests.livingRoom, "Living Room")], outcomes: [.answered(.waiting)])
        rig.sender.cancelAnswer = false
        await rig.destination.activate()
        await rig.destination.send(PlayDestinationTests.channel, to: PlayDestinationTests.livingRoom)
        await rig.destination.cancel()
        #expect(rig.destination.notice?.text == "Living Room already has it.")
    }

    @Test("play-on-apple-tv/the-phone-can-take-a-request-back: a request that started at once has no Cancel")
    func noCancelAfterStart() async throws {
        let rig = try PlayDestinationTests.rig([PlayDestinationTests.tv(PlayDestinationTests.livingRoom, "Living Room")])
        await rig.destination.activate()
        await rig.destination.send(PlayDestinationTests.channel, to: PlayDestinationTests.livingRoom)
        #expect(rig.destination.notice?.cancel == nil)
        await rig.destination.cancel()
        #expect(rig.sender.canceled.isEmpty)
    }
}
