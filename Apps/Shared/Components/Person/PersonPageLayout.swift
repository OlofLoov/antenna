import AntennaCore
import SwiftUI

/// What a person's page shows and what its parts do
/// (browse-by-person/a-person-s-page). The screen sets it.
struct PersonPageContext {
    /// One row of posters: Movies, Series or Directed.
    struct Row: Identifiable {
        /// `movies`, `series` or `directed`, the identifier's last part.
        var id: String
        var title: LocalizedStringResource
        /// "6 titles".
        var count: String
        var titles: [ShelfTitle]
        /// What VoiceOver reads for each poster, in `titles` order.
        var labels: [String]
    }

    struct State {
        /// As the provider wrote it, never translated.
        var name: String
        var initials: String
        /// "Acting · 9 in your sources"; nil while the page is built or when it is empty.
        var count: String?
        var rows: [Row]
        /// The note under the rows, nil when every title's names are known.
        var note: String?
        /// "Nothing with Mira Holt in your sources.", nil unless the page is empty.
        var empty: String?
        /// Where Back leads: the title's name, or Search.
        var back: LocalizedStringResource
        /// The poster whose title page just closed, focused again until
        /// `Actions.restored` runs.
        var returning: ActivityKey?
    }

    struct Actions {
        var back: () -> Void
        var open: (ShelfTitle) -> Void
        var restored: () -> Void
    }

    var state: State
    var actions: Actions
}

extension EnvironmentValues {
    /// Set by the person screen around the page.
    @Entry var personPage: PersonPageContext?
}

/// A person's page, one arrangement per board (`iPhone-Person`,
/// `iPad-Person`, `TV-Person`). Identifiers start with `person.`.
enum PersonPageLayout {
    /// The board's initials circle, the logo placeholder color.
    static let circle = Color(red: 0x26 / 255, green: 0x34 / 255, blue: 0x4A / 255)

    struct Sizes: Equatable {
        var circle: CGFloat
        var initials: CGFloat
        var name: CGFloat
        var count: CGFloat
        var note: CGFloat
        var gutter: CGFloat
        var spacing: CGFloat

        static let phone = Sizes(circle: 88, initials: 28, name: 28, count: 13, note: 12, gutter: 16, spacing: 18)
        static let pad = Sizes(circle: 112, initials: 34, name: 36, count: 14, note: 13, gutter: 24, spacing: 22)
        static let tv = Sizes(circle: 200, initials: 64, name: 76, count: 24, note: 22, gutter: 64, spacing: 36)
    }

    /// The initials circle, the name and the count line. Not focusable.
    struct Header: View {
        let type: Sizes
        @Environment(\.personPage) private var page

        var body: some View {
            if let page {
                HStack(spacing: type.gutter) {
                    Text(verbatim: page.state.initials)
                        .font(.boardStyle(type.initials, weight: .bold))
                        .foregroundStyle(Palette.textMuted)
                        .frame(width: type.circle, height: type.circle)
                        .background(Circle().fill(PersonPageLayout.circle))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: type.count / 2) {
                        // Provider text: never translated, laid out in its own script's direction.
                        Text(verbatim: page.state.name)
                            .font(.boardStyle(type.name, weight: .heavy))
                            .foregroundStyle(Palette.text)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                            .accessibilityAddTraits(.isHeader)
                        if let count = page.state.count {
                            Text(verbatim: count)
                                .font(.boardStyle(type.count))
                                .foregroundStyle(Browse.textSecondary)
                                .accessibilityIdentifier("person.count")
                        }
                    }
                }
                .padding(.horizontal, type.gutter)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("person.header")
            }
        }
    }

    /// The Movies, Series and Directed rows, each left out when empty, or
    /// the empty line. A poster opens the title's page.
    struct Rows: View {
        let type: Sizes
        @Environment(\.personPage) private var page
        @Environment(\.shelfMetrics) private var metrics
        @FocusState private var focused: ActivityKey?

        var body: some View {
            if let page {
                VStack(alignment: .leading, spacing: metrics.rowSpacing) {
                    if let empty = page.state.empty {
                        Text(verbatim: empty)
                            .font(.boardStyle(type.count))
                            .foregroundStyle(Browse.textSecondary)
                            .padding(.horizontal, type.gutter)
                            .accessibilityIdentifier("person.empty")
                    }
                    ForEach(page.state.rows) { row in
                        ShelfView.Row {
                            ShelfView.RowHeader(title: row.title, count: row.count) { EmptyView() }
                        } cards: {
                            ForEach(Array(zip(row.titles, row.labels)), id: \.0.activityKey) { title, label in
                                ShelfView.PosterCard(title: title, label: label) { page.actions.open(title) }
                                    .focused($focused, equals: title.activityKey)
                            }
                        }
                        .environment(\.shelfPrefix, "person.row.\(row.id)")
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("person.row.\(row.id)")
                        #if os(tvOS)
                            .focusSection()
                        #endif
                    }
                }
                .task(id: page.state.returning) {
                    // Back from a title's page, its poster has focus again.
                    guard let returning = page.state.returning else { return }
                    await Task.yield()
                    focused = returning
                    page.actions.restored()
                }
            }
        }
    }

    /// "Only titles whose cast your provider has sent are here. …", muted.
    struct Note: View {
        let type: Sizes
        @Environment(\.personPage) private var page

        var body: some View {
            if let note = page?.state.note {
                Text(verbatim: note)
                    .font(.boardStyle(type.note))
                    .foregroundStyle(Palette.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, type.gutter)
                    .accessibilityIdentifier("person.note")
            }
        }
    }

    /// "‹ The Long Harbor", a 44 pt target; Escape goes back too.
    struct Back: View {
        let size: CGFloat
        @Environment(\.personPage) private var page

        var body: some View {
            Button {
                page?.actions.back()
            } label: {
                Label(page?.state.back ?? "Back", systemImage: "chevron.backward")
                    .font(.boardStyle(size, weight: .semibold))
                    .foregroundStyle(Palette.accent)
                    .lineLimit(1)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            #if !os(tvOS)
                .keyboardShortcut(.cancelAction)
            #endif
            .accessibilityLabel("Back to \(page?.state.back ?? "the section")")
            .accessibilityIdentifier("person.back")
        }
    }
}

extension PersonPageContext {
    /// A page for previews, from fixed titles and no artwork.
    static func preview(rows: [Row] = PersonPreviewFixtures.rows, note: Bool = false, empty: Bool = false) -> PersonPageContext {
        PersonPageContext(
            state: State(
                name: "Mira Holt", initials: "MH", count: empty ? nil : "Acting · 9 in your sources", rows: empty ? [] : rows,
                note: note ? "Only titles whose cast your provider has sent are here. More appear as you browse." : nil,
                empty: empty ? "Nothing with Mira Holt in your sources." : nil, back: .verbatim("The Long Harbor"), returning: nil),
            actions: Actions(back: {}, open: { _ in }, restored: {}))
    }
}

enum PersonPreviewFixtures {
    static let rows = [
        row("movies", "Movies", (0..<6).map { ShelfFixtures.movie($0) }),
        row("series", "Series", (0..<3).map { ShelfFixtures.series($0) }),
    ]

    static func row(_ id: String, _ title: LocalizedStringResource, _ titles: [ShelfTitle]) -> PersonPageContext.Row {
        PersonPageContext.Row(id: id, title: title, count: "\(titles.count) titles", titles: titles, labels: titles.map(\.name))
    }
}
