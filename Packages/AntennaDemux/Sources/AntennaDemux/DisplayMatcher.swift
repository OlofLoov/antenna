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
        /// the request; it is called only when one is needed.
        public func match(_ mode: DisplayMode, criteria: () -> AVDisplayCriteria?) {
            guard keeper.match(mode) else { return }
            screen.manager?.preferredDisplayCriteria = criteria()
        }
    #else
        public init(sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }) {
            keeper = DisplayModeKeeper(sleep: sleep) {}
        }
    #endif

    /// The mode the TV is in or switching to, nil when it is left alone.
    public var mode: DisplayMode? { keeper.mode }

    /// Playback stopped. The TV goes back to its own mode unless the next
    /// stream asks for one within a moment.
    public func letGo() {
        keeper.letGo()
    }
}
