#if os(tvOS)
    import SwiftUI

    /// Draws the label only: the full-screen picture holds focus with no
    /// visible card.
    struct HolderStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label.contentShape(Rectangle())
        }
    }
#endif
