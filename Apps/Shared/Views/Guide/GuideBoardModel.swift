#if os(iOS) || os(macOS)
    import AntennaCore
    import Foundation
    import Observation

    /// One cell of the guide, by row and start: what the details describe
    /// and what the keyboard cursor sits on. Read again from the guide each
    /// time, so it follows the clock and a guide that refreshes.
    struct GuideTarget: Hashable, Identifiable {
        var key: RowKey
        var start: Date

        var id: String { "\(key.identifier).\(Int(start.timeIntervalSince1970))" }
    }

    /// Where the guide is asked to scroll. Each value is new, so asking for
    /// the same place twice scrolls twice.
    struct GuideJump: Equatable {
        enum Place: Equatable {
            /// Today around now, with the playing channel's row in view.
            case now(row: RowKey?)
            /// `time` at the grid's left edge, with `row` in view.
            case time(Date, row: RowKey?)
            /// Scrolls only as far as it takes to show the cell.
            case reveal(GuideTarget)
        }

        let place: Place
        let id = UUID()
    }

    /// The guide's zoom step on this device (guide-on-iphone-ipad-and-mac/zoom),
    /// in `UserDefaults`, never in SwiftData or iCloud.
    struct GuideZoomStore {
        static let key = "guide.zoom"
        let defaults: UserDefaults

        /// The app's store. A UI test launched with
        /// `-ui-testing-reset-guide-zoom` starts at the default step.
        static var app: GuideZoomStore {
            #if DEBUG
                _ = resetForUITests
            #endif
            return GuideZoomStore(defaults: .standard)
        }

        #if DEBUG
            /// Runs once per launch, so a zoom picked later in the run is kept.
            private static let resetForUITests: Void = {
                if ProcessInfo.processInfo.arguments.contains("-ui-testing-reset-guide-zoom") {
                    UserDefaults.standard.removeObject(forKey: key)
                }
            }()
        #endif

        func load() -> GuideZoom {
            defaults.object(forKey: Self.key) == nil ? GuideZoom() : GuideZoom(step: defaults.integer(forKey: Self.key))
        }

        func save(_ zoom: GuideZoom) {
            defaults.set(zoom.step, forKey: Self.key)
        }
    }

    /// What the Guide on iPhone, iPad and Mac keeps while the window lives
    /// (guide-on-iphone-ipad-and-mac capability): the time in view, the
    /// zoom, the filter, the open details and the keyboard cursor. The
    /// window root owns one, so the grid and the rows swap without losing
    /// the day or the details. The current group is Live's.
    @MainActor @Observable
    final class GuideBoardModel {
        /// The time at the grid's left edge, or the time the iPhone rows
        /// start from. Nil follows now.
        var time: Date?
        private(set) var zoom: GuideZoom
        /// The iPad and Mac filter field's text.
        var filter = ""
        /// The programme whose details are open.
        var details: GuideTarget?
        /// The cell the arrow keys move, on iPad and Mac with a keyboard.
        var cursor: GuideTarget?
        /// The last scroll another part of the guide asked for.
        private(set) var jump: GuideJump?
        /// A programme another screen asked the guide to open at, until a
        /// guide screen takes it.
        var request: ProgrammeKey?
        /// The window shows the narrow layout, the rows instead of the grid.
        @ObservationIgnored var compact = false
        /// A zoom by button or key keeps the time under the now line; a pinch
        /// keeps the time under the fingers. Nil until the first zoom.
        private(set) var zoomAnchor: ZoomAnchor?

        enum ZoomAnchor: Equatable {
            case nowLine
            /// Points from the grid's left edge.
            case point(Double)
        }

        @ObservationIgnored private let store: GuideZoomStore

        init(store: GuideZoomStore) {
            self.store = store
            zoom = store.load()
        }

        // MARK: Moving

        /// Today around now, with `playing` in view (guide-on-iphone-ipad-and-mac/move-through-the-days).
        func showNow(playing: RowKey?) {
            time = nil
            jump = GuideJump(place: .now(row: playing))
        }

        /// The same time of day on `day`; today with no time chosen is now.
        func pick(day index: Int, timeline: GuideTimeline, now: Date) {
            let days = timeline.days(at: now)
            guard days.indices.contains(index) else { return }
            let target = timeline.time(time ?? now, on: days[index])
            time = target
            jump = GuideJump(place: .time(target, row: nil))
        }

        /// The day chip for the time in view.
        func selectedDay(_ timeline: GuideTimeline, now: Date) -> Int {
            timeline.dayIndex(of: time ?? now, in: timeline.days(at: now))
        }

        /// The grid scrolled to `leading`.
        func scrolled(to leading: Date) {
            time = leading
        }

        // MARK: Zoom

        func zoomIn() { setZoom(zoom.zoomedIn, anchor: .nowLine) }
        func zoomOut() { setZoom(zoom.zoomedOut, anchor: .nowLine) }

        /// A pinch ended at `x` points from the grid's left edge.
        func pinched(by magnification: Double, at x: Double) {
            setZoom(zoom.pinched(by: magnification), anchor: .point(x))
        }

        private func setZoom(_ next: GuideZoom, anchor: ZoomAnchor) {
            guard next != zoom else { return }
            zoomAnchor = anchor
            zoom = next
            store.save(next)
        }

        // MARK: Details

        /// Scrolls the cursor's cell into view.
        func reveal(_ target: GuideTarget) {
            jump = GuideJump(place: .reveal(target))
        }

        func open(_ target: GuideTarget) {
            cursor = target
            details = target
        }

        func closeDetails() {
            details = nil
        }

        // MARK: Banners

        /// Sources whose failed-guide banner the user dismissed.
        private(set) var dismissedBanners: Set<UUID> = []

        func dismissBanner(_ source: UUID) {
            dismissedBanners.insert(source)
        }

        /// The sources whose guide has failed now. One that recovered can
        /// show its banner again the next time it fails.
        func failedSourcesChanged(to failed: Set<UUID>) {
            dismissedBanners.formIntersection(failed)
        }

        // MARK: Open at a programme

        /// Where the guide opens for `request`
        /// (guide-on-iphone-ipad-and-mac/open-at-a-programme): the row of the
        /// first channel with that guide in `rows`, and the cell holding the
        /// programme's start when it is a programme. Nil when no row has it
        /// or its guide has not loaded.
        static func target(
            for request: ProgrammeKey, rows: [RowKey], channel: (RowKey) -> Channel?, cells: (RowKey, DateInterval) -> [GuideCell]
        ) -> GuideTarget? {
            guard let key = rows.first(where: { channel($0).flatMap(GuideKey.init(channel:)) == request.guideKey }) else {
                return nil
            }
            let around = DateInterval(start: request.start, duration: GuideTimeline.column)
            guard let cell = cells(key, around).first(where: { $0.segment.contains(request.start) }), cell.programme != nil else {
                return nil
            }
            return GuideTarget(key: key, start: cell.start)
        }

        /// Opens at `target`: its day, scrolled to it, details open, the
        /// filter cleared. With no target, opens at now with nothing selected.
        func open(at target: GuideTarget?, playing: RowKey?) {
            filter = ""
            guard let target else {
                details = nil
                showNow(playing: playing)
                return
            }
            time = target.start
            jump = GuideJump(place: .time(target.start, row: target.key))
            open(target)
        }
    }
#endif
