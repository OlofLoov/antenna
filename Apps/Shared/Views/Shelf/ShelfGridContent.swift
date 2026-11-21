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
    /// Recently added's See all: every title, newest first
    /// (movies-and-series-browsing/see-everything-new).
    case recentlyAdded

    /// The grid's heading: "All movies", "All series" or the category.
    func name(_ kind: ShelfTitle.Kind) -> LocalizedStringResource {
        switch self {
        case .all: kind == .movie ? "All movies" : "All series"
        case .genre(let name): .verbatim(name)
        case .myList: "My list"
        case .continueWatching: "Continue watching"
        case .recentlyAdded: "Recently added"
        }
    }

    /// `all`, or the category name as a slug.
    var identifier: String {
        switch self {
        case .all: "all"
        case .genre(let name): ShelfText.slug(name)
        case .myList: "myList"
        case .continueWatching: "continueWatching"
        case .recentlyAdded: "recentlyAdded"
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
    /// Recently added brings the rows back. Recently added's grid has one
    /// order, so another one shows All.
    mutating func order(_ sort: ShelfSort) {
        self.sort = sort
        list = sort == .recentlyAdded ? nil : (list == .recentlyAdded ? .all : list ?? .all)
    }
}

/// A list's posters in a grid, in `sort` order, with its name and count.
/// My list keeps its own order, latest added first, Recently added is always
/// newest first, and Continue watching shows its wide cards, most recent first.
struct ShelfGridContent: View {
    let model: ShelfModel
    let list: ShelfList
    let sort: ShelfSort
    let actions: ShelfActions
    @Environment(ShelfLibrary.self) private var library
    @Environment(ShelfActivity.self) private var activity
    @Environment(\.shelfMetrics) private var metrics
    @Environment(\.shelfPrefix) private var prefix

    var body: some View {
        switch list {
        case .continueWatching:
            let items = activity.continueWatching(library)
            ShelfView.Grid(title: list.name(model.kind), count: ShelfText.titles(items.count), cardWidth: metrics.card.width) {
                ForEach(items) { item in
                    ShelfContinueCard(item: item, actions: actions)
                }
            }
            .environment(\.shelfRow, "grid")
        case .all, .genre, .myList, .recentlyAdded:
            let titles = titles(of: list)
            ShelfView.Grid(title: list.name(model.kind), count: ShelfText.titles(titles?.count ?? count(of: list))) {
                ForEach(titles ?? []) { title in
                    ShelfPoster(title: title, actions: actions)
                }
            }
            .overlay {
                if titles == nil {
                    ProgressView()
                        .controlSize(.large)
                        .accessibilityIdentifier("\(prefix).grid.sorting")
                }
            }
            .environment(\.shelfRow, "grid")
            // A long list in Title or Year order is sorted away from the
            // main actor (movies-and-series-browsing/browsing-stays-responsive).
            .task(id: SortRequest(list: list, sort: sort, revision: model.indexRevision)) {
                switch list {
                case .all: await model.sort(in: nil, by: sort)
                case .genre(let name): await model.sort(in: name, by: sort)
                case .myList, .recentlyAdded, .continueWatching: break
                }
            }
        }
    }

    private struct SortRequest: Hashable {
        var list: ShelfList
        var sort: ShelfSort
        var revision: Int
    }

    /// Nil while the list's order is worked out.
    private func titles(of list: ShelfList) -> [ShelfTitle]? {
        switch list {
        case .all: model.titles(sortedBy: sort)
        case .genre(let name): model.titles(in: name, sortedBy: sort)
        case .myList: activity.myList(model)
        case .recentlyAdded: model.titles(sortedBy: .recentlyAdded)
        case .continueWatching: []
        }
    }

    /// The list's length before its order is ready.
    private func count(of list: ShelfList) -> Int {
        switch list {
        case .genre(let name): Shelf.genres(model.rows).first { $0.name == name }?.count ?? 0
        case .all, .myList, .recentlyAdded, .continueWatching: model.titles.count
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
                ShelfView.Chip(title: .verbatim(genre.name), isSelected: selection == list) { select(list) }
                    .accessibilityIdentifier("\(prefix).genres.\(list.identifier)")
            }
        }
    }
}
