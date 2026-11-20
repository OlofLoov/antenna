import AntennaCore
import Testing

struct HeldPressTests {
    @Test("tvos-shell/one-press-does-one-thing the release of a hold is not also a click")
    func releaseOfAHold() {
        var press = HeldPress()
        let start = ContinuousClock.now
        let plainClick = press.takeRelease(at: start)
        press.held(at: start)
        let release = press.takeRelease(at: start + .milliseconds(400))
        let nextClick = press.takeRelease(at: start + .milliseconds(600))
        #expect(!plainClick, "a click with no hold is a click")
        #expect(release, "the release of the hold")
        #expect(!nextClick, "the next click is a click again")
    }

    @Test("tvos-shell/one-press-does-one-thing a click long after a hold is a click")
    func clickAfterTheWindow() {
        var press = HeldPress()
        let start = ContinuousClock.now
        press.held(at: start)
        let late = press.takeRelease(at: start + HeldPress.releaseWindow)
        #expect(!late)
    }
}
