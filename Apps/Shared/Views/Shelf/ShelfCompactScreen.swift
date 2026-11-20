#if os(iOS) || os(macOS)
    import AntennaCore
    import SwiftUI

    /// The Movies tab or the Series tab on iPhone and in a narrow iPad
    /// window (boards `iPhone-Movies`, `iPhone-Series`, `iPhone-Movies-Rows`):
    /// the section's name and the profile button over a tall banner with the
    /// genre button (the Genres sheet), then the rows or the picked genre's grid
    /// (`iPhone-Movies-Grid`). Once the banner scrolls away the name and the
    /// button stay pinned on the ground color. Each tab has its own screen,
    /// so each keeps its own scroll position and genre.
    struct ShelfCompactScreen: View {
        let kind: ShelfTitle.Kind
        @Environment(ShelfLibrary.self) private var library
        @Environment(ShelfActivity.self) private var activity
        @State private var pinned = false
        /// The grid in place of the rows; nil shows the rows.
        @State private var list: ShelfList?

        @Environment(ShelfPlayback.self) private var playback
        @Environment(\.tabTaps) private var tabTaps

        /// Posters and the banner play through the playback, open pages through the library, and
        /// change My list through the activity.
        private var actions: ShelfActions {
            .section(kind, library: library, activity: activity, playback: playback)
        }

        var body: some View {
            let page = library.top.flatMap { $0.section == kind && $0.origin != .search ? $0 : nil }
            ZStack {
                section
                    .opacity(page == nil ? 1 : 0)
                    .accessibilityHidden(page != nil)
                    .disabled(page != nil)
                if let page {
                    LibraryPageView(page: page) { page in
                        TitlePage.Phone(plotLines: page.title.kind == .movie ? 4 : 2) { EpisodePicker.Section(type: .phone) }
                    } person: {
                        PersonPageLayout.Phone()
                    }
                    .edgeSwipeBack { library.closePage() }
                    .environment(\.shelfMetrics, .phone)
                    .environment(\.shelfPrefix, kind.prefix)
                }
            }
            .background(Palette.ground)
            // Tapping Movies or Series again closes an open page, as a pushed page goes
            // back to its root (live-tv-on-iphone-ipad-mac/tap-the-open-tab-to-go-back-to-the-top).
            .onChange(of: tabTaps) { _, _ in
                if library.top.map({ $0.section == kind && $0.origin != .search }) == true { library.closeAll() }
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
                                        ShelfGenreButton(model: model, selection: list) { list = $0 }
                                    }
                                    .padding(.top, proxy.safeAreaInsets.top)
                                }
                            }
                            ShelfNotices(model: model, banner: banner, waiting: waiting)
                            if let list {
                                ShelfGridContent(model: model, list: list, sort: .recentlyAdded, actions: actions)
                            } else {
                                ShelfRowsContent(model: model, actions: actions) { list = $0 }
                            }
                        case let status:
                            topBar.padding(.top, proxy.safeAreaInsets.top)
                            ShelfStatusContent(model: model, status: status)
                        }
                    }
                    .padding(.bottom, 24)
                }
                .scrollsToTopOnTabTap()
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
            .task { library.open() }
        }

        /// The section's name and the profile button. Search is the tab
        /// bar's search button, so the bar has none of its own.
        private var topBar: some View {
            HStack {
                Text(kind.sectionTitle)
                    .font(.boardStyle(28, weight: .bold))
                    .foregroundStyle(Palette.text)
                    .lineLimit(1)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("\(kind.prefix).title")
                Spacer()
                ProfileMenuButton()
            }
            .padding(.leading, 16)
            .padding(.trailing, 12)
        }
    }
#endif
