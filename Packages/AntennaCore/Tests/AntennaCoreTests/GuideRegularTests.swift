import AntennaCore
import Foundation
import Testing

/// The iPad, Mac and iPhone guide's rules on the Apple TV guide's fixtures:
/// Monday 22 March 2027 at 21:34 in Stockholm, a guide to 06:00 on 30 March.
@Suite struct GuideRegularTests {
    let calendar = gridCalendar()
    let now = march(22, 21, 34)
    var timeline: GuideTimeline {
        GuideTimeline(horizon: DateInterval(start: march(22, 6, 10), end: march(30, 6)), now: now, calendar: calendar)
    }
    let scale = GuideZoom().scale

    func show(_ start: Date, _ stop: Date, _ title: String) -> Programme {
        Programme(channelID: "sport1", start: start, stop: stop, title: title)
    }

    @Test("guide-on-iphone-ipad-and-mac/a-time-grid-on-ipad-and-mac opening at 21:34 starts the grid at 21:00")
    func opensHalfAnHourBack() {
        #expect(timeline.regularOpening(at: now, visibleWidth: 800, scale: scale) == march(22, 21))
        #expect(clockText(timeline.regularOpening(at: now, visibleWidth: 800, scale: scale)) == "21:00")
        // 21:00 to 21:34 is 204 pt at 180 pt per half hour; a narrower grid starts at 21:30.
        #expect(timeline.regularOpening(at: now, visibleWidth: 200, scale: scale) == march(22, 21, 30))
        // Never before the guide's first half hour.
        #expect(timeline.regularOpening(at: march(22, 6, 20), visibleWidth: 800, scale: scale) == march(22, 6))
    }

    @Test("guide-on-iphone-ipad-and-mac/a-time-grid-on-ipad-and-mac blocks are 180 pt per half hour and at least 28 pt")
    func blocksAtTheDefaultZoom() {
        let window = DateInterval(start: march(22, 21), end: march(22, 23))
        let segments = GuideRowLayout.segments(
            [
                show(march(22, 20), march(22, 22), "Premier League"),
                show(march(22, 22), march(22, 22, 2), "Trailer"),
                show(march(22, 22, 2), march(22, 23), "Match of the Day"),
            ], from: march(22, 20), to: march(22, 23))
        let blocks = GuideRowLayout.blocks(segments, in: window, now: now, scale: scale)
        #expect(blocks.map(\.leading) == [0, 360, 392])
        #expect(blocks.map(\.width) == [356, 28, 324])
        #expect(blocks.map(\.startedEarlier) == [true, false, false])
        #expect(blocks.map(\.timing) == [.now, .future, .future])
    }

    @Test("guide-on-iphone-ipad-and-mac/a-time-grid-on-ipad-and-mac the Apple TV sizes stay 370, 40 and 300")
    func televisionSizes() {
        #expect(GuideScale.television == GuideScale(columnWidth: 370, minimumBlockWidth: 40, channelColumn: 300))
        #expect(GuideTimeline(horizon: nil, now: now, calendar: calendar).scale == .television)
        #expect(GuideRowLayout.minimumWidth == 40)
        #expect(GuideZoom.channelColumn == 200)
    }

    @Test("guide-on-iphone-ipad-and-mac/a-time-grid-on-ipad-and-mac only the rows and columns on screen are built")
    func viewport() {
        let viewport = GuideViewport(
            x: 900, y: 600, width: 720, height: 600, rowPitch: 60, rowCount: 20_000, timeline: timeline, scale: scale)
        // Rows 10 to 19 are on screen; one more each side.
        #expect(viewport.rows == 9..<21)
        // 900 pt is five columns from 06:00, so 08:30 to 10:30 is on screen; one column of slack each way.
        #expect(viewport.time.start == march(22, 8))
        #expect(viewport.time.end == march(22, 11))
        let top = GuideViewport(x: 0, y: 0, width: 720, height: 600, rowPitch: 60, rowCount: 3, timeline: timeline, scale: scale)
        #expect(top.rows == 0..<3)
        #expect(top.time.start == march(22, 6))
    }

    @Test("guide-on-iphone-ipad-and-mac/a-time-grid-on-ipad-and-mac as the clock passes 22:00 the next programme is on now")
    func timePasses() {
        let segments = GuideRowLayout.segments(
            [show(march(22, 20), march(22, 22), "Premier League"), show(march(22, 22), march(22, 23), "Match of the Day")],
            from: march(22, 20), to: march(22, 23))
        let window = DateInterval(start: march(22, 21), end: march(22, 23))
        let before = GuideRowLayout.blocks(segments, in: window, now: march(22, 21, 59), scale: scale)
        let after = GuideRowLayout.blocks(segments, in: window, now: march(22, 22).addingTimeInterval(5), scale: scale)
        #expect(before.map(\.timing) == [.now, .future])
        #expect(after.map(\.timing) == [.past, .now])
        // The blocks stay where they are; only the line moves.
        #expect(before.map(\.leading) == after.map(\.leading))
        #expect(scale.offset(of: march(22, 22), from: march(22, 21)) - scale.offset(of: march(22, 21, 59), from: march(22, 21)) == 6)
    }

    @Test("guide-on-iphone-ipad-and-mac/move-through-the-days a new time zone moves the day chips and labels")
    func timeZoneChanges() {
        let tokyo = gridCalendar("Asia/Tokyo")
        let moved = GuideTimeline(horizon: timeline.bounds, now: now, calendar: tokyo)
        // 21:34 in Stockholm is 05:34 the next morning in Tokyo.
        #expect(moved.days(at: now).first == tokyo.startOfDay(for: now))
        #expect(moved.days(at: now).first != timeline.days(at: now).first)
        #expect(clockText(moved.regularOpening(at: now, visibleWidth: 800, scale: scale), in: tokyo) == "05:00")
    }

    @Test("guide-on-iphone-ipad-and-mac/zoom four steps, 180 pt by default, buttons off at either end")
    func zoomSteps() {
        let zoom = GuideZoom()
        #expect(zoom.scale.columnWidth == 180)
        #expect(zoom.zoomedIn.scale.columnWidth == 270)
        #expect(!zoom.zoomedIn.canZoomIn)
        #expect(zoom.zoomedIn.zoomedIn == zoom.zoomedIn)
        #expect(zoom.zoomedOut.zoomedOut.scale.columnWidth == 90)
        #expect(!zoom.zoomedOut.zoomedOut.canZoomOut)
        #expect(GuideZoom(step: 9).step == 3)
        #expect(GuideZoom(step: -1).step == 0)
    }

    @Test("guide-on-iphone-ipad-and-mac/zoom a pinch snaps to the nearest step and keeps the time in place")
    func pinch() {
        let zoom = GuideZoom()
        #expect(zoom.pinched(by: 1.4).scale.columnWidth == 270)
        #expect(zoom.pinched(by: 1.1).scale.columnWidth == 180)
        #expect(zoom.pinched(by: 0.6).scale.columnWidth == 120)
        #expect(zoom.pinched(by: 0.1).scale.columnWidth == 90)
        // 21:34 under x = 384 at 270 pt per half hour from 06:00.
        let wider = zoom.zoomedIn.scale
        let offset = GuideZoom.offset(keeping: now, at: 384, origin: march(22, 6), scale: wider)
        #expect(wider.date(at: offset + 384, from: march(22, 6)) == now)
    }

    @Test("guide-on-iphone-ipad-and-mac/move-through-the-days a day chip keeps the time of day")
    func dayChips() {
        let days = timeline.days(at: now)
        #expect(days.count == 9)
        #expect(timeline.time(march(22, 21), on: days[2]) == march(24, 21))
        #expect(timeline.time(march(24, 21), on: days[0]) == march(22, 21))
        #expect(timeline.dayIndex(of: march(23, 0, 30), in: days) == 1)
        // The last day ends with the guide at 06:00.
        #expect(timeline.time(march(22, 21), on: days[8]) == march(30, 6))
    }

    @Test("guide-on-iphone-ipad-and-mac/move-through-the-days the 2027-03-28 clock change skips an hour")
    func clockChange() {
        let days = timeline.days(at: now)
        // 02:30 does not exist on 28 March; the jump lands on 03:00.
        #expect(timeline.time(march(22, 2, 30), on: days[6]) == march(28, 3))
        let columns = timeline.columns(in: DateInterval(start: march(28, 1), end: march(28, 4)))
        #expect(columns.map { clockText($0) } == ["01:00", "01:30", "03:00", "03:30"])
    }

    @Test("guide-on-iphone-ipad-and-mac/move-through-the-days the grid cannot scroll outside the guide")
    func scrollLimits() {
        #expect(timeline.scrollClamp(march(21, 12)) == march(22, 6))
        #expect(timeline.scrollClamp(march(31, 12)) == march(30, 6))
        #expect(timeline.width(at: scale) == timeline.bounds.duration / 1800 * 180)
        let short = GuideTimeline(horizon: DateInterval(start: march(22, 18), end: march(22, 23)), now: now, calendar: calendar)
        #expect(short.days(at: now).count == 1)
        #expect(GuideTimeline(horizon: nil, now: now, calendar: calendar).days(at: now).count == 1)
    }

    @Test("guide-on-iphone-ipad-and-mac/one-row-per-channel-on-iphone cards start at the programme on now")
    func strip() {
        let cards = GuideStrip.cards(
            [
                show(march(22, 19), march(22, 20), "Earlier"),
                show(march(22, 20), march(22, 22), "Premier League"),
                show(march(22, 22), march(22, 23), "Match of the Day"),
                show(march(22, 23, 15), march(22, 23, 45), "Sports Tonight"),
            ], from: now)
        #expect(cards.map { $0.programme?.title } == ["Premier League", "Match of the Day", nil, "Sports Tonight"])
        #expect(cards[2].start == march(22, 23))
        #expect(cards[2].stop == march(22, 23, 15))
        #expect(GuideStrip.cards([show(march(22, 22), march(22, 23), "Later")], from: now).map(\.start) == [march(22, 22)])
        #expect(GuideStrip.cards([show(march(22, 19), march(22, 20), "Over")], from: now).isEmpty)
    }

    @Test("guide-on-iphone-ipad-and-mac/filter-channels-by-typing a name or the start of a number matches")
    func filter() {
        #expect(ChannelFilter("spo").matches(name: "Sport One", number: 104))
        #expect(ChannelFilter("10").matches(name: "Sport One", number: 104))
        #expect(!ChannelFilter("11").matches(name: "Sport One", number: 104))
        #expect(!ChannelFilter("news").matches(name: "Sport One", number: 104))
        #expect(ChannelFilter("").matches(name: "Sport One", number: 104))
    }

    @Test("guide-on-iphone-ipad-and-mac/playback-carries-on-out-of-sight the bar names the channel, programme and time left")
    func nowPlaying() {
        let programme = Programme(channelID: "s1", start: march(22, 20), stop: march(22, 22), title: "Premier League")
        let text = GuideNowPlaying(channel: "Sport One", number: 104, state: .loaded, current: programme, now: now)
        #expect(text.channel == "104 Sport One")
        #expect(text.title == "Premier League")
        #expect(text.detail == "104 Sport One · 26 min left")
        #expect(text.progress.map { ($0 * 100).rounded() } == 78)
        let none = GuideNowPlaying(channel: "Sport One", number: nil, state: .noData, current: nil, now: now)
        #expect(none.title == "No programme information")
        #expect(none.detail == "Sport One")
        #expect(none.progress == nil)
    }
}
