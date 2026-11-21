#if os(iOS)
    import SwiftUI
    import UIKit

    /// Puts the screen around it in the responder chain, so its
    /// `keyboardShortcut` buttons answer the keyboard before anything has
    /// been tapped. Until a view in the window is first responder, iPadOS
    /// asks only the window and the app for key commands, and SwiftUI's
    /// shortcuts live below the window; on iPadOS 26 the first arrow
    /// presses after launch did nothing. An invisible view takes first
    /// responder when it appears and again each time `isActive` turns on.
    /// A text field that takes the keyboard keeps it.
    struct KeyboardAnchor: UIViewRepresentable {
        var isActive = true

        func makeUIView(context: Context) -> AnchorView {
            AnchorView()
        }

        func updateUIView(_ view: AnchorView, context: Context) {
            view.setActive(isActive)
        }

        final class AnchorView: UIView {
            private var isActive = true

            override var canBecomeFirstResponder: Bool { isActive }

            override func didMoveToWindow() {
                super.didMoveToWindow()
                if window != nil { claim() }
            }

            func setActive(_ active: Bool) {
                guard active != isActive else { return }
                isActive = active
                if active { claim() }
            }

            private func claim() {
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.isActive, self.window != nil else { return }
                    self.becomeFirstResponder()
                }
            }
        }
    }
#else
    import SwiftUI

    /// The Mac window keeps its responder chain, so there is nothing to anchor.
    struct KeyboardAnchor: View {
        var isActive = true

        var body: some View { EmptyView() }
    }
#endif
