import AntennaCore
import SwiftUI

/// A person's page over the title page or Search it was opened from
/// (browse-by-person/a-person-s-page). Builds the page from the people
/// index, which reads only names the provider already sent, and rebuilds it
/// when titles or names arrive. The host screen picks the arrangement.
struct PersonScreen<Page: View>: View {
    let route: PersonRoute
    @ViewBuilder var page: Page
    @Environment(ShelfLibrary.self) private var library
    @Environment(ShelfActivity.self) private var activity
    @Environment(\.locale) private var locale
    @State private var built: PersonPage?

    var body: some View {
        page
            .environment(\.personPage, context)
            .task(id: library.peopleRevision) {
                let index = await library.people()
                guard !Task.isCancelled else { return }
                built = index.page(route.name)
            }
            #if os(tvOS)
                .onExitCommand { library.closePage() }
            #endif
            #if os(iOS)
                // iPadOS keeps Escape unless a key command asks for priority.
                .background { LiveEscapeKey { library.closePage() } }
            #endif
    }

    private var context: PersonPageContext {
        let name = built?.name ?? route.name.display
        return PersonPageContext(
            state: .init(
                name: name, initials: built?.initials ?? PersonPage.initials(of: name),
                count: built.flatMap { $0.isEmpty ? nil : $0.countLine(locale: locale) }, rows: rows,
                note: built?.showsNote == true ? PersonPage.note(locale: locale) : nil,
                empty: built.flatMap { $0.isEmpty ? $0.emptyLine(locale: locale) : nil }, back: back, returning: returning),
            actions: .init(back: { library.closePage() }, open: { library.push($0) }, restored: { library.restored() }))
    }

    private var rows: [PersonPageContext.Row] {
        guard let built else { return [] }
        return [
            row("movies", "Movies", built.movies), row("series", "Series", built.series), row("directed", "Directed", built.directed),
        ]
        .compactMap(\.self)
    }

    private func row(_ id: String, _ title: LocalizedStringResource, _ titles: [ShelfTitle]) -> PersonPageContext.Row? {
        guard !titles.isEmpty else { return nil }
        return PersonPageContext.Row(
            id: id, title: title, count: ShelfText.titles(titles.count, locale: locale), titles: titles,
            labels: titles.map { ShelfText.posterLabel($0, progress: activity.progress(of: $0), locale: locale) })
    }

    /// The title's name below this page, or Search.
    private var back: LocalizedStringResource {
        guard let index = library.stack.firstIndex(of: .person(route)), index > 0 else { return "Search" }
        if case .title(let title) = library.stack[index - 1] { return .verbatim(title.title.name) }
        return "Back"
    }

    /// The poster whose title page just closed over this page.
    private var returning: ActivityKey? {
        guard case .title(let closed)? = library.popped, library.person == route else { return nil }
        return closed.title.activityKey
    }
}
