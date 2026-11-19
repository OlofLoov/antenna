#if os(tvOS)
    import SwiftUI

    extension EnvironmentValues {
        /// True while the highlight is in the Apple TV tab bar. Set by the shell.
        @Entry var shellBarFocused = false
    }

    /// Scrolls a tab's content back to the top when the highlight moves up
    /// into the system tab bar, by Back or by swiping up, so swiping down
    /// again lands on the first row (tvos-shell/back-from-a-tab-goes-to-the-tab-bar).
    struct ShellBackToTop: ViewModifier {
        /// The screen's own scroll position, when it scrolls the view too.
        var shared: Binding<ScrollPosition>?
        @Environment(\.shellBarFocused) private var barFocused
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @State private var own = ScrollPosition(edge: .top)

        func body(content: Content) -> some View {
            let position = shared ?? $own
            content
                .scrollPosition(position)
                .onChange(of: barFocused) { _, focused in
                    guard focused else { return }
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) {
                        position.wrappedValue.scrollTo(edge: .top)
                    }
                }
        }
    }

    extension View {
        /// Applied to a tab's scroll view; see `ShellBackToTop`.
        func scrollsToTopFromTabBar() -> some View {
            modifier(ShellBackToTop())
        }

        /// The same, for a screen that also moves `position` itself.
        func scrollsToTopFromTabBar(_ position: Binding<ScrollPosition>) -> some View {
            modifier(ShellBackToTop(shared: position))
        }
    }
#endif
