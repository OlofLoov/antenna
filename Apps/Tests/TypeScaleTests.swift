import SwiftUI
import Testing

@testable import Antenna

/// The board sizes and the text styles they become.
@MainActor
struct TypeScaleTests {
    @Test("design-system/type-uses-text-styles a board size maps to the nearest text style on each platform")
    func nearestStyle() {
        #expect(TypeScale.style(for: 29, in: TypeScale.television) == .body)
        #expect(TypeScale.style(for: 76, in: TypeScale.television) == .title)
        #expect(TypeScale.style(for: 38, in: TypeScale.television) == .headline)
        #expect(TypeScale.style(for: 27, in: TypeScale.television) == .body, "halfway takes the larger")
        #expect(TypeScale.style(for: 17, in: TypeScale.touch) == .body)
        #expect(TypeScale.style(for: 34, in: TypeScale.touch) == .largeTitle)
        #expect(TypeScale.style(for: 14, in: TypeScale.touch) == .subheadline, "halfway takes the larger")
    }

    @Test("design-system/text-stays-above-the-platform-caption-floor small board sizes stop at the caption floor")
    func captionFloor() {
        #expect(TypeScale.style(for: 18, in: TypeScale.television) == .caption2)
        #expect(TypeScale.style(for: 20, in: TypeScale.television) == .caption2)
        #expect(TypeScale.style(for: 10, in: TypeScale.touch) == .caption)
        #expect(TypeScale.television.map(\.size).min() == 23)
        #expect(TypeScale.touch.map(\.size).min() == 12)
    }
}
