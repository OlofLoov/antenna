#if DEBUG && os(macOS)
    import AppKit
    import SwiftUI

    extension UITestingStoreShots {
        /// The window size of the Mac store set, in points: 1440 by 900, which
        /// the App Store takes as is and, at 2x, as 2880 by 1800.
        static let windowSize = CGSize(width: 1440, height: 900)

        /// Sizes the app's window to `windowSize` and centers it on a
        /// store-shot launch (polish-store-screenshots). Does nothing without
        /// the argument.
        struct WindowSize: ViewModifier {
            func body(content: Content) -> some View {
                content.onAppear {
                    guard UITestingStoreShots.isOn else { return }
                    Task { @MainActor in
                        guard let window = NSApp.windows.first(where: \.canBecomeMain) else { return }
                        window.setFrame(NSRect(origin: .zero, size: UITestingStoreShots.windowSize), display: true)
                        window.center()
                    }
                }
            }
        }
    }
#endif
