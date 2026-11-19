import SwiftUI

/// SwiftUI mirrors what it draws in a right-to-left language, offsets and
/// positions included, but a touch, a pointer, an arrow key and a Siri
/// Remote press still report the physical side of the screen. These turn
/// that side into the side the layout draws, so input lands where the
/// viewer sees it (design-system/focus-moves-where-the-remote-points).
extension LayoutDirection {
    /// `x`, measured from the left of a view `width` wide, measured from
    /// its leading edge instead.
    func fromLeading(_ x: CGFloat, in width: CGFloat) -> CGFloat {
        self == .rightToLeft ? width - x : x
    }

    /// A sideways distance, positive toward the trailing edge.
    func towardTrailing(_ distance: CGFloat) -> CGFloat {
        self == .rightToLeft ? -distance : distance
    }

    /// Whether something on the right side of the screen, or the right
    /// arrow, points toward the trailing edge: true in a left-to-right
    /// language, false in a right-to-left one.
    func isTrailing(right: Bool) -> Bool {
        right != (self == .rightToLeft)
    }

    /// The arrow key that points toward the leading edge.
    var leadingArrow: KeyEquivalent { self == .rightToLeft ? .rightArrow : .leftArrow }

    /// The arrow key that points toward the trailing edge.
    var trailingArrow: KeyEquivalent { self == .rightToLeft ? .leftArrow : .rightArrow }
}

#if os(tvOS) || os(macOS)
    extension MoveCommandDirection {
        /// The move with left meaning toward the leading edge and right
        /// toward the trailing edge, so code written for English reads it
        /// the same in a right-to-left language.
        func reading(_ direction: LayoutDirection) -> MoveCommandDirection {
            guard direction == .rightToLeft else { return self }
            switch self {
            case .left: return .right
            case .right: return .left
            default: return self
            }
        }
    }
#endif

extension View {
    /// Letter spacing for the uppercase labels and badges. Arabic letters
    /// join to their neighbours, and spacing pulls them apart, so a
    /// right-to-left layout gets none.
    func letterSpacing(_ value: CGFloat) -> some View {
        modifier(LetterSpacing(value: value))
    }
}

private struct LetterSpacing: ViewModifier {
    let value: CGFloat
    @Environment(\.layoutDirection) private var direction

    func body(content: Content) -> some View {
        content.tracking(direction == .rightToLeft ? 0 : value)
    }
}
