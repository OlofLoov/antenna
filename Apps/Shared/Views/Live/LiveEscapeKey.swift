#if os(iOS)
    import SwiftUI
    import UIKit

    /// Escape on an iPad keyboard while the picture fills the window
    /// (live-tv-on-iphone-ipad-mac/keyboard-shortcuts). iPadOS keeps Escape
    /// for itself unless a key command asks for priority, which SwiftUI's
    /// shortcuts cannot, so an invisible view takes first responder and
    /// offers it. Full screen has no text field to take the keys from.
    struct LiveEscapeKey: UIViewRepresentable {
        let action: () -> Void

        func makeUIView(context: Context) -> KeyView {
            KeyView()
        }

        func updateUIView(_ view: KeyView, context: Context) {
            view.action = action
        }

        final class KeyView: UIView {
            var action: () -> Void = {}

            override var canBecomeFirstResponder: Bool { true }

            override func didMoveToWindow() {
                super.didMoveToWindow()
                if window != nil { DispatchQueue.main.async { self.becomeFirstResponder() } }
            }

            override var keyCommands: [UIKeyCommand]? {
                let escape = UIKeyCommand(input: UIKeyCommand.inputEscape, modifierFlags: [], action: #selector(pressed))
                escape.wantsPriorityOverSystemBehavior = true
                return [escape]
            }

            @objc private func pressed() { action() }
        }
    }
#endif
