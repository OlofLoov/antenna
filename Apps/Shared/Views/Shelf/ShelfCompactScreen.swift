#if os(iOS) || os(macOS)
    import AntennaCore
    import SwiftUI

    /// The Movies tab on iPhone and in a narrow iPad window (board
    /// `iPhone-Movies`, `iPhone-Movies-Rows`): the Movies | Series switch
    /// over a tall banner with the genre chips, then the rows or the
    /// picked genre's grid (`iPhone-Movies-Grid`). Once the banner scrolls away the
    /// switch stays pinned on the ground color.
    struct ShelfCompactScreen: View {
        @Environment(ShelfLibrary.self) private var library
        @Environment(ShelfActivity.self) private var activity
        @State private var kind: ShelfTitle.Kind = .movie
        @State private var pinned = false
        /// The grid in place of the rows; nil shows the rows.
        @State private var list: ShelfList?

        @Environment(ShelfPlayback.self) private var playback

        /// Posters and the banner play through the playback, open pages through the library, and
        /// change My list through the activity.
        private var actions: ShelfActions {
            .section(kind, library: library, activity: activity, playback: playback)
        }

        var body: some View {
            let page = library.page.flatMap { $0.section == kind ? $0 : nil }
            ZStack {
                section
                    .opacity(page == nil ? 1 : 0)
                    .accessibilityHidden(page != nil)
                    .disabled(page != nil)
                if let page {
                    TitleScreen(route: page) {
                        TitlePage.Phone(plotLines: page.title.kind == .movie ? 4 : 2) { EmptyView() }
                    }
                    .simultaneousGesture(edgeSwipe)
                    .environment(\.shelfMetrics, .phone)
                    .environment(\.shelfPrefix, kind.prefix)
                }
            }
            .background(Palette.ground)
        }

        /// A swipe in from the left edge goes back, as a pushed page does
        /// (title-detail-and-episode-picker/back-to-where-you-were).
        private var edgeSwipe: some Gesture {
            DragGesture(minimumDistance: 20)
                .onEnded { drag in
                    guard drag.startLocation.x < 28, drag.translation.width > 80,
                        abs(drag.translation.height) < drag.translation.width
                    else { return }
                    library.closePage()
                }
        }

        private var section: some View {
            let model = library.model(kind)
            return GeometryReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: ShelfView.Metrics.phone.rowSpacing) {
                        switch model.status {
                        case .titles(let banner, let waiting):
                            ShelfBannerHost(model: model, actions: actions) {
                                ShelfBanner.Phone {
                                    VStack(alignment: .leading, spacing: 2) {
                                        topBar
                                            .opacity(pinned ? 0 : 1)
                                            .accessibilityHidden(pinned)
                                        ShelfGenreChips(model: model, selection: list, select: { list = $0 }) {
                                            ShelfView.Chip(title: "All", isSelected: list == nil) { list = nil }
                                                .accessibilityIdentifier("\(kind.prefix).genres.all")
                                            ShelfView.Chip(title: "My list", isSelected: list == .myList) { list = .myList }
                                                .accessibilityIdentifier("\(kind.prefix).genres.myList")
                                        }
                                    }
                                    .padding(.top, proxy.safeAreaInsets.top)
                                }
                            }
                            ShelfNotices(model: model, banner: banner, waiting: waiting)
                            if let list {
                                ShelfGridContent(model: model, list: list, sort: .recentlyAdded, actions: actions)
                            } else {
                                ShelfRowsContent(model: model, actions: actions) { list = .continueWatching }
                            }
                        case let status:
                            topBar.padding(.top, proxy.safeAreaInsets.top)
                            ShelfStatusContent(model: model, status: status)
                        }
                    }
                    .padding(.bottom, 24)
                }
                .onScrollGeometryChange(for: Bool.self) { geometry in
                    geometry.contentOffset.y + geometry.contentInsets.top > 420
                } action: { _, past in
                    pinned = past
                }
                .ignoresSafeArea(edges: .top)
                .overlay(alignment: .top) {
                    if pinned {
                        topBar
                            .padding(.bottom, 10)
                            .background(Palette.ground.ignoresSafeArea(edges: .top))
                            .overlay(alignment: .bottom) { Rectangle().fill(Palette.surface(0.08)).frame(height: 1) }
                    }
                }
            }
            .background(Palette.ground)
            .environment(\.shelfMetrics, .phone)
            .environment(\.shelfPrefix, kind.prefix)
            .task(id: kind) { library.open() }
        }

        private var topBar: some View {
            HStack {
                ShelfView.KindSwitch(selection: kind) {
                    kind = $0
                    list = nil
                }
                Spacer()
            }
            .padding(.horizontal, 16)
        }
    }
#endif
