import SwiftUI

/// The board sizes and the text styles they map to
/// (design-system/type-uses-text-styles). A board gives a point size; the
/// view asks for `.boardStyle(size)` and gets the platform's text style
/// nearest that size, so text grows with the system and the board stays
/// the source of the hierarchy. On Apple TV nothing maps below Caption 2,
/// 23 pt, and on iPhone, iPad and Mac nothing below Caption 1, 12 pt
/// (design-system/text-stays-above-the-platform-caption-floor). The step
/// also gives the design: the two largest steps of each platform are
/// rounded and every other step is plain
/// (design-system/display-headings-are-rounded).
enum TypeScale {
    /// One text style, the point size it has at the default text size, and
    /// its design; nil is the plain system font.
    struct Step: Equatable, Sendable {
        let size: CGFloat
        let style: Font.TextStyle
        var design: Font.Design?
    }

    /// Apple TV: Title 1 76 and Title 2 57 rounded; Title 3 48, Headline 38,
    /// Callout 31, Body 29, Caption 1 25 and Caption 2 23 plain.
    static let television: [Step] = [
        Step(size: 23, style: .caption2), Step(size: 25, style: .caption), Step(size: 29, style: .body),
        Step(size: 31, style: .callout), Step(size: 38, style: .headline), Step(size: 48, style: .title3),
        Step(size: 57, style: .title2, design: .rounded), Step(size: 76, style: .title, design: .rounded),
    ]

    /// iPhone, iPad and Mac: Large Title 34 and Title 1 28 rounded; Title 2
    /// 22, Title 3 20, Body 17, Callout 16, Subheadline 15, Footnote 13 and
    /// Caption 1 12 plain.
    static let touch: [Step] = [
        Step(size: 12, style: .caption), Step(size: 13, style: .footnote), Step(size: 15, style: .subheadline),
        Step(size: 16, style: .callout), Step(size: 17, style: .body), Step(size: 20, style: .title3),
        Step(size: 22, style: .title2), Step(size: 28, style: .title, design: .rounded),
        Step(size: 34, style: .largeTitle, design: .rounded),
    ]

    /// The steps of the platform the app runs on.
    static var steps: [Step] {
        #if os(tvOS)
            television
        #else
            touch
        #endif
    }

    /// The step nearest `size`; a size halfway between two takes the larger.
    static func step(for size: CGFloat, in steps: [Step] = TypeScale.steps) -> Step {
        var best = steps[0]
        for step in steps where abs(step.size - size) <= abs(best.size - size) {
            best = step
        }
        return best
    }

    /// The style nearest `size`; a size halfway between two takes the larger.
    static func style(for size: CGFloat, in steps: [Step] = TypeScale.steps) -> Font.TextStyle {
        step(for: size, in: steps).style
    }

    /// The design of `style` on the platform; plain for a style its scale
    /// does not list.
    static func design(of style: Font.TextStyle, in steps: [Step] = TypeScale.steps) -> Font.Design? {
        steps.first { $0.style == style }?.design
    }
}

extension Font {
    /// The text style for a board's point size, with the board's weight and
    /// the step's design; see `TypeScale`.
    static func boardStyle(_ size: CGFloat, weight: Font.Weight? = nil) -> Font {
        let step = TypeScale.step(for: size)
        return .system(step.style, design: step.design, weight: weight)
    }

    /// A text style with the design the scale gives it, for a component
    /// that names a style instead of a board size.
    static func boardStyle(_ style: Font.TextStyle, weight: Font.Weight? = nil) -> Font {
        .system(style, design: TypeScale.design(of: style), weight: weight)
    }
}

private struct TypeScaleSample: View {
    let steps: [TypeScale.Step]
    let sample: String

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.Spacing.xSmall) {
            ForEach(steps.reversed(), id: \.size) { step in
                Text(verbatim: "\(Int(step.size)) \(sample)")
                    .font(.boardStyle(step.size, weight: .bold))
                    .foregroundStyle(Palette.text)
            }
        }
        .padding(Metrics.Spacing.large)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.ground)
    }
}

#Preview("Type scale") {
    TypeScaleSample(steps: TypeScale.steps, sample: "Unlock Antuna")
}

#Preview("Type scale, Arabic") {
    TypeScaleSample(steps: TypeScale.steps, sample: "افتح Antuna")
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.locale, Locale(identifier: "ar"))
}
