import AntennaCore
import SwiftUI

/// The list a grid shows in place of the rows
/// (movies-and-series-browsing/browse-a-genre-or-sort-the-lot).
enum ShelfList: Hashable {
    /// Every title of the section.
    case all
    /// One category, every source's titles together.
    case genre(String)

    /// The grid's heading: "All movies", "All series" or the category.
    func name(_ kind: ShelfTitle.Kind) -> String {
        switch self {
        case .all: kind == .movie ? "All movies" : "All series"
        case .genre(let name): name
        }
    }

    /// `all`, or the category name as a slug.
    var identifier: String {
        switch self {
        case .all: "all"
        case .genre(let name): ShelfText.slug(name)
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
struct ShelfGridContent: View {
    let model: ShelfModel
    let list: ShelfList
    let sort: ShelfSort
    let actions: ShelfActions

    var body: some View {
        let titles = Shelf.sorted(titles(of: list), by: sort)
        ShelfView.Grid(title: list.name(model.kind), count: ShelfText.titles(titles.count)) {
            ForEach(titles) { title in
                ShelfView.PosterCard(title: title, label: title.name) { actions.play(title) }
            }
        }
    }

    private func titles(of list: ShelfList) -> [ShelfTitle] {
        switch list {
        case .all: model.titles
        case .genre(let name): Shelf.titles(in: name, of: model.titles)
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
