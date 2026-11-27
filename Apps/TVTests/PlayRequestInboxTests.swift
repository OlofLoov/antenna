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
        "play-on-apple-tv/the-tv-keeps-its-own-locks-and-profile: behind the paywall or Who's watching the request waits, then is offered")
    func keptBehindGates() {
        let inbox = PlayRequestInbox()
        var answers: [PlayAnswer.Result] = []
        let request = Self.request()
        inbox.receive(request) { answers.append($0) }
        #expect(answers == [.waiting])
        #expect(inbox.delivery?.request == nil)
        inbox.attach()
        #expect(inbox.offered == request, "a request kept behind a gate is offered once the shell shows")
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
        #expect(inbox.offered == second)
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
