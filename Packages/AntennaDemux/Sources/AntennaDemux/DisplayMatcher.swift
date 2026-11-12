import AntennaCore
import CoreMedia
import Foundation

#if os(tvOS)
    import AVKit
#endif

/// The TV's frame rate and dynamic range on Apple TV, shared by both
/// playback paths so a channel change between them keeps the TV's mode when
/// both channels need the same one. Does nothing on iPhone, iPad and Mac.
@MainActor
public final class DisplayMatcher {
    let keeper: DisplayModeKeeper

    #if os(tvOS)
        private final class Screen {
            weak var manager: AVDisplayManager?
        }

        private let screen: Screen

        /// The display manager of the window the picture is in.
        public var displayManager: AVDisplayManager? {
            get { screen.manager }
            set { screen.manager = newValue }
        }

        public init(sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }) {
            let screen = Screen()
            self.screen = screen
            keeper = DisplayModeKeeper(sleep: sleep) { screen.manager?.preferredDisplayCriteria = nil }
        }

        /// Asks the TV for `mode` when it is in another one. `criteria` makes
        /// the request; it is called only when one is needed. While
        /// `appliesDisplayCriteria` is false the request waits.
        public func match(_ mode: DisplayMode, criteria: () -> AVDisplayCriteria?) {
            guard appliesDisplayCriteria else {
                pending = (mode, criteria())
                return
            }
            guard keeper.match(mode) else { return }
            screen.manager?.preferredDisplayCriteria = criteria()
        }

        private var pending: (mode: DisplayMode, criteria: AVDisplayCriteria?)?

        private func applyPending() {
            guard let pending else { return }
            self.pending = nil
            guard keeper.match(pending.mode) else { return }
            screen.manager?.preferredDisplayCriteria = pending.criteria
        }
    #else
        private func applyPending() {}

        public init(sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }) {
            keeper = DisplayModeKeeper(sleep: sleep) {}
        }
    #endif

    /// False leaves the TV's frame rate and dynamic range as they are, as
    /// multi-view tiles do (multi-view/start-multi-view-on-apple-tv). A mode
    /// asked for meanwhile is applied once it turns true again.
    public var appliesDisplayCriteria = true {
        didSet {
            if appliesDisplayCriteria, !oldValue { applyPending() }
        }
    }

    /// The mode the TV is in or switching to, nil when it is left alone.
    public var mode: DisplayMode? { keeper.mode }

    /// Playback stopped. The TV goes back to its own mode unless the next
    /// stream asks for one within a moment.
    public func letGo() {
        guard appliesDisplayCriteria else { return }
        keeper.letGo()
    }
}
