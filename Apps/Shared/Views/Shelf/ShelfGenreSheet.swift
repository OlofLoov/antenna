#if os(iOS) || os(macOS)
    import AntennaCore
    import SwiftUI

    /// The open genre in the top bar of Movies or Series on iPhone and in a
    /// narrow iPad window, on a glass capsule (`iPhone-Movies`;
    /// movies-and-series-browsing/pick-a-genre-from-a-list-on-iphone): the
    /// genre's name, its count and a chevron. Tapping it opens the Genres
    /// sheet. `selection` nil is the rows, read as "All movies" or "All series".
    struct ShelfGenreButton: View {
        let model: ShelfModel
        let selection: ShelfList?
        let select: (ShelfList?) -> Void
        @Environment(ShelfActivity.self) private var activity
        @Environment(\.shelfPrefix) private var prefix
        @State private var isPresented = false

        var body: some View {
            let list = selection ?? .all
            let name = String(localized: list.name(model.kind))
            ShelfCategoryButton(name: name, count: count(of: list)) {
                isPresented = true
            }
            .accessibilityLabel(Text(verbatim: "\(name), \(ShelfText.titles(count(of: list)))"))
            .accessibilityHint(Text("Opens the list of genres"))
            .accessibilityIdentifier("\(prefix).genres")
            .sheet(isPresented: $isPresented) {
                ShelfGenreSheet(model: model, selection: selection, count: count(of:)) { picked in
                    select(picked)
                    isPresented = false
                }
                .presentationDetents([.medium, .large])
            }
        }

        private func count(of list: ShelfList) -> Int {
            switch list {
            case .all: model.titles.count
            case .genre(let name): Shelf.genres(model.rows).first { $0.name == name }?.count ?? 0
            case .myList: activity.myList(model).count
            case .continueWatching, .recentlyAdded: 0
            }
        }
    }

    /// The section's lists with search, as Live's Groups sheet
    /// (`iPhone-Movies-Genres`): All and My list first, then every genre
    /// with its count and a checkmark on the open one. Picking one closes
    /// the sheet; All shows the rows, the rest their grid.
    struct ShelfGenreSheet: View {
        let model: ShelfModel
        let selection: ShelfList?
        let count: (ShelfList) -> Int
        let pick: (ShelfList?) -> Void
        @Environment(\.shelfPrefix) private var prefix
        @Environment(\.dismiss) private var dismiss
        @State private var query = ""

        var body: some View {
            let genres = Shelf.genres(model.rows, matching: query)
            NavigationStack {
                List {
                    if query.isEmpty {
                        Section {
                            row(.all, picks: nil)
                            row(.myList, picks: .myList)
                        }
                    }
                    if !genres.isEmpty {
                        Section {
                            ForEach(genres) { genre in
                                row(.genre(genre.name), picks: .genre(genre.name))
                            }
                        }
                    }
                }
                .environment(\.defaultMinListRowHeight, 44)
                .accessibilityIdentifier("\(prefix).genres.sheet")
                .overlay {
                    if genres.isEmpty, !query.isEmpty {
                        ContentUnavailableView.search(text: query)
                            .accessibilityElement(children: .combine)
                    }
                }
                .navigationTitle(Text("Genres"))
                .genreSearch($query)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(role: .close) { dismiss() }
                            .accessibilityIdentifier("\(prefix).genres.close")
                    }
                }
            }
        }

        private func row(_ list: ShelfList, picks: ShelfList?) -> some View {
            Browse.GroupChoiceRow(
                name: String(localized: list.name(model.kind)), systemImage: nil,
                count: count(list), isSelected: (selection ?? .all) == list
            ) {
                pick(picks)
            }
            .listRowInsets(.vertical, 0)
            .accessibilityIdentifier("\(prefix).genres.\(list.identifier)")
        }
    }

    extension View {
        /// The sheet's search field, always shown under the title on iPhone.
        @ViewBuilder fileprivate func genreSearch(_ query: Binding<String>) -> some View {
            #if os(iOS)
                navigationBarTitleDisplayMode(.inline)
                    .searchable(text: query, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("Search genres"))
            #else
                searchable(text: query, prompt: Text("Search genres"))
            #endif
        }
    }
#endif
