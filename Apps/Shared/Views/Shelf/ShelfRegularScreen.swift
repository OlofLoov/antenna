#if os(iOS) || os(macOS)
    import AntennaCore
    import SwiftUI

    /// Movies or Series in the iPad and Mac content column (board
    /// `iPad-Movies`, `iPad-Movies-Rows`): the toolbar with the section's
    /// name and sort menu, the banner card and the rows, or a grid in their
    /// place (`iPad-Movies-Grid`). The sidebar is the window's.
    struct ShelfRegularScreen<Leading: View>: View {
        let kind: ShelfTitle.Kind
        /// Rows or a grid, shared with the sidebar's genres.
        @Binding var browse: ShelfBrowse
        /// The sidebar button while the sidebar is folded.
        @ViewBuilder var leading: Leading
        @Environment(ShelfLibrary.self) private var library
        @Environment(ShelfActivity.self) private var activity

        /// Play arrives with task 4.1; My list goes through the activity.
        private var actions: ShelfActions { .with(activity) { _ in } }

        var body: some View {
            let model = library.model(kind)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    leading
                    Text(kind.sectionTitle)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Palette.text)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    sortMenu
                }
                .padding(EdgeInsets(top: 18, leading: 24, bottom: 0, trailing: 24))
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: ShelfView.Metrics.pad.rowSpacing) {
                        switch model.status {
                        case .titles(let banner, let waiting) where browse.list == nil:
                            ShelfBannerHost(model: model, actions: actions) {
                                ShelfBanner.Pad()
                                    .padding(.horizontal, 24)
                            }
                            ShelfNotices(model: model, banner: banner, waiting: waiting)
                            ShelfRowsContent(model: model, actions: actions) { browse.pick(.continueWatching) }
                        case .titles(let banner, let waiting) where browse.list != nil:
                            ShelfNotices(model: model, banner: banner, waiting: waiting)
                            ShelfGridContent(model: model, list: browse.list ?? .all, sort: browse.sort, actions: actions)
                        case let status:
                            ShelfStatusContent(model: model, status: status)
                        }
                    }
                    .padding(.vertical, 22)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Palette.ground)
            .environment(\.shelfMetrics, .pad)
            .environment(\.shelfPrefix, kind.prefix)
            .task(id: kind) { library.open() }
        }

        /// Recently added, Title or Year; the label reads the current order
        /// (movies-and-series-browsing/browse-a-genre-or-sort-the-lot).
        private var sortMenu: some View {
            Menu {
                ForEach(ShelfSort.allCases, id: \.self) { sort in
                    Button {
                        browse.order(sort)
                    } label: {
                        if sort == browse.sort {
                            Label(sort.name, systemImage: "checkmark")
                        } else {
                            Text(sort.name)
                        }
                    }
                    .accessibilityIdentifier("\(kind.prefix).sort.\(sort.rawValue)")
                }
            } label: {
                Text(browse.sort.name)
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.text)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 34)
                    .background(Palette.surface(0.08), in: RoundedRectangle(cornerRadius: 10))
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .accessibilityLabel("Sort")
            .accessibilityValue(browse.sort.name)
            .accessibilityIdentifier("\(kind.prefix).sort")
        }
    }
#endif
