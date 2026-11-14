#if os(tvOS)
    import SwiftUI

    extension EnvironmentValues {
        /// True while the highlight is in the Apple TV tab bar. Set by the shell.
        @Entry var shellBarFocused = false
    }

    /// Back in the shell. With the highlight in the bar, Back is left to the
    /// system, which goes to the Home Screen
    /// (tvos-shell/back-from-the-tab-bar-goes-to-the-home-screen); anywhere
    /// else `menu` handles it.
    struct ShellBack: ViewModifier {
        let barFocused: Bool
        let menu: () -> Void

        private var action: (() -> Void)? {
            barFocused ? nil : menu
        }

        func body(content: Content) -> some View {
            content
                .onExitCommand(perform: action)
                .environment(\.shellBarFocused, barFocused)
        }
    }

    /// Scrolls a tab's content back to the top when the highlight moves up
    /// into the tab bar, by Back or by swiping up, so swiping down again
    /// lands on the first row (tvos-shell/back-from-a-tab-goes-to-the-tab-bar).
    struct ShellBackToTop: ViewModifier {
        @Environment(\.shellBarFocused) private var barFocused
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @State private var position = ScrollPosition(edge: .top)

        func body(content: Content) -> some View {
            content
                .scrollPosition($position)
                .onChange(of: barFocused) { _, focused in
                    guard focused else { return }
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) {
                        position.scrollTo(edge: .top)
                    }
                }
        }
    }

    extension View {
        /// Applied to a tab's scroll view; see `ShellBackToTop`.
        func scrollsToTopFromTabBar() -> some View {
            modifier(ShellBackToTop())
        }
    }
#endif
