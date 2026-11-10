import AntennaCore
import Foundation
import Testing

@testable import AntennaTV

/// When the Apple TV info bar shows and hides, on a clock advanced by hand.
@MainActor
@Suite(.timeLimit(.minutes(1))) struct ZapBarModelTests {
    let clock = ManualClock()
    let model: ZapBarModel

    init() {
        let clock = clock
        model = ZapBarModel(sleep: { try await clock.sleep($0) })
    }

    private func settle() async {
        for _ in 0..<200 { await Task.yield() }
    }

    @Test("tv-zap-bar-and-number-entry/the-bar-appears-on-every-channel-change a channel change shows it for five seconds")
    func showsForFiveSeconds() async {
        model.channelChanged(to: .fixture("a1"))
        #expect(model.isVisible)
        #expect(model.channel == .fixture("a1"))
        await settle()
        clock.advance(by: .seconds(4))
        await settle()
        #expect(model.isVisible)
        clock.advance(by: .seconds(1))
        await settle()
        #expect(!model.isVisible)
    }

    @Test("tv-zap-bar-and-number-entry/the-bar-appears-on-every-channel-change fast flipping hides five seconds after the last change")
    func fastFlipping() async {
        model.channelChanged(to: .fixture("a1"))
        await settle()
        clock.advance(by: .seconds(3))
        model.channelChanged(to: .fixture("a2"))
        await settle()
        clock.advance(by: .seconds(3))
        model.channelChanged(to: .fixture("a3"))
        #expect(model.channel == .fixture("a3"), "the bar updates in place")
        await settle()
        clock.advance(by: .seconds(4))
        await settle()
        #expect(model.isVisible)
        clock.advance(by: .seconds(1))
        await settle()
        #expect(!model.isVisible)
    }

    @Test("tv-zap-bar-and-number-entry/play-pause-shows-the-bar shows the bar or keeps it five more seconds")
    func playPause() async {
        model.channelChanged(to: .fixture("a1"))
        await settle()
        clock.advance(by: .seconds(5))
        await settle()
        #expect(!model.isVisible)
        model.playPause()
        #expect(model.isVisible, "play/pause shows the hidden bar")
        await settle()
        clock.advance(by: .seconds(4))
        model.playPause()
        await settle()
        clock.advance(by: .seconds(4))
        await settle()
        #expect(model.isVisible, "a second press keeps it five more seconds")
        clock.advance(by: .seconds(1))
        await settle()
        #expect(!model.isVisible)
    }

    @Test("tv-zap-bar-and-number-entry/menu-hides-the-bar Menu hides it once and then lets the press through")
    func dismiss() async {
        model.channelChanged(to: .fixture("a1"))
        #expect(model.dismiss(), "the press is taken while the bar shows")
        #expect(!model.isVisible)
        #expect(!model.dismiss(), "with the bar hidden the press goes on to the shell")
        await settle()
        clock.advance(by: .seconds(5))
        await settle()
        #expect(!model.isVisible)
    }

    @Test("tv-zap-bar-and-number-entry/play-pause-shows-the-bar nothing tuned, nothing shown")
    func nothingTuned() {
        model.playPause()
        #expect(!model.isVisible)
        model.channelChanged(to: .fixture("a1"))
        model.channelChanged(to: nil)
        #expect(!model.isVisible)
    }
}
