#if os(iOS) || os(macOS)
    import SwiftUI

    extension View {
        /// A swipe in from the leading edge calls `back`, as on a pushed page:
        /// from the left in English, from the right in a right-to-left language
        /// (title-detail-and-episode-picker/back-to-where-you-were).
        func edgeSwipeBack(_ back: @escaping () -> Void) -> some View {
            modifier(EdgeSwipeBack(back: back))
        }
    }

    private struct EdgeSwipeBack: ViewModifier {
        let back: () -> Void
        @Environment(\.layoutDirection) private var direction
        @State private var width: CGFloat = 0

        func body(content: Content) -> some View {
            content
                .onGeometryChange(for: CGFloat.self) {
                    $0.size.width
                } action: {
                    width = $0
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 20)
                        .onEnded { drag in
                            let across = direction.towardTrailing(drag.translation.width)
                            guard direction.fromLeading(drag.startLocation.x, in: width) < 28, across > 80,
                                abs(drag.translation.height) < across
                            else { return }
                            back()
                        })
        }
    }
#endif
