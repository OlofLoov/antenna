import AntennaCore
import Foundation
import Testing

/// When a movie or episode saves its place.
@Suite struct PositionSavingTests {
    let start = ContinuousClock.now

    private func at(_ seconds: Double) -> ContinuousClock.Instant { start + .seconds(seconds) }

    private func film(_ seconds: Double, of length: Double = 6_000) -> PlaybackPosition {
        PlaybackPosition(time: .seconds(seconds), duration: .seconds(length), isLive: false)
    }

    @Test("movies-and-series-browsing/your-place-is-saved-as-you-watch every 30 seconds while it plays")
    func everyThirtySeconds() {
        var saving = PositionSaving()
        #expect(saving.state(.playing, at: at(0)) == nil)
        #expect(saving.position(film(100), at: at(10)) == nil)
        #expect(saving.position(film(119), at: at(29)) == nil)
        #expect(saving.position(film(120), at: at(30)) == film(120))
        #expect(saving.position(film(130), at: at(40)) == nil, "the next save is 30 seconds after this one")
        #expect(saving.position(film(150), at: at(60)) == film(150))
    }

    @Test("movies-and-series-browsing/your-place-is-saved-as-you-watch pausing, stopping and leaving save at once")
    func pauseAndLeave() {
        var saving = PositionSaving()
        _ = saving.state(.playing, at: at(0))
        _ = saving.position(film(42), at: at(5))
        #expect(saving.state(.paused, at: at(6)) == film(42))
        #expect(saving.position(film(42), at: at(100)) == nil, "nothing while paused")
        _ = saving.state(.playing, at: at(200))
        _ = saving.position(film(50), at: at(208))
        #expect(saving.position(film(60), at: at(220)) == nil, "the 30 seconds count from playing again")
        #expect(saving.leaving(at: at(221)) == film(60))
    }

    @Test("movies-and-series-browsing/your-place-is-saved-as-you-watch the end saves the whole length, live TV saves nothing")
    func endAndLive() {
        var saving = PositionSaving()
        _ = saving.state(.playing, at: at(0))
        _ = saving.position(film(5_990), at: at(1))
        #expect(saving.state(.ended, at: at(2))?.time == .seconds(6_000))

        var live = PositionSaving()
        _ = live.state(.playing, at: at(0))
        let channel = PlaybackPosition(time: .seconds(40), duration: nil, isLive: true)
        #expect(live.position(channel, at: at(1)) == nil)
        #expect(live.position(channel, at: at(60)) == nil)
        #expect(live.state(.paused, at: at(61)) == nil)
        #expect(live.leaving(at: at(62)) == nil)
    }

    @Test("movies-and-series-browsing/your-place-is-saved-as-you-watch nothing to save before the first position")
    func nothingYet() {
        var saving = PositionSaving()
        #expect(saving.state(.paused, at: at(0)) == nil)
        #expect(saving.leaving(at: at(1)) == nil)
        #expect(saving.state(.buffering, at: at(2)) == nil)
    }
}
