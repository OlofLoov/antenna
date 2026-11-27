#if os(tvOS)
    import AntennaCore
    import SwiftUI

    /// Movies or Series under the Apple TV tab bar (board `TV-Movies`,
    /// `TV-Movies-Rows`, `TV-Movies-Expanded`): the banner full bleed, the
    /// rows, then the genre chips. The banner's Play button is where focus
    /// lands when the tab opens. In the rows the focused poster grows into
    /// the expanded card.
    struct ShelfTVScreen: View {
        let kind: ShelfTitle.Kind
        let focus: FocusState<ShellFocus?>.Binding
        @Environment(ShelfLibrary.self) private var library
        @Environment(ShelfActivity.self) private var activity
        @Environment(\.shellBarFocused) private var barFocused

        /// The grid open over the rows, a screen of its own that Menu closes.
        @State private var list: ShelfList?
        @State private var scrolled = false
        @State private var position = ScrollPosition(edge: .top)
        /// True while the highlight is in a row, set by `ShelfTVFocusFollower`.
        @State private var inRows = false
        @State private var follow = ShelfPreviewFollow()
        /// The banner's title, written as it pages. Not observed, so paging
        /// never redraws the screen.
        @State private var bannerShown = ShelfBannerShown()
        @State private var rowHeights = ShelfRowHeights()
        /// The highlight's position in its row, which every row lands on.
        @State private var column = ShelfColumnState()
        @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

        @Environment(ShelfPlayback.self) private var playback

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
                    // Full screen: the shell hides the tab bar and clock while a page is open.
                    LibraryPageView(page: page) { page in
                        TitlePage.Television(
                            plotLines: page.title.kind == .movie ? 4 : 2, artHeight: page.title.kind == .movie ? 1080 : 520
                        ) {
                            EpisodePicker.Section(type: .tv)
                        }
                    } person: {
                        PersonPageLayout.Television()
                    }
                    .environment(\.shelfMetrics, .tv)
                    .environment(\.shelfPrefix, kind.prefix)
                }
            }
            #if DEBUG
                .background(UITestingShelf.Redraws.mark(.screen))
            #endif
        }

        private var section: some View {
            let model = library.model(kind)
            return Group {
                if let list {
                    grid(model, list)
                } else {
                    rows(model)
                }
            }
            .background(Palette.ground)
            .environment(\.shelfMetrics, .tv)
            .environment(\.shelfPrefix, kind.prefix)
            .controlHints(.titleRows(kind))
            .task(id: kind) {
                list = nil
                follow.schedule = PreviewSchedule()
                library.open()
            }
            // The loading holder had focus; once titles replace it, Play takes it.
            // With the highlight in the tab bar, which opens a tab as it passes, focus stays there.
            .onChange(of: model.status.showsTitles) { _, titles in
                guard titles, !barFocused, focus.wrappedValue == nil || focus.wrappedValue == .content else { return }
                refocus()
            }
        }

        private func rows(_ model: ShelfModel) -> some View {
            let browsing = browsing
            return ScrollViewReader { proxy in
                rowsScroll(model, browsing: browsing)
                    .background {
                        ShelfTVFocusFollower(
                            model: model, proxy: proxy, position: $position, inRows: $inRows, follow: follow,
                            bannerShown: bannerShown, rowHeights: rowHeights, column: column, reduceMotion: reduceMotion)
                    }
            }
        }

        private func rowsScroll(_ model: ShelfModel, browsing: Bool) -> some View {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: ShelfView.Metrics.tv.rowSpacing) {
                    switch model.status {
                    case .titles(let banner, let waiting):
                        ShelfTVBanner(model: model, actions: actions, paused: browsing, bannerShown: bannerShown, focus: focus)
                            .equatable()
                            // Full bleed behind the tab bar.
                            .padding(.top, -Self.barHeight)
                        ShelfNotices(model: model, banner: banner, waiting: waiting)
                        ShelfRowsContent(model: model, actions: actions) { list = $0 }
                            .environment(\.shelfExpandedCard, cardSource)
                        genres(model)
                    case let status:
                        ShelfTVStatus(model: model, status: status, focus: focus)
                            .padding(.top, 60)
                    }
                }
                // Room for the last row to come up under the tab bar.
                .padding(.bottom, Self.screenHeight - Self.rowTop - 200)
                .environment(\.shelfRowHeights, rowHeights)
                .environment(\.shelfColumn, column)
            }
            .scrollsToTopFromTabBar($position)
            // Swiping down from the tab bar lands on the banner's Play button
            // (tvos-shell/back-from-a-tab-goes-to-the-tab-bar).
            .focusSection()
            .defaultFocus(focus, .content, priority: .userInitiated)
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
            .overlay(alignment: .topTrailing) { heroClock(shows: !scrolled && !browsing && library.top == nil) }
            .onChange(of: library.top == nil) { _, closed in
                // Back from a page opened from a poster, its details show at
                // once (title-detail-and-episode-picker/back-to-where-you-were).
                guard closed, list == nil, case .poster? = library.returning?.origin else { return }
                follow.restoring = true
                #if DEBUG
                    if UITestingShelf.sectionFocusLandsLast {
                        Task {
                            try? await Task.sleep(for: .milliseconds(50))
                            focus.wrappedValue = .content
                        }
                    }
                #endif
            }
            #if DEBUG
                .overlay { UITestingShelf.InfoLoadsProbe() }
                .overlay { UITestingShelf.RedrawsProbe() }
            #endif
            .ignoresSafeArea()
        }

        /// True while the highlight is in a row of the section and nothing
        /// covers it: the banner holds its title.
        private var browsing: Bool {
            inRows && list == nil && library.top == nil
        }

        /// Each title's details for its expanded card, read per title
        /// (movies-and-series-browsing/expanded-card-for-the-focused-title-on-apple-tv).
        private var cardSource: ExpandedCardSource {
            ExpandedCardSource(owner: ObjectIdentifier(library)) { [library] title in
                library.model(title.kind).cardDetails.value(title.id)
            }
        }

        /// The system tab bar holds no clock, so the hero draws it in its top right (`TV-Shell-TabView`).
        @ViewBuilder private func heroClock(shows: Bool) -> some View {
            if shows {
                TimelineView(.everyMinute) { context in
                    TVClock(date: context.date)
                }
                .padding(.top, Self.clockTop)
                .padding(.trailing, 80)
            }
        }

        private var reduceMotion: Bool {
            #if DEBUG
                if UITestingShelf.reduceMotion { return true }
            #endif
            return systemReduceMotion
        }

        /// The tab bar's height; rows scroll to just under it.
        static let barHeight: CGFloat = ShelfRowPlacement.barHeight
        /// The clock's top, level with the system tab bar.
        static let clockTop: CGFloat = 58
        static let rowTop: CGFloat = ShelfRowPlacement.rowTop
        static let screenHeight: CGFloat = ShelfRowPlacement.screenHeight

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
            .shelfFocusRow("genres")
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

    /// Play, More info, Trailer when the title has a playable one, and My
    /// list. Each move between them starts the banner's wait again; moving right past My
    /// list or left past Play pages it
    /// (movies-and-series-browsing/new-titles-up-front,
    /// movies-and-series-browsing/rating-and-trailer-on-the-banner).
    private struct ShelfTVBannerButtons: View {
        let focus: FocusState<ShellFocus?>.Binding
        @Environment(\.shelfBanner) private var banner
        @Environment(ShelfLibrary.self) private var library
        @Environment(ShelfPlayback.self) private var playback
        @Environment(\.layoutDirection) private var direction
        @Environment(\.shellBarFocused) private var barFocused
        @FocusState private var focused: Part?
        /// True while the banner is on screen, in the tab that is open.
        @State private var shown = false

        enum Part: Hashable { case play, info, trailer, myList }

        var body: some View {
            HStack(spacing: 16) {
                ShelfBanner.PlayButton(type: .tv)
                    .fixedSize()
                    .focused(focus, equals: .content)
                    .focused($focused, equals: .play)
                    .onMoveCommand { if $0.reading(direction) == .left { banner?.actions.page(-1) } }
                ShelfBanner.InfoButton(type: .tv, title: "More info")
                    .fixedSize()
                    .focused($focused, equals: .info)
                ShelfBanner.TrailerButton(type: .tv)
                    .fixedSize()
                    .focused($focused, equals: .trailer)
                ShelfBanner.MyListButton(type: .tv)
                    .fixedSize()
                    .focused($focused, equals: .myList)
                    .onMoveCommand { if $0.reading(direction) == .right { banner?.actions.page(1) } }
            }
            // Up from the rows lands on Play, whichever card the highlight left
            // (movies-and-series-browsing/expanded-card-for-the-focused-title-on-apple-tv, back to the banner).
            .focusSection()
            .defaultFocus($focused, .play, priority: .userInitiated)
            // Every move between the buttons starts the banner's wait again.
            .onChange(of: focused) { _, part in
                banner?.actions.interacting(part != nil)
            }
            // Back from the page More info opened, focus is on More info again
            // (title-detail-and-episode-picker/back-to-where-you-were).
            .task(id: library.returning?.title) {
                guard library.returning?.origin == .banner else { return }
                await Task.yield()
                focused = .info
                library.returned()
            }
            // Down from the tab bar lands on Play, not on the button or the
            // poster nearest the tab (tvos-shell/back-from-a-tab-goes-to-the-tab-bar).
            .onChange(of: barFocused) { was, now in
                guard was, !now, shown, library.top == nil, focused != .play else { return }
                focused = .play
            }
            .onAppear { shown = true }
            .onDisappear { shown = false }
            // Back from the trailer, by Menu or its end, focus is on Trailer again.
            .onChange(of: playback.playing) { before, now in
                guard now == nil, library.top == nil, case .trailer = before else { return }
                Task {
                    await Task.yield()
                    focused = .trailer
                }
            }
        }
    }

    /// Loading, the failure message with Try again, or "Nothing here yet"
    /// with Open Settings. Something on it always takes focus when the tab
    /// opens.
    private struct ShelfTVStatus: View {
        let model: ShelfModel
        let status: ShelfStatus
        let focus: FocusState<ShellFocus?>.Binding

        var body: some View {
            switch status {
            case .offline, .failed:
                ShelfMessage(kind: model.kind, status: status) {
                    ShelfTryAgain(model: model)
                        .focused(focus, equals: .content)
                }
            case .empty:
                ShelfMessage(kind: model.kind, status: status) {
                    ShelfOpenSettings()
                        .focused(focus, equals: .content)
                }
            case .loading, .titles:
                ShelfStatusContent(model: model, status: status)
                    .focusable()
                    .focusEffectDisabled()
                    .focused(focus, equals: .content)
            }
        }
    }

    /// Where and when the focused row of Movies or Series comes to rest:
    /// its header just under the tab bar, with the rows below it in view
    /// (movies-and-series-browsing/expanded-card-for-the-focused-title-on-apple-tv).
    enum ShelfRowPlacement {
        /// The tab bar's height, the top inset of the rows' scroll view.
        static let barHeight: CGFloat = SystemTabBar.bottom
        /// Where the focused row's header rests, 36 pt under the tab bar.
        static let rowTop: CGFloat = barHeight + 36
        static let screenHeight: CGFloat = 1080
        /// How long a move down takes the focus engine to scroll before the rows are placed.
        static let settle = Duration.milliseconds(350)
        /// How far a placed row may sit from `rowTop` before it is placed again.
        static let slack: CGFloat = 8

        /// How long to wait before placing a row whose top is at `top` on
        /// screen and whose height is `height`. A row wholly on screen, or
        /// above where rows rest as after moving up, is placed at once: the
        /// focus engine leaves it where it is. A row cut by the foot of the
        /// screen waits for the focus engine's scroll to settle, so the two
        /// never move the rows at once.
        static func wait(top: CGFloat?, height: CGFloat?) -> Duration {
            guard let top else { return settle }
            if top < rowTop { return .zero }
            return top + (height ?? screenHeight) <= screenHeight ? .zero : settle
        }

        /// How many times a row that rests away from `rowTop` is placed again.
        static let attempts = 3

        /// True when a placed row whose top is at `top` on screen is not
        /// where rows rest, as when the focus engine's scroll lands last.
        static func misplaced(top: CGFloat?) -> Bool {
            guard let top else { return false }
            return abs(top - rowTop) > slack
        }

        /// The anchor that puts a row of `rowHeight` at `rowTop`. The scroll
        /// view lines anchors up within its frame less the tab bar's inset.
        static func anchor(rowHeight: CGFloat) -> CGFloat {
            (rowTop - barHeight) / max(1, screenHeight - barHeight - rowHeight)
        }
    }

    /// The title the Apple TV banner shows. The rest schedule starts on it,
    /// so landing on its poster asks nothing the banner has not asked.
    @MainActor
    final class ShelfBannerShown {
        var title: ShelfTitle?
    }

    /// The banner with its buttons. It redraws for its titles and details
    /// and when the highlight enters or leaves the rows, not as it moves
    /// between posters (movies-and-series-browsing/browsing-stays-responsive).
    private struct ShelfTVBanner: View {
        let model: ShelfModel
        let actions: ShelfActions
        /// True while the highlight is in the rows.
        let paused: Bool
        let bannerShown: ShelfBannerShown
        let focus: FocusState<ShellFocus?>.Binding

        var body: some View {
            ShelfBannerHost(model: model, actions: actions, paused: paused, showing: { [bannerShown] in bannerShown.title = $0 }) {
                ShelfBanner.Television {
                    ShelfTVBannerButtons(focus: focus)
                }
            }
        }
    }

    /// `focus` is the shell's one focus state, so it is left out.
    extension ShelfTVBanner: @MainActor Equatable {
        static func == (lhs: ShelfTVBanner, rhs: ShelfTVBanner) -> Bool {
            lhs.model === rhs.model && lhs.actions == rhs.actions && lhs.paused == rhs.paused && lhs.bannerShown === rhs.bannerShown
        }
    }
#endif
