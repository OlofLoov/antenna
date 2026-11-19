import SwiftUI

/// The board sizes and the text styles they map to
/// (design-system/type-uses-text-styles). A board gives a point size; the
/// view asks for `.boardStyle(size)` and gets the platform's text style
/// nearest that size, so text grows with the system and the board stays
/// the source of the hierarchy. On Apple TV nothing maps below Caption 2,
/// 23 pt, and on iPhone, iPad and Mac nothing below Caption 1, 12 pt
/// (design-system/text-stays-above-the-platform-caption-floor).
enum TypeScale {
    /// One text style and the point size it has at the default text size.
    struct Step: Equatable, Sendable {
        let size: CGFloat
        let style: Font.TextStyle
    }

    /// Apple TV: Title 1 76, Title 2 57, Title 3 48, Headline 38, Callout
    /// 31, Body 29, Caption 1 25, Caption 2 23.
    static let television: [Step] = [
        Step(size: 23, style: .caption2), Step(size: 25, style: .caption), Step(size: 29, style: .body),
        Step(size: 31, style: .callout), Step(size: 38, style: .headline), Step(size: 48, style: .title3),
        Step(size: 57, style: .title2), Step(size: 76, style: .title),
    ]

    /// iPhone, iPad and Mac: Caption 1 12, Footnote 13, Subheadline 15,
    /// Callout 16, Body 17, Title 3 20, Title 2 22, Title 1 28, Large Title 34.
    static let touch: [Step] = [
        Step(size: 12, style: .caption), Step(size: 13, style: .footnote), Step(size: 15, style: .subheadline),
        Step(size: 16, style: .callout), Step(size: 17, style: .body), Step(size: 20, style: .title3),
        Step(size: 22, style: .title2), Step(size: 28, style: .title), Step(size: 34, style: .largeTitle),
    ]

    /// The steps of the platform the app runs on.
    static var steps: [Step] {
        #if os(tvOS)
            television
        #else
            touch
        #endif
    }

    /// The style nearest `size`; a size halfway between two takes the larger.
    static func style(for size: CGFloat, in steps: [Step] = TypeScale.steps) -> Font.TextStyle {
        var best = steps[0]
        for step in steps where abs(step.size - size) <= abs(best.size - size) {
            best = step
        }
        return best.style
    }
}

extension Font {
    /// The text style for a board's point size, with the board's weight and
    /// design; see `TypeScale`.
    static func boardStyle(_ size: CGFloat, weight: Font.Weight? = nil, design: Font.Design? = nil) -> Font {
        .system(TypeScale.style(for: size), design: design, weight: weight)
    }
}

private struct TypeScaleSample: View {
    let steps: [TypeScale.Step]

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.Spacing.xSmall) {
            ForEach(steps, id: \.size) { step in
                Text(verbatim: "\(Int(step.size)) pt")
                    .font(.system(step.style))
                    .foregroundStyle(Palette.text)
            }
        }
        .padding(Metrics.Spacing.large)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.ground)
    }
}

#Preview("Type scale") {
    TypeScaleSample(steps: TypeScale.steps)
}
