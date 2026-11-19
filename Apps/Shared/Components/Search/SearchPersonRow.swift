import SwiftUI

extension SearchRow {
    /// A person: initials in a circle, the name with its highlight, and
    /// "Acting · 9 in your sources" (browse-by-person/find-a-person-in-search).
    /// The name is provider text, never translated.
    struct Person: View {
        let name: String
        let nameRanges: [Range<String.Index>]
        let detail: String
        let initials: String
        let select: () -> Void
        @Environment(\.searchMetrics) private var metrics
        @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

        var body: some View {
            Button(action: select) {
                HStack(spacing: metrics.spacing) {
                    Text(verbatim: initials)
                        .font(.boardStyle(metrics.initials * 1.3, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: metrics.logo.height, height: metrics.logo.height)
                        .background(Circle().fill(PersonPageLayout.circle))
                        .frame(width: metrics.logo.width)
                    VStack(alignment: .leading, spacing: 3) {
                        Highlighted(text: name, ranges: nameRanges)
                            .font(.boardStyle(metrics.title))
                            .lineLimit(1)
                        Text(verbatim: detail)
                            .font(.boardStyle(metrics.detail))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, metrics.padding)
                .frame(minHeight: metrics.channelHeight * scale)
                .contentShape(Rectangle())
            }
            .modifier(RowLook())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("People, \(name), \(detail)")
            .accessibilityAddTraits(.isButton)
        }
    }
}
