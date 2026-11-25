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
        let reduceMotion: Bool
        @Environment(ShelfLibrary.self) private var library
        @Environment(ShelfPlayback.self) private var playback
        @FocusedValue(\.shelfFocusedRow) private var focusedRow
        @FocusedValue(\.shelfFocusedTitle) private var focusedTitle

        var body: some View {
            let browsing = browsing
            Color.clear
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .onChange(of: focusedRow != nil, initial: true) { _, now in
                    if inRows != now { inRows = now }
                }
                .prefetchesAroundTheHighlight(row: focusedRow, title: focusedTitle)
                // Nothing moves until the highlight has been in a row, so
                // the banner's buttons take presses as soon as they show.
                .task(id: focusedRow) {
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
    }
#endif
