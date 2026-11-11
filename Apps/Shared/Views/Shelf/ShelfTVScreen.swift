#if os(tvOS)
    import AntennaCore
    import SwiftUI

    /// Movies or Series under the Apple TV tab bar (board `TV-Movies`,
    /// `TV-Movies-Rows`): the banner full bleed, the rows, then the genre
    /// chips. The banner's Play button is where focus lands when the tab opens.
    struct ShelfTVScreen: View {
        let kind: ShelfTitle.Kind
        let focus: FocusState<ShellFocus?>.Binding
        @Environment(ShelfLibrary.self) private var library
        @Environment(ShelfActivity.self) private var activity

        /// The grid open over the rows, a screen of its own that Menu closes.
        @State private var list: ShelfList?
        @State private var scrolled = false

        /// Play arrives with task 4.1; My list goes through the activity.
        private var actions: ShelfActions { .with(activity) { _ in } }

        var body: some View {
            let model = library.model(kind)
            Group {
                if let list {
                    grid(model, list)
                } else {
                    rows(model)
                }
            }
            .background(Palette.ground)
            .environment(\.shelfMetrics, .tv)
            .environment(\.shelfPrefix, kind.prefix)
            .task(id: kind) {
                list = nil
                library.open()
            }
            // The loading holder had focus; once titles replace it, Play takes it.
            .onChange(of: model.status.showsTitles) { _, titles in
                guard titles, focus.wrappedValue == nil || focus.wrappedValue == .content else { return }
                refocus()
            }
        }

        private func rows(_ model: ShelfModel) -> some View {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: ShelfView.Metrics.tv.rowSpacing) {
                    switch model.status {
                    case .titles(let banner, let waiting):
                        ShelfBannerHost(model: model, actions: actions) {
                            ShelfBanner.Television {
                                ShelfTVBannerButtons(focus: focus)
                            }
                        }
                        // Full bleed behind the tab bar.
                        .padding(.top, -Self.barHeight)
                        ShelfNotices(model: model, banner: banner, waiting: waiting)
                        ShelfRowsContent(model: model, actions: actions) { list = .continueWatching }
                        genres(model)
                    case let status:
                        ShelfTVStatus(model: model, status: status, focus: focus)
                            .padding(.top, 60)
                    }
                }
                .padding(.bottom, 60)
            }
            // Focus scrolls rows clear of the tab bar, which sits on a band of
            // the ground color once the banner has scrolled away.
            .safeAreaPadding(.top, Self.barHeight)
            .onScrollGeometryChange(for: Bool.self) {
                $0.contentOffset.y + $0.contentInsets.top > 300
            } action: { _, past in
                scrolled = past
            }
            .overlay(alignment: .top) {
                if scrolled {
                    Palette.ground.frame(height: Self.barHeight).accessibilityHidden(true)
                }
            }
            .ignoresSafeArea()
        }

        /// The tab bar's height; rows scroll to just under it.
        static let barHeight: CGFloat = 120

        /// The Genres row after the last category (`TV-Movies-Rows`): My list,
        /// All movies, then a chip per genre.
        private func genres(_ model: ShelfModel) -> some View {
            VStack(alignment: .leading, spacing: ShelfView.Metrics.tv.headerSpacing) {
                ShelfView.RowHeader(title: "Genres", count: nil) { EmptyView() }
                ShelfGenreChips(model: model, selection: nil, select: { list = $0 }) {
                    ShelfView.Chip(title: "My list", isSelected: false) { list = .myList }
                        .accessibilityIdentifier("\(kind.prefix).genres.myList")
                    ShelfView.Chip(title: ShelfList.all.name(kind), isSelected: false) { list = .all }
                        .accessibilityIdentifier("\(kind.prefix).genres.all")
                }
            }
        }

        /// `TV-Movies-Grid`: under the tab bar, newest first. Menu goes back
        /// to the rows (movies-and-series-browsing/browse-a-genre-or-sort-the-lot).
        private func grid(_ model: ShelfModel, _ list: ShelfList) -> some View {
            ScrollView {
                ShelfGridContent(model: model, list: list, sort: .recentlyAdded, actions: actions)
                    .padding(.top, 128)
                    .padding(.bottom, 60)
            }
            .scrollClipDisabled()
            .ignoresSafeArea()
            .onExitCommand {
                self.list = nil
                refocus()
            }
        }

        /// Puts focus back on the banner's Play button once it exists.
        private func refocus() {
            focus.wrappedValue = nil
            Task {
                await Task.yield()
                focus.wrappedValue = .content
            }
        }
    }

    /// Play, More info and My list. Focus on any of them holds the banner;
    /// moving right past My list or left past Play pages it
    /// (movies-and-series-browsing/new-titles-up-front).
    private struct ShelfTVBannerButtons: View {
        let focus: FocusState<ShellFocus?>.Binding
        @Environment(\.shelfBanner) private var banner
        @FocusState private var focused: Part?

        enum Part: Hashable { case play, info, myList }

        var body: some View {
            Group {
                ShelfBanner.PlayButton(type: .tv)
                    .fixedSize()
                    .focused(focus, equals: .content)
                    .focused($focused, equals: .play)
                ShelfBanner.InfoButton(type: .tv, title: "More info")
                    .fixedSize()
                    .focused($focused, equals: .info)
                ShelfBanner.MyListButton(type: .tv)
                    .focused($focused, equals: .myList)
            }
            .onMoveCommand { direction in
                switch (direction, focused) {
                case (.right, .myList?): banner?.actions.page(1)
                case (.left, .play?): banner?.actions.page(-1)
                default: break
                }
            }
            .onChange(of: focused != nil) { _, inside in
                banner?.actions.interacting(inside)
            }
        }
    }

    /// Loading, the failure message with Retry, or "Nothing here yet".
    /// Something on it always takes focus when the tab opens.
    private struct ShelfTVStatus: View {
        let model: ShelfModel
        let status: ShelfStatus
        let focus: FocusState<ShellFocus?>.Binding
        @Environment(\.shelfPrefix) private var prefix

        var body: some View {
            switch status {
            case .offline(let waiting):
                failure(ShelfStatus.offlineTitle, [ShelfStatus.offlineLine] + waiting)
            case .failed(let waiting):
                failure(ShelfStatus.failedTitle(model.kind), waiting)
            case .loading, .empty, .titles:
                ShelfStatusContent(model: model, status: status)
                    .focusable()
                    .focusEffectDisabled()
                    .focused(focus, equals: .content)
            }
        }

        private func failure(_ title: String, _ lines: [String]) -> some View {
            ShelfView.Message(title: title, lines: lines) {
                ShelfView.RetryButton(retry: model.retry)
                    .focused(focus, equals: .content)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("\(prefix).error")
        }
    }
#endif
