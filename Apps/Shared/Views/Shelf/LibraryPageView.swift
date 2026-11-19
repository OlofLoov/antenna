import AntennaCore
import SwiftUI

/// The page on top of the library's stack, in the host screen's
/// arrangements: a title page through `title`, a person's page through
/// `person` (browse-by-person/a-person-s-page).
struct LibraryPageView<TitleArrangement: View, PersonArrangement: View>: View {
    let page: LibraryPage
    @ViewBuilder var title: (TitleRoute) -> TitleArrangement
    @ViewBuilder var person: () -> PersonArrangement

    var body: some View {
        switch page {
        case .title(let route):
            TitleScreen(route: route) { title(route) }
                .id(ObjectIdentifier(route.model))
        case .person(let route):
            PersonScreen(route: route) { person() }
                .id(route.id)
        }
    }
}
