import AntennaCore
import SwiftUI

/// A title's or an episode's whole description with its cast and director
/// (title-detail-and-episode-picker/what-the-title-is-about,
/// title-detail-and-episode-picker/what-each-episode-shows). `TV-Title-About`
/// on Apple TV, where the remote scrolls it; `iPhone-Title-About` elsewhere,
/// with Done. The presenter closes it through `close`.
struct TitleAbout: View {
    let text: TitleAboutText
    let close: () -> Void

    var body: some View {
        #if os(tvOS)
            Television(text: text, close: close)
        #else
            Sheet(text: text, close: close)
        #endif
    }

    /// The heading, the details line and the paragraphs at `sizes`.
    struct Column: View {
        let text: TitleAboutText
        let sizes: Sizes

        var body: some View {
            VStack(alignment: .leading, spacing: sizes.spacing) {
                Text(text.heading)
                    .font(sizes.heading)
                    .foregroundStyle(Palette.text)
                    .accessibilityAddTraits(.isHeader)
                if let details = text.details {
                    Text(details)
                        .font(sizes.details)
                        .foregroundStyle(Browse.textSecondary)
                }
                ForEach(Array(text.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                    if let label = paragraph.label {
                        Text("\(Text(label).foregroundStyle(Palette.textMuted)) \(Text(paragraph.text).foregroundStyle(Palette.text))")
                            .font(sizes.details)
                            .lineSpacing(sizes.lineSpacing)
                    } else {
                        Text(paragraph.text)
                            .font(sizes.body)
                            .lineSpacing(sizes.lineSpacing)
                            .foregroundStyle(Palette.text)
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// The board's type: fixed sizes on the TV, text styles that follow
    /// Dynamic Type elsewhere.
    struct Sizes {
        var heading: Font
        var details: Font
        var body: Font
        var spacing: CGFloat
        var lineSpacing: CGFloat

        static let tv = Sizes(
            heading: .system(size: 57, weight: .bold), details: .system(size: 29), body: .system(size: 31), spacing: 28,
            lineSpacing: 10)
        static let phone = Sizes(heading: .title2.bold(), details: .subheadline, body: .body, spacing: 12, lineSpacing: 5)
    }

    #if os(tvOS)
        /// The column takes focus without a focus effect; swiping down or up
        /// moves the scroll view 360 points within its range. Menu closes the page.
        struct Television: View {
            let text: TitleAboutText
            let close: () -> Void
            @State private var position = ScrollPosition(edge: .top)
            @State private var offset: CGFloat = 0
            @State private var range: CGFloat = 0
            @FocusState private var focused: Bool

            static let step: CGFloat = 360

            var body: some View {
                ScrollView {
                    Column(text: text, sizes: .tv)
                        .frame(maxWidth: 1200, alignment: .leading)
                        .padding(.vertical, 120)
                        .frame(maxWidth: .infinity)
                        .focusable()
                        .focusEffectDisabled()
                        .focused($focused)
                        .onMoveCommand(perform: move)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("title.about")
                }
                .defaultFocus($focused, true)
                .scrollPosition($position)
                .onScrollGeometryChange(for: [CGFloat].self) { geometry in
                    [geometry.contentOffset.y, max(0, geometry.contentSize.height - geometry.containerSize.height)]
                } action: { _, values in
                    offset = values[0]
                    range = values[1]
                }
                .onAppear { focused = true }
                .onExitCommand(perform: close)
            }

            private func move(_ direction: MoveCommandDirection) {
                let target: CGFloat
                switch direction {
                case .down: target = min(range, offset + Self.step)
                case .up: target = max(0, offset - Self.step)
                default: return
                }
                withAnimation(.easeOut(duration: 0.25)) { position.scrollTo(y: target) }
            }
        }
    #else
        /// A sheet with Done, which Escape also presses.
        struct Sheet: View {
            let text: TitleAboutText
            let close: () -> Void

            var body: some View {
                NavigationStack {
                    ScrollView {
                        Column(text: text, sizes: .phone)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 24)
                            .accessibilityIdentifier("title.about.text")
                    }
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done", action: close)
                                .keyboardShortcut(.cancelAction)
                                .accessibilityIdentifier("title.about.done")
                        }
                    }
                }
                .presentationDetents([.medium, .large])
                .presentationBackground(Palette.ground)
                .preferredColorScheme(.dark)
                .accessibilityIdentifier("title.about")
            }
        }
    #endif
}

extension TitleAboutText {
    /// The Long Harbor with a long description, for previews.
    static let preview = TitleAboutText(
        heading: "The Long Harbor", details: "2024 · 2 h 08 min · Thriller",
        paragraphs: [
            .init(
                text: "A harbour pilot uncovers a smuggling ring the night before the port is sold. One tide to decide who gets out. "
                    + "With the buyers arriving at dawn and her own crew split down the middle, she has until the water turns to choose "
                    + "a side, and every channel out of the harbour is watched."),
            .init(label: "Cast", text: "Mira Holt, Jonas Reeve, Adaeze Okafor, Teodor Lind, Ines Barros, Paul Achterberg, Kaito Mori"),
            .init(label: "Director", text: "Sanna Weiss"),
        ])
}

#if os(tvOS)
    #Preview("About, Apple TV", traits: .fixedLayout(width: 1920, height: 1080)) {
        TitleAbout(text: .preview, close: {})
            .background(CoverBackdrop())
    }
#else
    #Preview("About, episode") {
        TitleAbout(
            text: TitleAboutText(
                heading: "4. Low Water", details: "Season 1 · Episode 4 · 44 min",
                paragraphs: [
                    .init(
                        text: "The ferry runs aground off the north point and the sisters spend the night on the ice, waiting "
                            + "for the tide.")
                ]), close: {}
        )
        .background(Palette.ground)
    }
#endif
