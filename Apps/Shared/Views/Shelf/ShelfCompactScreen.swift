#if os(iOS) || os(macOS)
    import AntennaCore
    import SwiftUI

    /// The Movies tab or the Series tab on iPhone and in a narrow iPad
    /// window (boards `iPhone-Movies`, `iPhone-Movies-Rows`): a bar pinned at
    /// the top with the section's name, the genre button (the Genres sheet)
    /// and the profile button, then the banner card below it, then the rows
    /// or the picked genre's grid (`iPhone-Movies-Grid`). Everything below
    /// the bar scrolls under it (movies-and-series-browsing/a-pinned-top-bar-on-iphone).
    /// Each tab has its own screen, so each keeps its own scroll position
    /// and genre.
    struct ShelfCompactScreen: View {
        let kind: ShelfTitle.Kind
        @Environment(ShelfLibrary.self) private var library
        @Environment(ShelfActivity.self) private var activity
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
            return ScrollView {
                LazyVStack(alignment: .leading, spacing: ShelfView.Metrics.phone.rowSpacing) {
                    switch model.status {
                    case .titles(let banner, let waiting):
                        ShelfBannerHost(model: model, actions: actions) {
                            ShelfBanner.Phone()
                                .padding(.horizontal, 16)
                        }
                        ShelfNotices(model: model, banner: banner, waiting: waiting)
                        if let list {
                            ShelfGridContent(model: model, list: list, sort: .recentlyAdded, actions: actions)
                        } else {
                            ShelfRowsContent(model: model, actions: actions) { list = $0 }
                        }
                    case let status:
                        ShelfStatusContent(model: model, status: status)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollsToTopOnTabTap()
            // The bar is the scroll view's own top bar, so the system blurs
            // the rows passing under it.
            .safeAreaBar(edge: .top) { topBar(model) }
            .background(Palette.ground)
            .environment(\.shelfMetrics, .phone)
            .environment(\.shelfPrefix, kind.prefix)
            .task { library.open() }
        }

        /// The section's name, the genre button once there are titles, and
        /// the profile button. Search is the tab bar's search button, so the
        /// bar has none of its own.
        private func topBar(_ model: ShelfModel) -> some View {
            ShelfTopBar(title: kind.sectionTitle) {
                if case .titles = model.status {
                    ShelfGenreButton(model: model, selection: list) { list = $0 }
                }
            } profile: {
                ProfileMenuButton()
            }
        }
    }
#endif
