import SwiftUI

extension TitlePage {
    /// "Cast Mira Holt, …" and "Director Sanna Weiss", each up to two
    /// lines until the page is expanded. `cut` hears whether either line
    /// hides names, so the page can offer More.
    struct Credits: View {
        let type: Sizes
        var cut: (Bool) -> Void = { _ in }
        @Environment(\.titlePage) private var page
        @State private var hiding: Set<String> = []

        var body: some View {
            if let page, page.state.metadata.cast != nil || page.state.metadata.director != nil {
                let meta = page.state.metadata
                let expanded = page.state.expanded
                VStack(alignment: .leading, spacing: type.spacing / 2) {
                    if let cast = meta.cast {
                        CutLine(text: line("Cast", cast), lines: 2, expanded: expanded) { record($0, "title.cast") }
                            .accessibilityIdentifier("title.cast")
                    }
                    if let director = meta.director {
                        CutLine(text: line("Director", director), lines: 2, expanded: expanded) { record($0, "title.director") }
                            .accessibilityIdentifier("title.director")
                    }
                }
                .onChange(of: hiding.isEmpty, initial: true) { _, none in cut(!none) }
            }
        }

        private func record(_ hides: Bool, _ line: String) {
            if hides { hiding.insert(line) } else { hiding.remove(line) }
        }

        private func line(_ label: String, _ names: String) -> Text {
            Text("\(Text(label).foregroundStyle(Palette.textMuted)) \(Text(names).foregroundStyle(Browse.textSecondary))")
                .font(.system(size: type.plot * 0.9))
        }
    }

    /// Text cut to `lines` unless `expanded`, telling `hides` whether the
    /// cut leaves words out.
    struct CutLine: View {
        let text: Text
        let lines: Int
        let expanded: Bool
        let hides: (Bool) -> Void
        @State private var cutHeight: CGFloat = 0
        @State private var fullHeight: CGFloat = 0

        var body: some View {
            text
                .lineLimit(expanded ? nil : lines)
                .fixedSize(horizontal: false, vertical: true)
                .background {
                    ZStack {
                        text.lineLimit(lines).fixedSize(horizontal: false, vertical: true)
                            .onGeometryChange(for: CGFloat.self) {
                                $0.size.height
                            } action: {
                                cutHeight = $0
                            }
                        text.fixedSize(horizontal: false, vertical: true)
                            .onGeometryChange(for: CGFloat.self) {
                                $0.size.height
                            } action: {
                                fullHeight = $0
                            }
                    }
                    .hidden()
                }
                .onChange(of: fullHeight > cutHeight + 1, initial: true) { _, over in hides(over) }
        }
    }
}
