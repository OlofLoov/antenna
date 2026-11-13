#if os(tvOS)
    import SwiftUI
    import UIKit

    /// Clicks left and right and slides on the Siri Remote while a movie or
    /// episode plays, seen by recognizers on the window
    /// (player-controls-and-playback-errors/move-around-in-a-movie-or-episode).
    /// SwiftUI's move command cannot tell a click from a swipe, and here a
    /// click skips while a slide moves the target.
    /// `active` is false while the audio and subtitles panel is open, so the
    /// remote moves focus there as usual.
    struct TitleRemote: UIViewRepresentable {
        let active: Bool
        let click: (_ forward: Bool) -> Void
        let slideBegan: () -> Void
        /// How far the finger moved since it came down, as a share of the surface's width.
        let slid: (_ share: Double) -> Void
        let slideEnded: () -> Void

        func makeCoordinator() -> Coordinator { Coordinator() }

        func makeUIView(context: Context) -> WindowWatcher {
            let view = WindowWatcher()
            view.isUserInteractionEnabled = false
            view.attached = { window in context.coordinator.attach(to: window) }
            return view
        }

        func updateUIView(_ view: WindowWatcher, context: Context) {
            let coordinator = context.coordinator
            coordinator.active = active
            coordinator.click = click
            coordinator.slideBegan = slideBegan
            coordinator.slid = slid
            coordinator.slideEnded = slideEnded
        }

        static func dismantleUIView(_ view: WindowWatcher, coordinator: Coordinator) {
            coordinator.detach()
        }

        final class WindowWatcher: UIView {
            var attached: ((UIWindow?) -> Void)?

            override func didMoveToWindow() {
                super.didMoveToWindow()
                attached?(window)
            }
        }

        @MainActor
        final class Coordinator: NSObject, UIGestureRecognizerDelegate {
            var active = false
            var click: (Bool) -> Void = { _ in }
            var slideBegan: () -> Void = {}
            var slid: (Double) -> Void = { _ in }
            var slideEnded: () -> Void = {}
            private let left = UITapGestureRecognizer()
            private let right = UITapGestureRecognizer()
            private let pan = UIPanGestureRecognizer()
            private weak var window: UIWindow?

            override init() {
                super.init()
                left.allowedPressTypes = [NSNumber(value: UIPress.PressType.leftArrow.rawValue)]
                right.allowedPressTypes = [NSNumber(value: UIPress.PressType.rightArrow.rawValue)]
                pan.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.indirect.rawValue)]
                for recognizer in [left, right, pan] {
                    recognizer.cancelsTouchesInView = false
                    recognizer.delegate = self
                }
                left.addTarget(self, action: #selector(clicked(_:)))
                right.addTarget(self, action: #selector(clicked(_:)))
                pan.addTarget(self, action: #selector(panned(_:)))
            }

            func attach(to window: UIWindow?) {
                guard window !== self.window else { return }
                detach()
                self.window = window
                for recognizer in [left, right, pan] { window?.addGestureRecognizer(recognizer) }
            }

            func detach() {
                for recognizer in [left, right, pan] { recognizer.view?.removeGestureRecognizer(recognizer) }
                window = nil
            }

            nonisolated func gestureRecognizer(
                _ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
            ) -> Bool {
                true
            }

            @objc private func clicked(_ recognizer: UITapGestureRecognizer) {
                guard active, recognizer.state == .ended else { return }
                click(recognizer === right)
            }

            @objc private func panned(_ recognizer: UIPanGestureRecognizer) {
                guard active || recognizer.state != .began, let view = recognizer.view else { return }
                switch recognizer.state {
                case .began:
                    slideBegan()
                case .changed:
                    slid(recognizer.translation(in: view).x / max(1, view.bounds.width))
                case .ended, .cancelled, .failed:
                    slideEnded()
                default:
                    break
                }
            }
        }
    }
#endif
