#if os(tvOS)
    import AntennaCore
    import Foundation
    import Observation

    /// When the Apple TV info bar shows (tv-zap-bar-and-number-entry capability). Any
    /// channel change shows it, and it hides five seconds after the last
    /// change; play/pause shows it or keeps it five more seconds; Menu and
    /// select hide it at once.
    @MainActor @Observable
    final class ZapBarModel {
        static let showFor = Duration.seconds(5)

        private(set) var isVisible = false
        /// The channel the bar describes.
        private(set) var channel: Channel?

        @ObservationIgnored private let sleep: @MainActor (Duration) async throws -> Void
        @ObservationIgnored private var hideTimer: Task<Void, Never>?

        init(sleep: @escaping @MainActor (Duration) async throws -> Void = { try await Task.sleep(for: $0) }) {
            self.sleep = sleep
        }

        /// The tuned channel changed: show the bar for `channel`, updating in place.
        func channelChanged(to channel: Channel?) {
            self.channel = channel
            guard channel != nil else { return hide() }
            show()
        }

        /// Play/pause in full-screen live TV.
        func playPause() {
            guard channel != nil else { return }
            show()
        }

        /// While `on`, the bar stays up, as during the user's pause; after
        /// it, the bar hides five seconds later.
        func keep(_ on: Bool) {
            guard channel != nil else { return }
            kept = on
            show()
        }

        @ObservationIgnored private var kept = false

        /// Menu or select while the bar shows. False when it was not showing,
        /// so the press goes on to the shell.
        @discardableResult
        func dismiss() -> Bool {
            guard isVisible else { return false }
            hide()
            return true
        }

        private func show() {
            isVisible = true
            hideTimer?.cancel()
            guard !kept else { return }
            hideTimer = Task { [weak self, sleep] in
                do {
                    try await sleep(Self.showFor)
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                self?.isVisible = false
            }
        }

        private func hide() {
            hideTimer?.cancel()
            hideTimer = nil
            isVisible = false
        }
    }
#endif
