import AntennaCore
import Foundation
import Testing

@Suite struct GuideRowLayoutTests {
    /// 20:00 to 22:00 on Monday 22 March 2027, Stockholm time, as on the `TV-Guide` board.
    let window = DateInterval(start: march(22, 20), end: march(22, 22))
    let now = march(22, 21, 34)

    func show(_ start: Date, _ stop: Date, _ title: String) -> Programme {
        Programme(channelID: "sport1", start: start, stop: stop, title: title)
    }

    func layout(_ programmes: [Programme], at now: Date? = nil) -> [GuideBlock] {
        let segments = GuideRowLayout.segments(programmes, from: march(22, 6), to: march(30, 6))
        return GuideRowLayout.blocks(segments, in: window, now: now ?? self.now)
    }

    @Test("tv-guide-grid/programmes-are-drawn-to-scale each block is as wide as its programme")
    func toScale() {
        let blocks = layout([
            show(march(22, 20), march(22, 20, 30), "Handball Weekly"),
            show(march(22, 20, 30), march(22, 23), "Handball: EHF Champions League"),
        ])
        #expect(blocks.map(\.leading) == [0, 370])
        #expect(blocks.map(\.width) == [366, 1106])
        #expect(blocks.map(\.timing) == [.past, .now])
        #expect(blocks.map(\.startedEarlier) == [false, false])
    }

    @Test("tv-guide-grid/programmes-are-drawn-to-scale a programme that started earlier is clipped and marked")
    func clipped() {
        let blocks = layout([
            show(march(22, 19), march(22, 21), "Snooker: UK Championship"),
            show(march(22, 21), march(22, 23), "Cycling: Tour Down Under, Stage 4"),
        ])
        #expect(blocks.map(\.leading) == [0, 740])
        #expect(blocks.map(\.width) == [736, 736])
        #expect(blocks.map(\.startedEarlier) == [true, false])
        #expect(blocks[0].segment.start == march(22, 19))
        #expect(blocks.map(\.timing) == [.past, .now])
    }

    @Test("tv-guide-grid/programmes-are-drawn-to-scale time with no programme is a gap block")
    func gaps() {
        let segments = GuideRowLayout.segments(
            [show(march(22, 20, 30), march(22, 21), "Pit Lane"), show(march(22, 21, 30), march(22, 22), "Late Show")],
            from: march(22, 6), to: march(30, 6))
        #expect(segments.map(\.start) == [march(22, 6), march(22, 20, 30), march(22, 21), march(22, 21, 30), march(22, 22)])
        #expect(segments.map { $0.programme?.title } == [nil, "Pit Lane", nil, "Late Show", nil])
        #expect(segments.last?.stop == march(30, 6))

        let blocks = GuideRowLayout.blocks(segments, in: window, now: now)
        #expect(blocks.map(\.leading) == [0, 370, 740, 1110])
        #expect(blocks.map(\.width) == [366, 366, 366, 366])
        #expect(blocks[0].startedEarlier)
        #expect(blocks[2].segment.programme == nil)
        #expect(GuideRowLayout.index(of: march(22, 21, 10), in: segments) == 2)
        #expect(GuideRowLayout.index(of: march(31, 0), in: segments) == nil)
    }

    @Test("tv-guide-grid/programmes-are-drawn-to-scale a short programme keeps 40 pt and blocks never overlap")
    func minimumWidth() {
        let blocks = layout([
            show(march(22, 20), march(22, 20, 1), "Ident"),
            show(march(22, 20, 1), march(22, 20, 30), "Weather"),
            show(march(22, 20, 30), march(22, 22), "Film"),
        ])
        #expect(blocks[0].width == GuideRowLayout.minimumWidth)
        #expect(blocks[1].leading == 44)
        #expect(blocks[1].leading + blocks[1].width == 366)
        for (left, right) in zip(blocks, blocks.dropFirst()) {
            #expect(left.leading + left.width + GuideRowLayout.gap <= right.leading)
        }
    }

    @Test("tv-guide-grid/programmes-are-drawn-to-scale overlapping source data never draws two blocks on top of each other")
    func overlaps() {
        let segments = GuideRowLayout.segments(
            [show(march(22, 20), march(22, 21), "First"), show(march(22, 20, 30), march(22, 21, 30), "Second")],
            from: march(22, 20), to: march(22, 21, 30))
        #expect(segments.map(\.start) == [march(22, 20), march(22, 21)])
        #expect(segments.map(\.stop) == [march(22, 21), march(22, 21, 30)])
    }

    @Test("tv-guide-grid/programmes-are-drawn-to-scale a programme turns past when it ends and the next is on now")
    func timingFollowsTheClock() {
        let programmes = [show(march(22, 20), march(22, 21), "News"), show(march(22, 21), march(22, 22), "Film")]
        #expect(layout(programmes, at: march(22, 20, 59)).map(\.timing) == [.now, .future])
        #expect(layout(programmes, at: march(22, 21)).map(\.timing) == [.past, .now])
        #expect(layout(programmes, at: march(22, 22)).map(\.timing) == [.past, .past])
    }

    @Test("tv-guide-grid/channels-without-a-guide-say-so a row with nothing in the window has no blocks")
    func nothingInView() {
        #expect(GuideRowLayout.segments([], from: march(22, 6), to: march(30, 6)).isEmpty)
        let elsewhere = GuideRowLayout.segments([show(march(23, 9), march(23, 10), "Tomorrow")], from: march(23, 9), to: march(23, 10))
        #expect(GuideRowLayout.blocks(elsewhere, in: window, now: now).isEmpty)
    }

    @Test("tv-guide-grid/one-row-per-channel-in-the-current-group only rows on screen and one more are built")
    func rowWindow() {
        let rows = GuideRowWindow(capacity: 7)
        #expect(rows.drawn(of: 42) == 0..<8)
        #expect(rows.drawn(of: 3) == 0..<3)
        #expect(rows.drawn(of: 0).isEmpty)
        #expect(rows.showing(6) == rows)
        let down = rows.showing(9)
        #expect(down.first == 3)
        #expect(down.drawn(of: 42) == 3..<11)
        #expect(down.showing(5) == down)
        #expect(down.showing(1).first == 1)
        #expect(GuideRowWindow(first: 19_995, capacity: 7).drawn(of: 20_000) == 19_995..<20_000)
    }
}
