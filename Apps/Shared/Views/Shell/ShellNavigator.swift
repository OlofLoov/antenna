#if os(tvOS)
    import SwiftUI

    /// How other screens send the user somewhere in the Apple TV shell. The
    /// shell provides it; each call closes the channel picker first.
    struct ShellNavigator {
        enum Destination: Hashable, Sendable {
            case search
            /// The Guide, told which programme to show.
            case guide(programmeKey: ProgrammeKey)
        }

        var show: @MainActor (Destination) -> Void
        /// Live full screen with no tab bar, for example after a tune.
        var showLive: @MainActor () -> Void

        /// A navigator that forwards to `model`.
        @MainActor
        static func forwarding(to model: ShellModel) -> ShellNavigator {
            ShellNavigator(
                show: { destination in Task { await model.show(destination) } },
                showLive: { Task { await model.showLive() } }
            )
        }
    }

    extension EnvironmentValues {
        /// Set once by `ShellView`. Nil outside the shell.
        @Entry var shellNavigator: ShellNavigator? = .none
    }
#endif
