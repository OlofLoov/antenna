import Foundation

/// When the player controls go away
/// (live-tv-on-iphone-ipad-mac/player-controls-when-you-want-them).
enum ControlsTimer {
    /// What last kept the controls up.
    enum Input: Equatable {
        /// A tap, a click or a press on one of the controls.
        case touch
        /// The pointer moved over the picture.
        case pointerInside
        /// The pointer left the picture.
        case pointerLeft
    }

    /// How long a tap keeps the controls up while playing.
    static let touchHold = Duration.seconds(3)

    /// How long after `input` the controls hide, or nil while they stay:
    /// paused, or with the pointer over the picture.
    static func delay(after input: Input, isPaused: Bool, touchHold: Duration = touchHold) -> Duration? {
        guard !isPaused else { return nil }
        switch input {
        case .touch: return touchHold
        case .pointerInside: return nil
        case .pointerLeft: return .seconds(1)
        }
    }
}
