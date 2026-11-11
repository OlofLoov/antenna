import AntennaCore
import SwiftUI

/// The field, chips, section headers and messages around Search's results.
enum SearchParts {
    /// The search field on iPhone, iPad and Mac: a magnifier, the
    /// placeholder, and a clear button while it holds text
    /// (search/clear-the-field). The screen binds the text and the focus.
    struct Field: View {
        @Binding var text: String
        let clear: () -> Void
        let submit: () -> Void
        @Environment(\.searchMetrics) private var metrics

        var body: some View {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Palette.textMuted)
                    .accessibilityHidden(true)
                TextField("Search", text: $text, prompt: Text(SearchText.placeholder).foregroundStyle(Palette.textMuted))
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .onSubmit(submit)
                    .accessibilityLabel(SearchText.placeholder)
                    .accessibilityIdentifier("search.field")
                if !text.isEmpty {
                    Button(action: clear) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Palette.textMuted)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear")
                    .accessibilityIdentifier("search.clear")
                }
            }
            .font(.system(size: metrics.title + 2))
            .foregroundStyle(Palette.text)
            .padding(.leading, 12)
            .padding(.trailing, text.isEmpty ? 12 : 0)
            .frame(height: metrics.title * 2.7)
            .background(Palette.surface(0.08), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    /// One kind chip with its count. A kind with nothing is grayed out and
    /// cannot be picked (search/narrow-to-one-kind).
    struct Chip: View {
        let title: String
        let isSelected: Bool
        let isEmpty: Bool
        let select: () -> Void

        var body: some View {
            Browse.Chip(title: title, isSelected: isSelected, select: select)
                .disabled(isEmpty)
                .opacity(isEmpty ? 0.45 : 1)
        }
    }

    /// A section's name, its count and an optional trailing link.
    struct Header<Trailing: View>: View {
        let title: String
        let count: String?
        @ViewBuilder var trailing: Trailing
        @Environment(\.searchMetrics) private var metrics

        var body: some View {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(title)
                    .font(.system(size: metrics.header, weight: .bold))
                    .foregroundStyle(Palette.text)
                    .accessibilityAddTraits(.isHeader)
                if let count {
                    Text(count)
                        .font(.system(size: metrics.headerCount))
                        .foregroundStyle(Palette.textMuted)
                }
                Spacer(minLength: 0)
                trailing
            }
        }
    }

    /// "See all n" in the accent color.
    struct SeeAll: View {
        let count: Int
        let select: () -> Void
        @Environment(\.searchMetrics) private var metrics

        var body: some View {
            Button(action: select) {
                Text("See all \(count)")
                    .font(.system(size: metrics.headerCount))
                    .foregroundStyle(Palette.accent)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("search.seeAll")
        }
    }

    /// The muted last row of a capped section: "Showing 500 of 612".
    struct CapNote: View {
        let text: String
        @Environment(\.searchMetrics) private var metrics

        var body: some View {
            Text(text)
                .font(.system(size: metrics.detail))
                .foregroundStyle(Palette.textMuted)
                .frame(maxWidth: .infinity, minHeight: 44)
                .accessibilityIdentifier("search.capNote")
        }
    }

    /// A recent search in the iPad and Mac sidebar: 36 pt text with a 44 pt
    /// hit area, tinted while the arrow keys are on it.
    struct SidebarRecent: View {
        let text: String
        let isCursor: Bool
        let select: () -> Void

        var body: some View {
            Button(action: select) {
                Text(text)
                    .font(.system(size: 16))
                    .foregroundStyle(Browse.textSecondary)
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .background(isCursor ? Palette.surface(0.12) : .clear, in: RoundedRectangle(cornerRadius: 10))
                    .contentShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Recent search, \(text)")
        }
    }

    /// A centered message: no results with its hint, or sources still loading
    /// (search/nothing-found).
    struct Message: View {
        let title: String
        let lines: [String]
        @Environment(\.searchMetrics) private var metrics

        var body: some View {
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: metrics.header + 2, weight: .semibold))
                    .foregroundStyle(Palette.text)
                ForEach(lines, id: \.self) { line in
                    Text(line)
                        .font(.system(size: metrics.title))
                        .foregroundStyle(Palette.textMuted)
                }
            }
            .multilineTextAlignment(.center)
            .padding(24)
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
        }
    }
}
