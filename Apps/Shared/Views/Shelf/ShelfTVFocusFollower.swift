#if os(tvOS)
    import AntennaCore
    import SwiftUI

    /// Follows the Apple TV highlight through the rows of Movies or Series:
    /// brings the focused row up under the preview and shows the focused
    /// title in the preview once it rests
    /// (movies-and-series-browsing/preview-of-the-focused-title-on-apple-tv).
    /// It reads the focused row and title itself, so a move between posters
    /// redraws this view and not the screen; the screen redraws when the
    /// preview's title changes or the highlight enters or leaves the rows
    /// (movies-and-series-browsing/browsing-stays-responsive).
    struct ShelfTVFocusFollower: View {
        let model: ShelfModel
        let proxy: ScrollViewProxy
        @Binding var position: ScrollPosition
        /// True while the highlight is in a row.
        @Binding var inRows: Bool
        /// The title the preview shows, the banner's until a poster rests.
        @Binding var previewTitle: ShelfTitle?
        let follow: ShelfPreviewFollow
        let bannerShown: ShelfBannerShown
        let rowHeights: ShelfRowHeights
        let reduceMotion: Bool
        @Environment(ShelfLibrary.self) private var library
        @Environment(ShelfPlayback.self) private var playback
        @FocusedValue(\.shelfFocusedRow) private var focusedRow
        @FocusedValue(\.shelfFocusedTitle) private var focusedTitle

        var body: some View {
            let previewing = previewing
            Color.clear
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .onChange(of: focusedRow != nil, initial: true) { _, now in
                    if inRows != now { inRows = now }
                }
                // Nothing moves until the highlight has been in a row, so
                // the banner's buttons take presses as soon as they show.
                .task(id: focusedRow) {
                    guard focusedRow != nil || follow.placedRow != nil else { return }
                    let wait = ShelfRowPlacement.wait(top: focusedRow.flatMap { rowHeights.tops[$0] })
                    if wait > .zero { try? await Task.sleep(for: wait) }
                    guard !Task.isCancelled else { return }
                    follow.placedRow = focusedRow
                    if let row = focusedRow { bringUp(row) } else { backToTop() }
                }
                .task(id: RestKey(title: focusedTitle?.activityKey, previewing: previewing)) {
                    await rest()
                }
        }

        /// True while the highlight is in a row and no page covers the rows.
        private var previewing: Bool {
            focusedRow != nil && library.top == nil
        }

        private struct RestKey: Hashable {
            var title: ActivityKey?
            var previewing: Bool
        }

        /// Shows the focused title once it has rested, and asks the provider
        /// about it then. A focus change cancels the wait.
        private func rest() async {
            guard previewing, let title = focusedTitle else {
                if follow.schedule.pending != nil { follow.schedule.left() }
                return
            }
            if follow.restoring {
                follow.restoring = false
                follow.schedule.restored(title.id)
                show(title)
                return
            }
            // Coming down from the banner, the preview starts on its title.
            if follow.schedule.shown == nil, let bannerTitle = bannerShown.title {
                follow.schedule.start(on: bannerTitle.id)
                previewTitle = bannerTitle
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
            if previewTitle != title {
                withAnimation(ShelfBanner.crossfade) { previewTitle = title }
            }
            model.preview(title)
        }

        /// Scrolls the focused row so its header sits just under the
        /// preview (`ShelfRowPlacement.anchor`).
        private func bringUp(_ row: String) {
            guard library.top == nil else { return }
            let height = rowHeights.heights[row] ?? 392
            let anchor = UnitPoint(x: 0, y: ShelfRowPlacement.anchor(rowHeight: height))
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) {
                proxy.scrollTo(ShelfRowAnchor.id(row), anchor: anchor)
            }
        }

        /// Leaving the rows for the banner scrolls back to the top, and the
        /// preview starts over on the banner's title next time. Not while a
        /// page or the player covers the rows, so the poster it opened from
        /// stays loaded to take focus back.
        private func backToTop() {
            guard library.top == nil, playback.playing == nil else { return }
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) {
                position.scrollTo(edge: .top)
            }
            follow.schedule = PreviewSchedule()
            previewTitle = nil
        }
    }

    /// Where the preview stands as the highlight moves: its schedule, the
    /// row last brought up, and whether a closed page's poster is about to
    /// take focus back. Not observed, so none of it redraws the screen.
    @MainActor
    final class ShelfPreviewFollow {
        var schedule = PreviewSchedule()
        /// The row last brought up under the preview, nil once back at the top.
        var placedRow: String?
        /// True from a page's close until its poster has focus again.
        var restoring = false
    }
#endif
