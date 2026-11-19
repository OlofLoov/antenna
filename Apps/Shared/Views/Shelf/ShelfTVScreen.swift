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
        @State private var position = ScrollPosition(edge: .top)
        @FocusedValue(\.shelfFocusedRow) private var focusedRow
        @FocusedValue(\.shelfFocusedTitle) private var focusedTitle
        @State private var schedule = PreviewSchedule()
        /// The title the preview shows, the banner's until a poster rests.
        @State private var previewTitle: ShelfTitle?
        /// The banner's title, written as it pages. Not observed, so paging
        /// never redraws the screen.
        @State private var bannerShown = ShelfBannerShown()
        /// Preview titles shown for longer than `BannerArt.patience`.
        @State private var previewWaited: Set<String> = []
        /// True from a page's close until its poster has focus again.
        @State private var restoring = false
        @State private var rowHeights = ShelfRowHeights()
        /// The row last brought up under the preview, nil once back at the top.
        @State private var placedRow: String?
        @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

        @Environment(ShelfPlayback.self) private var playback

        /// Posters and the banner play through the playback, open pages through the library, and
        /// change My list through the activity.
        private var actions: ShelfActions {
            .section(kind, library: library, activity: activity, playback: playback)
        }

        var body: some View {
            let page = library.page.flatMap { $0.section == kind && $0.origin != .search ? $0 : nil }
            ZStack {
                section
                    .opacity(page == nil ? 1 : 0)
                    .accessibilityHidden(page != nil)
                    .disabled(page != nil)
                if let page {
                    // Full screen: the shell hides the tab bar and clock while a page is open.
                    TitleScreen(route: page) {
                        TitlePage.Television(
                            plotLines: page.title.kind == .movie ? 4 : 2, artHeight: page.title.kind == .movie ? 1080 : 520
                        ) {
                            EpisodePicker.Section(type: .tv)
                        }
                    }
                    .environment(\.shelfMetrics, .tv)
                    .environment(\.shelfPrefix, kind.prefix)
                }
            }
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
                schedule = PreviewSchedule()
                library.open()
            }
            // The loading holder had focus; once titles replace it, Play takes it.
            .onChange(of: model.status.showsTitles) { _, titles in
                guard titles, focus.wrappedValue == nil || focus.wrappedValue == .content else { return }
                refocus()
            }
            // Select on the tab sends focus to the loading holder, and the
            // focus engine moves it a moment later. When titles replace the
            // holder in that moment, focus leaves the tab for nothing, and
            // Play takes it.
            .onChange(of: focus.wrappedValue) { old, new in
                guard new == nil, case .tab = old, model.status.showsTitles, list == nil, library.page == nil else { return }
                refocus()
            }
        }

        private func rows(_ model: ShelfModel) -> some View {
            let previewing = previewing
            return ScrollViewReader { proxy in
                rowsScroll(model, previewing: previewing)
                    // After the focus engine's own scroll has settled, so the
                    // two never move the rows at once.
                    // Nothing moves until the highlight has been in a row, so
                    // the banner's buttons take presses as soon as they show.
                    .task(id: focusedRow) {
                        guard focusedRow != nil || placedRow != nil else { return }
                        try? await Task.sleep(for: Self.settle)
                        guard !Task.isCancelled else { return }
                        placedRow = focusedRow
                        if let row = focusedRow { bringUp(row, proxy) } else { backToTop() }
                    }
            }
        }

        private func rowsScroll(_ model: ShelfModel, previewing: Bool) -> some View {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: ShelfView.Metrics.tv.rowSpacing) {
                    switch model.status {
                    case .titles(let banner, let waiting):
                        ShelfBannerHost(
                            model: model, actions: actions, paused: previewing, showing: { [bannerShown] in bannerShown.title = $0 }
                        ) {
                            ShelfBanner.Television {
                                ShelfTVBannerButtons(focus: focus)
                            }
                        }
                        // Full bleed behind the tab bar.
                        .padding(.top, -Self.barHeight)
                        ShelfNotices(model: model, banner: banner, waiting: waiting)
                        ShelfRowsContent(model: model, actions: actions) { list = $0 }
                        genres(model)
                    case let status:
                        ShelfTVStatus(model: model, status: status, focus: focus)
                            .padding(.top, 60)
                    }
                }
                // Room for the last row to come up under the preview.
                .padding(.bottom, Self.screenHeight - Self.rowTop - 200)
                .environment(\.shelfRowHeights, rowHeights)
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
            // Rows above the focused one pass under the preview and fade out
            // over 40 pt above its foot.
            .mask(alignment: .top) {
                VStack(spacing: 0) {
                    Color.black.opacity(previewing ? 0 : 1).frame(height: Self.rowTop - 40)
                    LinearGradient(colors: [.black.opacity(previewing ? 0 : 1), .black], startPoint: .top, endPoint: .bottom)
                        .frame(height: 40)
                    Color.black
                }
                .animation(ShelfBanner.crossfade, value: previewing)
            }
            .overlay(alignment: .top) {
                if scrolled, !previewing {
                    Palette.ground.frame(height: Self.barHeight).accessibilityHidden(true)
                }
            }
            .overlay(alignment: .top) {
                ZStack {
                    if previewing {
                        ShelfPreview.Television()
                            .environment(\.shelfPreview, previewContext(model))
                            .transition(.opacity)
                    }
                }
                .animation(ShelfBanner.crossfade, value: previewing)
            }
            .task(id: RestKey(title: focusedTitle?.activityKey, previewing: previewing)) {
                await rest(model)
            }
            .task(id: previewTitle?.id) {
                guard let id = previewTitle?.id, !previewWaited.contains(id) else { return }
                try? await Task.sleep(for: BannerArt.patience)
                if !Task.isCancelled { previewWaited.insert(id) }
            }
            .onChange(of: library.page == nil) { _, closed in
                // Back from a page opened from a poster, its preview shows at
                // once (title-detail-and-episode-picker/back-to-where-you-were).
                guard closed, list == nil, case .poster? = library.returning?.origin else { return }
                restoring = true
            }
            #if DEBUG
                .overlay { UITestingShelf.InfoLoadsProbe() }
            #endif
            .ignoresSafeArea()
        }

        /// True while the highlight is in a row of the section, so the
        /// preview shows (movies-and-series-browsing/preview-of-the-focused-title-on-apple-tv).
        private var previewing: Bool {
            focusedRow != nil && list == nil && library.page == nil
        }

        private struct RestKey: Hashable {
            var title: ActivityKey?
            var previewing: Bool
        }

        /// Shows the focused title once it has rested, and asks the provider
        /// about it then. A focus change cancels the wait.
        private func rest(_ model: ShelfModel) async {
            guard previewing, let title = focusedTitle else {
                if schedule.pending != nil { schedule.left() }
                return
            }
            if restoring {
                restoring = false
                schedule.restored(title.id)
                show(title, model)
                return
            }
            // Coming down from the banner, the preview starts on its title.
            if schedule.shown == nil, let bannerTitle = bannerShown.title {
                schedule.start(on: bannerTitle.id)
                previewTitle = bannerTitle
            }
            schedule.focused(title.id, at: .now)
            while let due = schedule.due, due > .now {
                try? await Task.sleep(for: .seconds(due.timeIntervalSinceNow))
                if Task.isCancelled { return }
            }
            guard schedule.check(at: .now) != nil else { return }
            show(title, model)
        }

        private func show(_ title: ShelfTitle, _ model: ShelfModel) {
            withAnimation(ShelfBanner.crossfade) { previewTitle = title }
            model.preview(title)
        }

        /// Scrolls the focused row so its header sits just under the
        /// preview. The anchor is the point of the row that lands on the same
        /// point of the screen, so it follows from the row's height.
        private func bringUp(_ row: String, _ proxy: ScrollViewProxy) {
            guard library.page == nil, list == nil else { return }
            let height = rowHeights.heights[row] ?? 392
            let anchor = UnitPoint(x: 0, y: Self.rowTop / max(1, Self.screenHeight - height))
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) {
                proxy.scrollTo(ShelfRowAnchor.id(row), anchor: anchor)
            }
        }

        /// Leaving the rows for the banner scrolls back to the top, and the
        /// preview starts over on the banner's title next time. Not while a
        /// page covers the rows, so the poster it opened from stays loaded.
        private func backToTop() {
            guard library.page == nil, list == nil else { return }
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) {
                position.scrollTo(edge: .top)
            }
            schedule = PreviewSchedule()
            previewTitle = nil
        }

        private func previewContext(_ model: ShelfModel) -> PreviewContext? {
            guard let title = previewTitle ?? bannerShown.title else { return nil }
            let details = model.details[title.id]
            let settled = model.answered.contains(title.id) || previewWaited.contains(title.id)
            let art = BannerArt.choose(
                details: details, answered: model.answered.contains(title.id), waited: previewWaited.contains(title.id),
                poster: title.posterURL)
            return PreviewContext(text: BannerText(preview: title, details: details), art: art, bare: art == nil && settled)
        }

        private var reduceMotion: Bool {
            #if DEBUG
                if UITestingShelf.reduceMotion { return true }
            #endif
            return systemReduceMotion
        }

        /// The tab bar's height; rows scroll to just under it.
        static let barHeight: CGFloat = 120
        /// Where the focused row's header aims while the preview shows. On the
        /// simulator it lands about 25 pt lower, still clear of the preview.
        static let rowTop: CGFloat = ShelfPreview.height + 16
        static let screenHeight: CGFloat = 1080
        /// How long a focus move takes to scroll before the rows are placed.
        static let settle = Duration.milliseconds(350)

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
            // The preview keeps the last title it showed.
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
        @FocusState private var focused: Part?

        enum Part: Hashable { case play, info, trailer, myList }

        var body: some View {
            Group {
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
                    .focused($focused, equals: .myList)
                    .onMoveCommand { if $0.reading(direction) == .right { banner?.actions.page(1) } }
            }
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
            // Back from the trailer, by Menu or its end, focus is on Trailer again.
            .onChange(of: playback.playing) { before, now in
                guard now == nil, library.page == nil, case .trailer = before else { return }
                Task {
                    await Task.yield()
                    focused = .trailer
                }
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
                failure(ShelfStatus.offlineTitle(), [ShelfStatus.offlineLine()] + waiting)
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

    /// The title the Apple TV banner shows, for the preview to start on.
    @MainActor
    final class ShelfBannerShown {
        var title: ShelfTitle?
    }
#endif
