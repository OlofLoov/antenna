import SwiftUI

extension EnvironmentValues {
    /// Goes up by one each time the user taps the tab that is already open,
    /// on iPhone and in a narrow iPad window. The tab's screen scrolls back
    /// to its top on each change
    /// (live-tv-on-iphone-ipad-mac/tap-the-open-tab-to-go-back-to-the-top).
    /// Stays 0 on Apple TV and in the sidebar layout.
    @Entry var tabTaps = 0
}

/// Scrolls a tab's scroll view back to its top when `tabTaps` changes.
struct ScrollsToTopOnTabTap: ViewModifier {
    @Environment(\.tabTaps) private var taps
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var position = ScrollPosition(edge: .top)

    func body(content: Content) -> some View {
        content
            .scrollPosition($position)
            .onChange(of: taps) { _, _ in
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) {
                    position.scrollTo(edge: .top)
                }
            }
    }
}

extension View {
    /// Applied to a tab's scroll view on iPhone and iPad; see `ScrollsToTopOnTabTap`.
    func scrollsToTopOnTabTap() -> some View {
        modifier(ScrollsToTopOnTabTap())
    }
}
