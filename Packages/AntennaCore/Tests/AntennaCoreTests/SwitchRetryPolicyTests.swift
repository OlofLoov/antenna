import AntennaCore
import Foundation
import Testing

/// Fails as scripted, then succeeds; counts the attempts.
private actor Scripted {
    private var failures: [PlaybackFailure]
    private(set) var count = 0

    init(_ failures: [PlaybackFailure]) {
        self.failures = failures
    }

    func next() throws -> Int {
        count += 1
        if !failures.isEmpty { throw failures.removeFirst() }
        return count
    }
}

/// The tune policy right after a channel from the same server closed
/// (playback-engine/a-channel-that-won-t-start-is-retried-briefly).
@Suite struct SwitchRetryPolicyTests {
    let now = ContinuousClock.now

    @Test(
        "playback-engine/a-channel-that-won-t-start-is-retried-briefly a refusal or timeout right after a switch gets one more try a second later",
        arguments: [PlaybackFailure.notAllowed, .timedOut, .refused(status: 458), .refused(status: 409)])
    func oneMoreTry(failure: PlaybackFailure) async throws {
        let sleeps = RecordedSleeps()
        let attempts = Scripted([failure])
        let value = try await RetryPolicy.tuneAfterSwitch.run(sleep: { await sleeps.sleep($0) }) { try await attempts.next() }
        #expect(value == 2)
        #expect(await sleeps.waits == [.seconds(1)])
    }

    @Test("playback-engine/a-channel-that-won-t-start-is-retried-briefly a second refusal after a switch fails with its reason")
    func onlyOnce() async {
        let attempts = Scripted([.notAllowed, .notAllowed, .notAllowed])
        await #expect(throws: PlaybackFailure.notAllowed) {
            try await RetryPolicy.tuneAfterSwitch.run(sleep: { _ in }) { try await attempts.next() }
        }
        #expect(await attempts.count == 2)
    }

    @Test(
        "playback-engine/a-channel-that-won-t-start-is-retried-briefly a missing or unreadable stream after a switch fails at once",
        arguments: [PlaybackFailure.notFound, .unreadable, .secureConnectionFailed])
    func notRetried(failure: PlaybackFailure) async {
        let attempts = Scripted([failure])
        await #expect(throws: failure) {
            try await RetryPolicy.tuneAfterSwitch.run(sleep: { _ in }) { try await attempts.next() }
        }
        #expect(await attempts.count == 1)
    }

    @Test("playback-engine/a-channel-that-won-t-start-is-retried-briefly busy servers are still tried 3 times after a switch")
    func busyStillRetried() async {
        let attempts = Scripted([.serverBusy, .serverBusy, .serverBusy])
        await #expect(throws: PlaybackFailure.serverBusy) {
            try await RetryPolicy.tuneAfterSwitch.run(sleep: { _ in }) { try await attempts.next() }
        }
        #expect(await attempts.count == 3)
    }

    @Test("playback-engine/a-channel-that-won-t-start-is-retried-briefly only a close on the same server within 3 seconds counts")
    func whatCountsAsASwitch() async {
        let closed = (host: Optional("panel.example"), at: now)
        #expect(await tries(RetryPolicy.tune(host: "panel.example", lastClosed: closed, now: now + .seconds(1))) == 2)
        #expect(await tries(RetryPolicy.tune(host: "panel.example", lastClosed: closed, now: now + .seconds(4))) == 1)
        #expect(await tries(RetryPolicy.tune(host: "other.example", lastClosed: closed, now: now + .seconds(1))) == 1)
        #expect(await tries(RetryPolicy.tune(host: "panel.example", lastClosed: nil, now: now)) == 1)
    }

    /// How many times `policy` asks for a stream the server keeps refusing.
    private func tries(_ policy: RetryPolicy) async -> Int {
        let attempts = Scripted([.notAllowed, .notAllowed, .notAllowed])
        _ = try? await policy.run(sleep: { _ in }) { try await attempts.next() }
        return await attempts.count
    }
}
