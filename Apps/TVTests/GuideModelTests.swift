import AntennaCore
import Foundation
import SwiftData
import Testing

@testable import AntennaTV

/// The guide grid's focus rules over fixture rows, at 21:34 on Monday
/// 22 March 2027 in Stockholm.
@MainActor
@Suite struct GuideModelTests {
    static let source = UUID()
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Stockholm") ?? .gmt
        return calendar
    }()
    let model = GuideModel()

    func at(_ hour: Int, _ minute: Int = 0, day: Int = 22) -> Date {
        calendar.date(from: DateComponents(year: 2027, month: 3, day: day, hour: hour, minute: minute)) ?? .distantPast
    }

    var now: Date { at(21, 34) }

    /// Ten channels. Row 0 has News 20:00–21:00 and Film 21:00–23:00; row 1
    /// Snooker 19:00–21:30, a gap, then Late Show 22:30–23:30; row 2 is still
    /// loading; the rest have one show from 21:00 to 22:00.
    var keys: [RowKey] {
        Channel.tagged(
            (0..<10).map { Channel(id: "c\($0)", name: "Channel \($0)", streamURL: URL(fileURLWithPath: "/c\($0).ts")) },
            sourceID: Self.source
        ).compactMap(RowKey.init)
    }

    func programmes(_ row: Int) -> [Programme] {
        func show(_ title: String, _ start: Date, _ stop: Date) -> Programme {
            Programme(channelID: "c\(row)", start: start, stop: stop, title: title)
        }
        switch row {
        case 0: return [show("News", at(20), at(21)), show("Film", at(21), at(23))]
        case 1: return [show("Snooker", at(19), at(21, 30)), show("Late Show", at(22, 30), at(23, 30))]
        default: return [show("Show \(row)", at(21), at(22))]
        }
    }

    func data(rows: [RowKey]? = nil, hours: Int = 2) -> GuideData {
        let timeline = GuideTimeline(
            horizon: DateInterval(start: at(6), end: at(6, day: 30)), now: now, calendar: calendar, hours: hours)
        let rows = rows ?? keys
        return GuideData(timeline: timeline, rows: rows) { key, window in
            let row = key.position
            return GuideCell.cells(
                state: row == 2 ? .loading : .loaded, programmes: programmes(row), window: window, bounds: timeline.bounds)
        }
    }

    func title(_ data: GuideData) -> String? {
        let cell = model.highlightedCell(data)
        if let placeholder = cell?.placeholder { return placeholder.text }
        return cell?.programme?.title ?? (cell == nil ? nil : "gap")
    }

    @Test("tv-guide-grid/it-opens-on-what-is-on-now on the playing channel's row")
    func opensOnThePlayingRow() {
        let data = data()
        model.open(data, playing: keys[1], now: now)
        #expect(model.windowStart == at(20))
        #expect(model.highlightedRow(data) == 1)
        #expect(title(data) == "gap")
        model.open(data, playing: keys[0], now: now)
        #expect(title(data) == "Film")
        #expect(model.area == .grid)
    }

    @Test("tv-guide-grid/it-opens-on-what-is-on-now on the first row when the group does not hold the playing channel")
    func opensOnTheFirstRow() {
        let data = data(rows: Array(keys.prefix(5)))
        model.open(data, playing: keys[9], now: now)
        #expect(model.highlightedRow(data) == 0)
        #expect(title(data) == "Film")
        model.open(data, playing: nil, now: now)
        #expect(model.highlightedRow(data) == 0)
    }

    @Test("tv-guide-grid/one-row-per-channel-in-the-current-group a far row opens scrolled into view")
    func opensScrolled() {
        let data = data()
        model.open(data, playing: keys[9], now: now)
        #expect(model.rowWindow.first == 3)
        #expect(model.rowWindow.drawn(of: data.rows.count) == 3..<10)
    }

    @Test("tv-guide-grid/open-at-a-programme-found-in-search the programme's half hour and row are in view, highlighted")
    func openAtAProgramme() {
        let data = data()
        model.open(data, row: 8, start: at(21, day: 24))
        #expect(model.windowStart == at(21, day: 24))
        #expect(model.highlightedRow(data) == 8)
        #expect(model.rowWindow.drawn(of: data.rows.count).contains(8))
        #expect(model.area == .grid)
    }

    @Test("tv-guide-grid/an-empty-group puts the highlight on the day list")
    func emptyGroup() {
        let data = data(rows: [])
        model.open(data, playing: nil, now: now)
        #expect(model.area == .days)
        #expect(model.highlightedCell(data) == nil)
        model.leaveDays(data)
        #expect(model.area == .days)
    }

    @Test("tv-guide-grid/programmes-are-drawn-to-scale up and down land on the block holding the start time")
    func upAndDown() {
        let data = data()
        model.open(data, playing: keys[0], now: now)
        #expect(title(data) == "Film")
        model.move(.down, data)
        // Film starts at 21:00, inside Snooker.
        #expect(title(data) == "Snooker")
        model.move(.down, data)
        // Snooker started before the window, so its start counts as 20:00.
        #expect(title(data) == "Loading guide…")
        model.move(.up, data)
        model.move(.up, data)
        #expect(title(data) == "News")
        model.move(.up, data)
        #expect(model.area == .days)
    }

    @Test("tv-guide-grid/programmes-are-drawn-to-scale left and right scroll at the window's edges")
    func leftAndRight() {
        let data = data()
        model.open(data, playing: keys[1], now: now)
        model.move(.right, data)
        #expect(title(data) == "Late Show")
        // Late Show starts at 22:30, past the window, so 22:30 becomes the first column.
        #expect(model.windowStart == at(22, 30))
        // Late Show starts at the left edge: the window goes back a column and the highlight stays.
        model.move(.left, data)
        #expect(model.windowStart == at(22))
        #expect(title(data) == "Late Show")
        model.move(.left, data)
        #expect(model.windowStart == at(22))
        #expect(title(data) == "gap")
        model.move(.left, data)
        model.move(.left, data)
        #expect(model.windowStart == at(21))
        #expect(title(data) == "gap")
        model.move(.left, data)
        #expect(title(data) == "Snooker")
        model.move(.left, data)
        #expect(model.windowStart == at(20, 30))
        #expect(title(data) == "Snooker")
    }

    @Test("tv-guide-grid/the-grid-opens-around-now-and-keeps-time the window stops at the guide's first column")
    func leftBound() {
        let data = data()
        model.open(data, playing: keys[0], now: at(6, 40))
        #expect(model.windowStart == at(6))
        model.move(.left, data)
        #expect(model.windowStart == at(6))
    }

    @Test("tv-guide-grid/pick-a-day down from the chips returns to the block focus came from")
    func daysAndBack() {
        let data = data()
        model.open(data, playing: keys[0], now: now)
        model.move(.up, data)
        #expect(model.area == .days)
        model.leaveDays(data)
        #expect(model.area == .grid)
        #expect(title(data) == "Film")

        model.move(.up, data)
        model.pick(day: 1, data, now: now)
        #expect(model.windowStart == at(20, day: 23))
        #expect(model.selectedDay(data, now: now) == 1)
        model.leaveDays(data)
        #expect(model.highlightedRow(data) == 0)
        #expect(model.highlightedCell(data)?.start ?? .distantPast <= at(20, day: 23))
    }

    @Test("tv-guide-grid/channels-without-a-guide-say-so a row without programmes in view is one placeholder across the window")
    func placeholders() {
        let window = DateInterval(start: at(20), end: at(22))
        let bounds = DateInterval(start: at(6), end: at(6, day: 30))
        func cells(_ state: GuideLoadingState, _ programmes: [Programme] = []) -> [GuideCell] {
            GuideCell.cells(state: state, programmes: programmes, window: window, bounds: bounds)
        }
        let whole = GuideSegment(start: at(20), stop: at(22))
        #expect(cells(.loading) == [GuideCell(segment: whole, placeholder: .loading)])
        #expect(cells(.failed(.offline)) == [GuideCell(segment: whole, placeholder: .failed)])
        #expect(cells(.noData) == [GuideCell(segment: whole, placeholder: .noGuide)])
        let tomorrow = Programme(channelID: "c", start: at(9, day: 23), stop: at(10, day: 23), title: "Tomorrow")
        #expect(cells(.loaded, [tomorrow]) == [GuideCell(segment: whole, placeholder: .noGuide)])
        // A refresh that failed after a load keeps the guide from before: the state stays loaded.
        let tonight = Programme(channelID: "c", start: at(21), stop: at(22), title: "Tonight")
        #expect(cells(.loaded, [tonight]).map(\.programme?.title) == [nil, "Tonight", nil])
    }

    @Test("tv-guide-grid/select-on-a-programme-that-is-on-now tunes the row's channel")
    func selectOnNow() {
        let data = data()
        model.open(data, playing: keys[3], now: now)
        #expect(model.select(data, now: now) == .tune(keys[3]))
        #expect(model.area == .grid)
    }

    @Test("tv-guide-grid/select-on-anything-else-goes-to-watch past, future, gaps and placeholders go to Watch")
    func selectElsewhere() {
        let data = data()
        model.open(data, playing: keys[0], now: now)
        model.move(.left, data)
        #expect(title(data) == "News")
        #expect(model.select(data, now: now) == .watch)
        #expect(model.area == .watch)
        #expect(model.watch(data) == .tune(keys[0]))
        model.leaveWatch(data)
        #expect(model.area == .grid)
        #expect(title(data) == "News")

        model.move(.down, data)
        model.move(.down, data)
        #expect(title(data) == "Loading guide…")
        #expect(model.select(data, now: now) == .watch)
        #expect(model.watch(data) == .tune(keys[2]))
    }
}

/// The Guide window preference on the grid's model, read from an in-memory store.
@MainActor
@Suite struct GuideWindowTests {
    let base = GuideModelTests()
    let container: ModelContainer

    init() throws {
        let schema = Schema(AntennaSchema.models)
        container = try ModelContainer(
            for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none))
    }

    var storedHours: Int { PreferencesStore.current(in: container.mainContext).guideHours }

    @Test("sources-and-settings/choose-how-the-app-behaves the grid shows the stored Guide window")
    func storedWindow() {
        let model = base.model
        #expect(storedHours == 2)
        model.open(base.data(hours: storedHours), playing: base.keys[0], now: base.now)
        #expect(model.window(base.data(hours: storedHours)) == DateInterval(start: base.at(20), end: base.at(22)))

        PreferencesStore.save(AppPreferences(guideHours: 4), in: container.mainContext)
        let data = base.data(hours: storedHours)
        model.fit(data)
        #expect(model.window(data) == DateInterval(start: base.at(20), end: base.at(0, day: 23)))
        #expect(data.timeline.columns(from: model.windowStart).count == 8)
        #expect(model.highlightedCell(data)?.programme?.title == "Film")
    }

    @Test("sources-and-settings/choose-how-the-app-behaves a longer window at the guide's end moves back inside it")
    func longerWindowAtTheEnd() {
        let model = base.model
        let two = base.data()
        model.open(two, row: 3, start: base.at(5, 30, day: 30))
        #expect(model.windowStart == base.at(4, day: 30))

        let four = base.data(hours: 4)
        model.fit(four)
        #expect(model.windowStart == base.at(2, day: 30))
        #expect(model.window(four).end == base.at(6, day: 30))
        #expect(model.highlight == GuideModel.Highlight(row: 3, at: base.at(5, 30, day: 30)))

        // Three hours from 02:00 would end at 05:00, before the highlight.
        model.fit(base.data(hours: 3))
        #expect(model.windowStart == base.at(3, day: 30))
        #expect(model.highlight?.at == base.at(5, 30, day: 30))
    }

    @Test("sources-and-settings/choose-how-the-app-behaves a shorter window keeps the highlight in view")
    func shorterWindowKeepsTheHighlight() {
        let model = base.model
        let four = base.data(hours: 4)
        model.open(four, playing: base.keys[1], now: base.now)
        model.move(.right, four)
        #expect(model.highlightedCell(four)?.programme?.title == "Late Show")
        #expect(model.windowStart == base.at(20))

        let two = base.data()
        model.fit(two)
        #expect(model.windowStart == base.at(21))
        #expect(model.window(two) == DateInterval(start: base.at(21), end: base.at(23)))
        #expect(model.highlightedCell(two)?.programme?.title == "Late Show")
    }
}
