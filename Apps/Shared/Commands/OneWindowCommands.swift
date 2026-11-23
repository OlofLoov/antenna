#if os(macOS)
    import SwiftUI

    /// The Antuna windows open on the Mac. Each window's root view adds
    /// itself when it appears and removes itself when it disappears.
    @MainActor @Observable
    final class OpenWindows {
        private(set) var open: Set<UUID> = []

        func opened(_ id: UUID) { open.insert(id) }
        func closed(_ id: UUID) { open.remove(id) }
    }

    /// File > New Window, which opens a window only while none is open
    /// (live-tv-on-iphone-ipad-mac/one-window-on-the-mac). A second window
    /// would load every source again and open a second provider connection,
    /// which an account limited to one connection refuses.
    struct OneWindowCommands: Commands {
        let windows: OpenWindows
        @Environment(\.openWindow) private var openWindow

        var body: some Commands {
            CommandGroup(replacing: .newItem) {
                Button("New Window") { openWindow(id: AntennaApp.windowID) }
                    .keyboardShortcut("n", modifiers: .command)
                    .disabled(!windows.open.isEmpty)
            }
        }
    }

    /// Keeps the window it sits in listed in `windows` while it is on screen.
    struct CountedWindow: ViewModifier {
        let windows: OpenWindows
        @State private var id = UUID()

        func body(content: Content) -> some View {
            content
                .onAppear { windows.opened(id) }
                .onDisappear { windows.closed(id) }
        }
    }
#endif
