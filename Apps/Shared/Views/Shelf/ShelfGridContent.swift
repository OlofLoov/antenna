import AntennaCore
import SwiftUI

/// The list a grid shows in place of the rows
/// (movies-and-series-browsing/browse-a-genre-or-sort-the-lot).
enum ShelfList: Hashable {
    /// Every title of the section.
    case all
    /// One category, every source's titles together.
    case genre(String)
    /// The section's titles on My list, latest added first.
    case myList
    /// Continue watching's See all.
    case continueWatching

    /// The grid's heading: "All movies", "All series" or the category.
    func name(_ kind: ShelfTitle.Kind) -> String {
        switch self {
        case .all: kind == .movie ? "All movies" : "All series"
        case .genre(let name): name
        case .myList: "My list"
        case .continueWatching: "Continue watching"
        }
    }

    /// `all`, or the category name as a slug.
    var identifier: String {
        switch self {
        case .all: "all"
        case .genre(let name): ShelfText.slug(name)
        case .myList: "myList"
        case .continueWatching: "continueWatching"
        }
    }
}

/// What the iPad and Mac section shows: the rows, or a list's grid in an
/// order (`iPad-Movies-Grid`).
struct ShelfBrowse: Equatable {
    /// Nil shows the rows.
    var list: ShelfList?
    var sort = ShelfSort.recentlyAdded

    /// A genre, My list or All in the sidebar opens its grid in the current order.
    mutating func pick(_ list: ShelfList) {
        self.list = list
    }

    /// Title or Year shows the open grid, or All, in that order;
    /// Recently added brings the rows back.
    mutating func order(_ sort: ShelfSort) {
        self.sort = sort
        list = sort == .recentlyAdded ? nil : (list ?? .all)
    }
}

/// A list's posters in a grid, in `sort` order, with its name and count.
/// My list keeps its own order, latest added first, and Continue watching
/// shows its wide cards, most recent first.
struct ShelfGridContent: View {
    let model: ShelfModel
    let list: ShelfList
    let sort: ShelfSort
    let actions: ShelfActions
    @Environment(ShelfLibrary.self) private var library
    @Environment(ShelfActivity.self) private var activity
    @Environment(\.shelfMetrics) private var metrics

    var body: some View {
        switch list {
        case .continueWatching:
            let items = activity.continueWatching(library)
            ShelfView.Grid(title: list.name(model.kind), count: ShelfText.titles(items.count), cardWidth: metrics.card.width) {
                ForEach(items) { item in
                    ShelfContinueCard(item: item, actions: actions)
                }
            }
        case .all, .genre, .myList:
            let titles = titles(of: list)
            ShelfView.Grid(title: list.name(model.kind), count: ShelfText.titles(titles.count)) {
                ForEach(titles) { title in
                    ShelfPoster(title: title, actions: actions)
                }
            }
        }
    }

    private func titles(of list: ShelfList) -> [ShelfTitle] {
        switch list {
        case .all: Shelf.sorted(model.titles, by: sort)
        case .genre(let name): Shelf.sorted(Shelf.titles(in: name, of: model.titles), by: sort)
        case .myList: activity.myList(model)
        case .continueWatching: []
        }
    }
}

/// The genre chips: `leading` (All on iPhone, All movies on Apple TV), then
/// one per genre. Picking a chip opens its grid.
struct ShelfGenreChips<Leading: View>: View {
    let model: ShelfModel
    let selection: ShelfList?
    let select: (ShelfList) -> Void
    @ViewBuilder var leading: Leading
    @Environment(\.shelfPrefix) private var prefix

    var body: some View {
        ShelfView.Chips {
            leading
            ForEach(Shelf.genres(model.rows)) { genre in
                let list = ShelfList.genre(genre.name)
                ShelfView.Chip(title: genre.name, isSelected: selection == list) { select(list) }
                    .accessibilityIdentifier("\(prefix).genres.\(list.identifier)")
            }
        }
    }
}
