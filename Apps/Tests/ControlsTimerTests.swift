import Testing

@testable import Antenna

#if os(iOS) || os(macOS)
    @Suite struct ControlsTimerTests {
        @Test("live-tv-on-iphone-ipad-mac/player-controls-when-you-want-them: three seconds after a touch, one after the pointer leaves")
        func delays() {
            #expect(ControlsTimer.delay(after: .touch, isPaused: false) == .seconds(3))
            #expect(ControlsTimer.delay(after: .pointerLeft, isPaused: false) == .seconds(1))
            #expect(ControlsTimer.delay(after: .pointerInside, isPaused: false) == nil, "they stay while the pointer is over the picture")
        }

        @Test("live-tv-on-iphone-ipad-mac/player-controls-when-you-want-them: paused, the controls stay")
        func paused() {
            #expect(ControlsTimer.delay(after: .touch, isPaused: true) == nil)
            #expect(ControlsTimer.delay(after: .pointerLeft, isPaused: true) == nil)
        }
    }
#endif
