#if os(tvOS)
    import AntennaCore
    import SwiftUI

    /// Follows the Apple TV highlight through the rows of Movies or Series:
    /// brings the focused row up under the tab bar and asks the provider
    /// about the focused title once it has rested 0.8 seconds
    /// (movies-and-series-browsing/expanded-card-for-the-focused-title-on-apple-tv).
    /// It reads the focused row and title itself, so a move between posters
    /// redraws this view and not the screen; the screen redraws only when
    /// the highlight enters or leaves the rows
    /// (movies-and-series-browsing/browsing-stays-responsive).
    struct ShelfTVFocusFollower: View {
        let model: ShelfModel
        let proxy: ScrollViewProxy
        @Binding var position: ScrollPosition
        /// True while the highlight is in a row.
        @Binding var inRows: Bool
        let follow: ShelfPreviewFollow
        let bannerShown: ShelfBannerShown
        let rowHeights: ShelfRowHeights
        let column: ShelfColumnState
        let reduceMotion: Bool
        @Environment(ShelfLibrary.self) private var library
        @Environment(ShelfPlayback.self) private var playback
        @Environment(ShelfActivity.self) private var activity
        @FocusedValue(\.shelfFocusedRow) private var focusedRow
        @FocusedValue(\.shelfFocusedTitle) private var focusedTitle
        /// Counts the moves back to the highlight's column. The focus
        /// engine scrolls again for each, so the row is placed again.
        @State private var corrections = 0

        var body: some View {
            let browsing = browsing
            Color.clear
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .onChange(of: focusedRow != nil, initial: true) { _, now in
                    if inRows != now { inRows = now }
                }
                .onChange(of: focusedTitle?.id) { keepColumn() }
                .prefetchesAroundTheHighlight(row: focusedRow, title: focusedTitle)
                // Nothing moves until the highlight has been in a row, so
                // the banner's buttons take presses as soon as they show.
                .task(id: PlaceKey(row: focusedRow, corrections: corrections)) {
                    guard focusedRow != nil || follow.placedRow != nil else { return }
                    let wait = ShelfRowPlacement.wait(
                        top: focusedRow.flatMap { rowHeights.tops[$0] }, height: focusedRow.flatMap { rowHeights.heights[$0] })
                    if wait > .zero { try? await Task.sleep(for: wait) }
                    guard !Task.isCancelled else { return }
                    follow.placedRow = focusedRow
                    guard let row = focusedRow else {
                        backToTop()
                        return
                    }
                    bringUp(row)
                    #if DEBUG
                        if wait == .zero, UITestingShelf.focusScrollWins { await focusEngineScroll(row) }
                    #endif
                    await keepPlaced(row)
                }
                .task(id: RestKey(title: focusedTitle?.activityKey, browsing: browsing)) {
                    await rest()
                }
        }

        /// True while the highlight is in a row and no page covers the rows.
        private var browsing: Bool {
            focusedRow != nil && library.top == nil
        }

        private struct PlaceKey: Hashable {
            var row: String?
            var corrections: Int
        }

        private struct RestKey: Hashable {
            var title: ActivityKey?
            var browsing: Bool
        }

        /// Asks the provider about the focused title once it has rested, so
        /// its card fills in. A focus change cancels the wait, so posters
        /// passed quickly are never asked about.
        private func rest() async {
            guard browsing, let title = focusedTitle else {
                if follow.schedule.pending != nil { follow.schedule.left() }
                return
            }
            if follow.restoring {
                follow.restoring = false
                follow.schedule.restored(title.id)
                show(title)
                return
            }
            // Coming down from the banner, the schedule starts on its title, which the banner has asked about.
            if follow.schedule.shown == nil, let bannerTitle = bannerShown.title {
                follow.schedule.start(on: bannerTitle.id)
            }
            follow.schedule.focused(title.id, at: .now)
            while let due = follow.schedule.due, due > .now {
                try? await Task.sleep(for: .seconds(due.timeIntervalSinceNow))
                if Task.isCancelled { return }
            }
            guard follow.schedule.check(at: .now) != nil else { return }
            show(title)
        }

        /// Keeps the highlight's column on a move up or down between rows
        /// of posters (`ShelfColumn`). It writes the column, which each
        /// row names as its default poster for a move into it
        /// (`ShelfRowColumn`), so the focus engine lands there in one move.
        /// When it still lands elsewhere, as after a second press before
        /// the row read the new column, this moves the highlight back
        /// before the frame draws.
        private func keepColumn() {
            // A press that came before the last correction took effect wins.
            if let pending = follow.pending {
                model.focusRequests.set(nil, for: pending)
                follow.pending = nil
            }
            guard let row = focusedRow, let title = focusedTitle else {
                follow.spot = nil
                return
            }
            #if DEBUG
                let start = ContinuousClock.now
                defer { PosterTrace.lookup(since: start) }
            #endif
            let moved = follow.spot.flatMap { $0.row == row || follow.restoring ? nil : $0 }
            let passed = moved.flatMap { ShelfColumn.skipped(rowOrder(from: $0.row, to: row), from: $0.row, to: row) }
            if let moved, let between = passed.flatMap(titles(in:)), let passed, !between.isEmpty {
                request(row: passed, index: min(moved.index, between.count - 1), in: between)
                return
            }
            guard let titles = titles(in: row), let index = titles.firstIndex(where: { $0.id == title.id }) else {
                follow.spot = nil
                return
            }
            if let moved, let target = ShelfColumn.target(from: moved.index, landed: index, count: titles.count) {
                #if DEBUG
                    PosterTrace.corrections.add(1, ordering: .relaxed)
                #endif
                request(row: row, index: target, in: titles)
                return
            }
            follow.spot = ShelfPreviewFollow.Spot(row: row, index: index)
            // Every row reads the column for its default focus, so a write
            // costs each row on screen a redraw and the focus engine a new
            // default. Along a row it waits for the highlight to rest; a
            // move up or down sooner is corrected as above.
            follow.columnWrite?.cancel()
            if moved == nil {
                follow.columnWrite = Task { [column] in
                    try? await Task.sleep(for: ShelfColumnState.rest)
                    guard !Task.isCancelled, column.column != index else { return }
                    column.column = index
                }
            } else if column.column != index {
                column.column = index
            }
        }

        /// Asks the poster at `index` of `row` to take the highlight.
        private func request(row: String, index: Int, in titles: [ShelfTitle]) {
            follow.spot = ShelfPreviewFollow.Spot(row: row, index: index)
            follow.columnWrite?.cancel()
            if column.column != index { column.column = index }
            follow.requests += 1
            let key = "\(row)|\(titles[index].id)"
            follow.pending = key
            model.focusRequests.set(follow.requests, for: key)
            corrections += 1
        }

        /// The section's rows top to bottom, as far as a move between
        /// `from` and `to` needs: Continue watching only when it is one of
        /// them, since it is the first row.
        private func rowOrder(from: String, to: String) -> [String] {
            var order: [String] = []
            if from == "continueWatching" || to == "continueWatching" { order.append("continueWatching") }
            if !activity.myList(model).isEmpty { order.append("myList") }
            if !activity.recentlyWatched(model).isEmpty { order.append("recentlyWatched") }
            return order + model.rows.map(\.identifier)
        }

        /// The posters of a row, in order; nil for Continue watching, whose
        /// cards are wider than posters, so the column does not carry over.
        private func titles(in row: String) -> [ShelfTitle]? {
            switch row {
            case "continueWatching": nil
            case "myList": activity.myList(model)
            case "recentlyWatched": activity.recentlyWatched(model)
            default: model.rows.first { $0.identifier == row }?.titles
            }
        }

        private func show(_ title: ShelfTitle) {
            model.preview(title)
        }

        /// Scrolls the focused row so its header sits just under the tab
        /// bar (`ShelfRowPlacement.anchor`).
        private func bringUp(_ row: String) {
            guard library.top == nil else { return }
            let height = rowHeights.heights[row] ?? 392
            let anchor = UnitPoint(x: 0, y: ShelfRowPlacement.anchor(rowHeight: height))
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) {
                proxy.scrollTo(ShelfRowAnchor.id(row), anchor: anchor)
            }
        }

        /// Places `row` again while it rests away from where rows rest. The
        /// focus engine scrolls a newly focused row only until it clears the
        /// tab bar, and when that scroll lands after `bringUp`'s it wins.
        /// Nothing else moves the rows until the next focus change.
        private func keepPlaced(_ row: String) async {
            for _ in 0..<ShelfRowPlacement.attempts {
                try? await Task.sleep(for: ShelfRowPlacement.settle)
                guard !Task.isCancelled, ShelfRowPlacement.misplaced(top: rowHeights.tops[row]) else { return }
                bringUp(row)
            }
        }

        #if DEBUG
            /// What the focus engine does when its own scroll lands a few
            /// frames after `bringUp`'s. It leaves the row's top at the tab
            /// bar's foot.
            private func focusEngineScroll(_ row: String) async {
                try? await Task.sleep(for: .milliseconds(50))
                guard !Task.isCancelled else { return }
                proxy.scrollTo(ShelfRowAnchor.id(row), anchor: .top)
            }
        #endif

        /// Leaving the rows for the banner scrolls back to the top, and the
        /// rest schedule starts over on the banner's title next time. Not while a
        /// page or the player covers the rows, or while the poster it opened
        /// from takes focus back, so that poster stays loaded.
        private func backToTop() {
            guard library.top == nil, playback.playing == nil, library.returning == nil else { return }
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) {
                position.scrollTo(edge: .top)
            }
            follow.schedule = PreviewSchedule()
        }
    }

    /// Where the rest stands as the highlight moves: its schedule, the row
    /// last brought up, and whether a closed page's poster is about to take
    /// focus back. Not observed, so none of it redraws the screen.
    @MainActor
    final class ShelfPreviewFollow {
        var schedule = PreviewSchedule()
        /// The row last brought up under the tab bar, nil once back at the top.
        var placedRow: String?
        /// True from a page's close until its poster has focus again.
        var restoring = false
        /// Where the highlight is: its row and position there.
        struct Spot {
            var row: String
            var index: Int
        }
        var spot: Spot?
        /// Counts the focus requests, so asking a poster twice asks again.
        var requests = 0
        /// The request not yet taken, cleared by the next focus change.
        var pending: String?
        /// The column write waiting for the highlight to rest.
        var columnWrite: Task<Void, Never>?
    }
#endif
