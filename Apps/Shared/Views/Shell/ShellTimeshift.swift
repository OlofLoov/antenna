#if os(tvOS)
    import AntennaCore
    import SwiftUI
    import UIKit

    /// Timeshift on full-screen Apple TV live TV
    /// (timeshift-catch-up-and-start-over capability): holding play/pause
    /// goes to live, holding left or right scans, the zap bar stays while
    /// the user's pause lasts, and notices show over the picture. `active`
    /// is false while the overlay, number entry, the guide or a panel is
    /// open, so the remote keeps its usual meaning there.
    struct ShellTimeshift: ViewModifier {
        let timeshift: TimeshiftModel
        let zapBar: ZapBarModel
        let active: Bool

        func body(content: Content) -> some View {
            content
                .background {
                    RemoteHolds(
                        active: active, holdForLive: timeshift.limits.holdForLive, holdToScan: timeshift.limits.clickLimit,
                        live: { timeshift.holdForLive() },
                        scan: { forward in timeshift.beginScan(forward: forward) },
                        endScan: { timeshift.endScan() }
                    )
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
                .overlay(alignment: .top) {
                    if let notice = timeshift.notice {
                        Timeshift.Notice(text: notice, size: 28)
                            .padding(.top, 60)
                    }
                }
                .onChange(of: timeshift.userPaused) { _, paused in
                    zapBar.keep(paused)
                }
        }
    }

    /// Long presses of play/pause, left and right on the Siri Remote, seen
    /// by recognizers on the window so they work whatever has focus.
    private struct RemoteHolds: UIViewRepresentable {
        let active: Bool
        let holdForLive: Duration
        let holdToScan: Duration
        let live: () -> Void
        let scan: (_ forward: Bool) -> Void
        let endScan: () -> Void

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
            coordinator.live = live
            coordinator.scan = scan
            coordinator.endScan = endScan
            coordinator.configure(holdForLive: holdForLive / .seconds(1), holdToScan: holdToScan / .seconds(1))
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
            var live: () -> Void = {}
            var scan: (Bool) -> Void = { _ in }
            var endScan: () -> Void = {}
            private let playPause = UILongPressGestureRecognizer()
            private let left = UILongPressGestureRecognizer()
            private let right = UILongPressGestureRecognizer()
            private weak var window: UIWindow?

            override init() {
                super.init()
                playPause.allowedPressTypes = [NSNumber(value: UIPress.PressType.playPause.rawValue)]
                left.allowedPressTypes = [NSNumber(value: UIPress.PressType.leftArrow.rawValue)]
                right.allowedPressTypes = [NSNumber(value: UIPress.PressType.rightArrow.rawValue)]
                for recognizer in [playPause, left, right] {
                    recognizer.cancelsTouchesInView = false
                    recognizer.delegate = self
                }
                playPause.addTarget(self, action: #selector(heldPlayPause(_:)))
                left.addTarget(self, action: #selector(heldArrow(_:)))
                right.addTarget(self, action: #selector(heldArrow(_:)))
            }

            func configure(holdForLive: Double, holdToScan: Double) {
                playPause.minimumPressDuration = holdForLive
                left.minimumPressDuration = holdToScan
                right.minimumPressDuration = holdToScan
            }

            func attach(to window: UIWindow?) {
                guard window !== self.window else { return }
                detach()
                self.window = window
                for recognizer in [playPause, left, right] { window?.addGestureRecognizer(recognizer) }
            }

            func detach() {
                for recognizer in [playPause, left, right] { recognizer.view?.removeGestureRecognizer(recognizer) }
                window = nil
            }

            nonisolated func gestureRecognizer(
                _ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
            ) -> Bool {
                true
            }

            @objc private func heldPlayPause(_ recognizer: UILongPressGestureRecognizer) {
                guard active, recognizer.state == .began else { return }
                live()
            }

            @objc private func heldArrow(_ recognizer: UILongPressGestureRecognizer) {
                guard active || recognizer.state != .began else { return }
                switch recognizer.state {
                case .began: scan(recognizer === right)
                case .ended, .cancelled, .failed: endScan()
                default: break
                }
            }
        }
    }
#endif
