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

    @Test("design-system/display-headings-are-rounded the two largest steps of each platform are rounded, the rest plain")
    func roundedSteps() {
        let rounded = { (steps: [TypeScale.Step]) in steps.filter { $0.design == .rounded }.map(\.size) }
        #expect(rounded(TypeScale.touch) == [28, 34])
        #expect(rounded(TypeScale.television) == [57, 76])
        #expect(TypeScale.touch.allSatisfy { $0.design == nil || $0.design == .rounded })
        #expect(TypeScale.television.allSatisfy { $0.design == nil || $0.design == .rounded })
    }

    @Test("design-system/display-headings-are-rounded a board size and a text style get the design of their step")
    func designFollowsTheStep() {
        #expect(TypeScale.step(for: 25, in: TypeScale.touch).design == .rounded, "halfway to Title 1 takes Title 1")
        #expect(TypeScale.step(for: 24, in: TypeScale.touch).design == nil)
        #expect(TypeScale.step(for: 40, in: TypeScale.touch).design == .rounded)
        #expect(TypeScale.step(for: 53, in: TypeScale.television).design == .rounded, "halfway to Title 2 takes Title 2")
        #expect(TypeScale.step(for: 48, in: TypeScale.television).design == nil)
        #expect(TypeScale.design(of: .title, in: TypeScale.touch) == .rounded)
        #expect(TypeScale.design(of: .title2, in: TypeScale.touch) == nil)
        #expect(TypeScale.design(of: .title2, in: TypeScale.television) == .rounded)
        #expect(TypeScale.design(of: .largeTitle, in: TypeScale.television) == nil, "not in the Apple TV scale")
        #expect(TypeScale.design(of: .body, in: TypeScale.television) == nil)
        #expect(Font.boardStyle(34, weight: .bold) == .system(.largeTitle, design: .rounded, weight: .bold))
        #expect(Font.boardStyle(17) == .system(.body, design: nil, weight: nil))
        #expect(Font.boardStyle(.title, weight: .bold) == .system(.title, design: .rounded, weight: .bold))
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
