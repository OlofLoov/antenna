#if os(tvOS)
    import SwiftUI
    import UIKit

    /// Where the highlight went, as the focus system reports it.
    enum ShellHighlight: Equatable {
        /// In the system tab bar.
        case bar
        /// On the open page or a layer over it.
        case page
        /// Nowhere, as when the focused view went away.
        case lost
    }

    /// Reports where the highlight moves. SwiftUI on Apple TV has no focus
    /// callback for a page as a whole, so this watches the focus system and
    /// asks whether the newly focused item sits in a `UITabBar`.
    struct ShellBarFocus: ViewModifier {
        let changed: (ShellHighlight) -> Void

        func body(content: Content) -> some View {
            content
                .onReceive(NotificationCenter.default.publisher(for: UIFocusSystem.didUpdateNotification)) { note in
                    guard let context = note.userInfo?[UIFocusSystem.focusUpdateContextUserInfoKey] as? UIFocusUpdateContext
                    else { return }
                    guard let item = context.nextFocusedItem else { return changed(.lost) }
                    changed(Self.isInTabBar(item) ? .bar : .page)
                }
        }

        /// Where the highlight is now, read from the window's focus system.
        /// The focus system does not always post an update when the focused
        /// view goes away, so the shell asks after the moments that remove one.
        @MainActor static func current() -> ShellHighlight {
            let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
            guard let item = scene?.focusSystem?.focusedItem else { return .lost }
            return isInTabBar(item) ? .bar : .page
        }

        private static func isInTabBar(_ item: any UIFocusItem) -> Bool {
            var environment: (any UIFocusEnvironment)? = item
            while let current = environment {
                if current is UITabBar { return true }
                environment = current.parentFocusEnvironment
            }
            return false
        }
    }

    /// Keeps the highlight where the shell wants it around the system tab
    /// bar: select on the open tab sends it onto the page, a highlight that
    /// went nowhere comes back to the page, and Live opened from code starts
    /// on the picture even when the focus engine first tries the bar.
    struct ShellFocusKeeper: ViewModifier {
        let model: ShellModel
        let focus: FocusState<ShellFocus?>.Binding
        /// The pages' focus scope, which `resetFocus` works in.
        let pages: Namespace.ID
        @Environment(\.resetFocus) private var resetFocus
        /// True while nothing has the highlight, as after the focused view went away.
        @State private var lost = false
        /// When Live last opened from code rather than from the tab bar.
        @State private var liveOpenedByCode = ContinuousClock.now - .seconds(10)

        func body(content: Content) -> some View {
            content
                .modifier(ShellBarFocus(changed: moved))
                .onChange(of: model.reselects) { _, _ in enterPage() }
                .onChange(of: model.tab) { _, tab in
                    guard !model.barFocused else { return }
                    // Live opened from code, as by a pick in the Guide or Search, starts on the picture.
                    if tab == .live { liveOpenedByCode = .now }
                    checkSoon()
                }
                .onChange(of: focus.wrappedValue == nil) { _, none in
                    if none, !model.barFocused { checkSoon() }
                }
                // The shell can appear with the first highlight in the bar, as after "Who's watching?".
                .task {
                    try? await Task.sleep(for: .milliseconds(400))
                    if model.tab == .live, ShellBarFocus.current() != .page { focus.wrappedValue = model.liveFocus }
                }
        }

        private func moved(_ highlight: ShellHighlight) {
            if highlight == .bar, model.tab == .live, ContinuousClock.now - liveOpenedByCode < .milliseconds(800) {
                // The focus engine put the highlight in the bar on its way to the picture.
                focus.wrappedValue = model.liveFocus
                return
            }
            // Down from the bar onto a failed stream loads it again, as select on Live does
            // (tvos-shell/back-to-full-screen-from-the-tab-bar).
            if model.barFocused, highlight == .page, model.tab == .live, model.player.failure != nil, let tuned = model.tuned {
                model.tune(tuned)
            }
            model.barFocused = highlight == .bar
            lost = highlight == .lost
            if lost { recover() }
        }

        /// Select on the open tab moves the highlight onto its page, as
        /// swiping down does. The search keyboard cannot take focus from code.
        private func enterPage() {
            switch model.tab {
            case .live: focus.wrappedValue = model.liveFocus
            case .guide, .movies, .series: focus.wrappedValue = .content
            case .search, .settings: break
            }
            Task {
                try? await Task.sleep(for: .milliseconds(150))
                if model.barFocused || lost { resetFocus(in: pages) }
            }
        }

        /// Recovers the highlight a moment after a tab opened from code or a
        /// focused view may have gone, when it turns out to be nowhere.
        private func checkSoon() {
            Task {
                try? await Task.sleep(for: .milliseconds(250))
                guard ShellBarFocus.current() == .lost else { return }
                lost = true
                recover()
            }
        }

        /// The highlight went nowhere, as when a tab opened from code or the
        /// focused row went away. It goes to the page's first place.
        private func recover() {
            Task {
                try? await Task.sleep(for: .milliseconds(150))
                // Multi-view and the sign-in step are covers with focus of their own.
                guard ShellBarFocus.current() == .lost, model.multiView == nil, model.signInRequest == nil else { return }
                if model.liveInFront, !model.pickerOpen, model.player.panel == nil {
                    focus.wrappedValue = model.liveFocus
                } else {
                    resetFocus(in: pages)
                }
            }
        }
    }
#endif
