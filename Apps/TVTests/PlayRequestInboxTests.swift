import AntennaCore
import Foundation
import Testing

@testable import AntennaTV

/// Requests arriving on the Apple TV before and while the shell shows.
@MainActor
@Suite struct PlayRequestInboxTests {
    static func request(_ title: String = "Sport One") -> PlayRequest {
        PlayRequest(
            sender: UUID(), senderName: "Anna's iPhone", target: UUID(), source: UUID(), item: .channel(key: "4f1c"), displayTitle: title,
            created: .now)
    }

    @Test(
        "play-on-apple-tv/the-tv-keeps-its-own-locks-and-profile: behind the paywall or Who's watching the request waits, then counts down")
    func keptBehindGates() {
        let inbox = PlayRequestInbox()
        var answers: [PlayAnswer.Result] = []
        let request = Self.request()
        inbox.receive(request) { answers.append($0) }
        #expect(answers == [.waiting])
        #expect(inbox.delivery?.request == nil)
        inbox.attach()
        #expect(inbox.countdown?.request == request, "a request kept behind a gate counts down once the shell shows")
        #expect(inbox.take()?.request == nil)

    }

    @Test("play-on-apple-tv/starts-at-once-on-the-same-network: with the shell up a request goes straight to it")
    func deliveredWhileShown() {
        let inbox = PlayRequestInbox()
        inbox.attach()
        var answers: [PlayAnswer.Result] = []
        let request = Self.request()
        inbox.receive(request) { answers.append($0) }
        let delivery = inbox.take()
        #expect(delivery?.request == request)
        delivery?.reply(.started)
        #expect(answers == [.started])
    }

    @Test("play-on-apple-tv/starts-at-once-on-the-same-network: the same request arriving twice plays once")
    func playsOnce() {
        let inbox = PlayRequestInbox()
        inbox.attach()
        let request = Self.request()
        inbox.receive(request) { _ in }
        _ = inbox.take()
        var again: [PlayAnswer.Result] = []
        inbox.receive(request) { again.append($0) }
        #expect(again == [.started])
        #expect(inbox.take()?.request == nil)
    }

    @Test("play-on-apple-tv/the-tv-keeps-its-own-locks-and-profile: only the newest kept request plays after a gate")
    func newestKept() {
        let inbox = PlayRequestInbox()
        inbox.receive(Self.request("Sport One")) { _ in }
        let second = Self.request("News")
        inbox.receive(second) { _ in }
        inbox.detach()
        inbox.attach()
        #expect(inbox.countdown?.request == second)
    }

    static let start = Date(timeIntervalSince1970: 1_800_000_000)

    static func counting(_ request: PlayRequest = request()) -> PlayRequestInbox {
        let inbox = PlayRequestInbox()
        inbox.attach(now: start)
        inbox.offer(request, now: start)
        return inbox
    }

    @Test("play-on-apple-tv/the-tv-counts-down-a-waiting-request: the countdown plays by itself after five seconds")
    func countsDownAndPlays() {
        let request = Self.request("Salt Road")
        let inbox = Self.counting(request)
        #expect(inbox.countdown?.secondsLeft(at: Self.start) == 5)
        inbox.tick(now: Self.start.addingTimeInterval(4.9))
        #expect(inbox.take()?.request == nil, "nothing plays before the five seconds are over")
        inbox.tick(now: Self.start.addingTimeInterval(5))
        #expect(inbox.countdown == nil)
        #expect(inbox.take()?.request == request)
    }

    @Test("play-on-apple-tv/the-tv-counts-down-a-waiting-request: Cancel or Menu stops it and nothing plays")
    func cancels() {
        let inbox = Self.counting()
        inbox.cancelCountdown()
        inbox.tick(now: Self.start.addingTimeInterval(10))
        #expect(inbox.countdown == nil)
        #expect(inbox.take()?.request == nil)
    }

    @Test("play-on-apple-tv/the-tv-counts-down-a-waiting-request: Play now plays at once")
    func playsNow() {
        let request = Self.request()
        let inbox = Self.counting(request)
        inbox.playNow()
        #expect(inbox.countdown == nil)
        #expect(inbox.take()?.request == request)
    }

    @Test("play-on-apple-tv/the-tv-counts-down-a-waiting-request: a request that expires during the countdown still plays")
    func expiresWhileCounting() {
        let sent = Self.start.addingTimeInterval(-58)
        let request = PlayRequest(
            sender: UUID(), senderName: "Anna's iPhone", target: UUID(), source: UUID(), item: .movie(key: "m"), displayTitle: "Salt Road",
            created: sent)
        let inbox = Self.counting(request)
        let end = Self.start.addingTimeInterval(5)
        #expect(request.isExpired(at: end))
        inbox.tick(now: end)
        #expect(inbox.take()?.request == request)
    }

    @Test("play-on-apple-tv/requests-expire-and-leave-no-trace: a request kept behind a gate past its minute does not count down")
    func keptPastItsMinute() {
        let inbox = PlayRequestInbox()
        let request = Self.request()
        inbox.receive(request) { _ in }
        inbox.attach(now: request.created.addingTimeInterval(61))
        #expect(inbox.countdown == nil)
    }

    @Test("play-on-apple-tv/the-tv-counts-down-a-waiting-request: the countdown waits for the shell, then starts from 5")
    func waitsForTheShell() {
        let inbox = PlayRequestInbox()
        let request = PlayRequest(
            sender: UUID(), senderName: "Anna's iPhone", target: UUID(), source: UUID(), item: .movie(key: "m"), displayTitle: "Salt Road",
            created: Self.start)
        inbox.offer(request, now: Self.start)
        #expect(inbox.countdown == nil, "no countdown behind a gate")
        let later = Self.start.addingTimeInterval(20)
        inbox.attach(now: later)
        #expect(inbox.countdown?.secondsLeft(at: later) == 5)
        inbox.detach()
        #expect(inbox.countdown == nil, "it goes back to waiting when the shell goes")
    }

    @Test("play-on-apple-tv/the-phone-can-take-a-request-back: a phone's cancel drops a countdown, a kept request or one not seen yet")
    func phoneCancel() {
        let counting = Self.request()
        let inbox = Self.counting(counting)
        #expect(inbox.cancel(counting.id))
        #expect(inbox.countdown == nil)

        let gated = PlayRequestInbox()
        let kept = Self.request()
        gated.receive(kept) { _ in }
        #expect(gated.cancel(kept.id))
        gated.attach()
        #expect(gated.countdown == nil, "nothing counts down after a profile is chosen")

        let unseen = Self.request()
        #expect(inbox.cancel(unseen.id))
        inbox.offer(unseen)
        #expect(inbox.countdown == nil, "a request canceled before it arrived never plays")

        let played = Self.request()
        inbox.receive(played) { _ in }
        _ = inbox.take()
        #expect(!inbox.cancel(played.id), "too late once it played")
    }

    @Test("play-on-apple-tv/starts-at-once-on-the-same-network: the banner names the sending device and the item")
    func banner() {
        let inbox = PlayRequestInbox()
        inbox.announce(Self.request("Salt Road"), locale: Locale(identifier: "en_US"))
        #expect(inbox.banner?.eyebrow == "From Anna's iPhone")
        #expect(inbox.banner?.line == "Salt Road")
        inbox.announce(Self.request(), reason: "Living Room isn't signed in to Acme TV.", locale: Locale(identifier: "en_US"))
        #expect(inbox.banner?.line == "Living Room isn't signed in to Acme TV.")
    }
}
