import Foundation
import Testing

@testable import AntennaCore

/// 2026-11-03 at `hour`:`minute` UTC. Hours past 23 roll into the next day.
func guideTime(_ hour: Int, _ minute: Int = 0) -> Date {
    Date(timeIntervalSince1970: 1_793_664_000 + TimeInterval(hour * 3600 + minute * 60))
}

func programme(_ channel: String, _ start: Date, _ stop: Date, _ title: String = "") -> Programme {
    Programme(channelID: channel, start: start, stop: stop, title: title)
}

@Suite struct GuideIndexTests {
    let source = UUID()
    let other = UUID()

    @Test("0014/AC-2 programmes join on trimmed id within their source")
    func join() throws {
        let index = GuideIndex(programmes: [
            source: [
                programme("sport1.se\n", guideTime(20), guideTime(21), "match"),
                programme("one", guideTime(20), guideTime(21), "one from A"),
            ],
            other: [programme("one", guideTime(20), guideTime(21), "one from B")],
        ])
        let padded = Channel(id: "a", name: "A", streamURL: URL(filePath: "/a"), epgID: " sport1.se", sourceID: source)
        let key = try #require(GuideKey(channel: padded))
        #expect(index.current(for: key, at: guideTime(20, 30))?.title == "match")
        #expect(index.current(for: key, at: guideTime(20, 30))?.channelID == "sport1.se")
        #expect(index.loadingState(for: padded) == .loaded)

        let otherCase = GuideKey(sourceID: source, epgID: "Sport1.se")
        #expect(index.current(for: otherCase, at: guideTime(20, 30)) == nil)
        #expect(index.loadingState(for: otherCase) == .noData)

        let noID = Channel(id: "b", name: "B", streamURL: URL(filePath: "/b"), sourceID: source)
        #expect(GuideKey(channel: noID) == nil)
        #expect(index.loadingState(for: noID) == .noData)
        let blankID = Channel(id: "c", name: "C", streamURL: URL(filePath: "/c"), epgID: "  ", sourceID: source)
        #expect(GuideKey(channel: blankID) == nil)

        #expect(index.current(for: GuideKey(sourceID: source, epgID: "one"), at: guideTime(20, 30))?.title == "one from A")
        #expect(index.current(for: GuideKey(sourceID: other, epgID: "one"), at: guideTime(20, 30))?.title == "one from B")
    }

    @Test("0014/AC-9 the join counts channels with a guide, past-only included, and unmatched programmes")
    func joinSummary() {
        let guide = SourceGuide([
            programme("a", guideTime(20), guideTime(21)),
            programme("a", guideTime(21), guideTime(22)),
            programme("b", guideTime(18), guideTime(19)),
            programme("nobody", guideTime(20), guideTime(21)),
        ])
        let channels = [
            Channel(id: "1", name: "1", streamURL: URL(filePath: "/1"), epgID: "a ", sourceID: source),
            Channel(id: "2", name: "2", streamURL: URL(filePath: "/2"), epgID: "b", sourceID: source),
            Channel(id: "3", name: "3", streamURL: URL(filePath: "/3"), sourceID: source),
        ]
        let summary = guide.summary(channels: channels, now: guideTime(20, 30))
        #expect(summary == .init(channelsWithGuide: 2, channelsTotal: 3, days: 1, unmatched: 1))
    }

    @Test func compactStorageGivesBackEveryField() throws {
        let icon = try #require(URL(string: "http://img.example/a.png"))
        let input = [
            Programme(
                channelID: " a ", start: guideTime(20), stop: guideTime(21), title: "Same", subtitle: "Part 1",
                summary: "Shared text", category: "News", iconURL: icon),
            Programme(channelID: "a", start: guideTime(21), stop: guideTime(22), title: "Same", summary: "Shared text"),
            Programme(channelID: "b", start: guideTime(20), stop: guideTime(21), title: "", summary: "Other"),
        ]
        let guide = SourceGuide(input)
        #expect(
            guide.programmes["a"] == [
                Programme(
                    channelID: "a", start: guideTime(20), stop: guideTime(21), title: "Same", subtitle: "Part 1",
                    summary: "Shared text", category: "News", iconURL: icon),
                Programme(channelID: "a", start: guideTime(21), stop: guideTime(22), title: "Same", summary: "Shared text"),
            ])
        #expect(
            guide.programmes["b"] == [Programme(channelID: "b", start: guideTime(20), stop: guideTime(21), title: "", summary: "Other")])
    }

    @Test("0014/AC-4 now and next")
    func nowAndNext() {
        let key = GuideKey(sourceID: source, epgID: "ch")
        let index = GuideIndex(programmes: [
            source: [
                programme("ch", guideTime(22), guideTime(23), "late"),
                programme("ch", guideTime(20), guideTime(22), "evening"),
                programme("ch", guideTime(23, 15), guideTime(24), "night"),
            ]
        ])
        #expect(index.current(for: key, at: guideTime(21, 34))?.title == "evening")
        #expect(index.current(for: key, at: guideTime(22))?.title == "late")
        #expect(index.current(for: key, at: guideTime(23, 5)) == nil)
        #expect(index.current(for: key, at: guideTime(19)) == nil)
        #expect(index.current(for: key, at: guideTime(24)) == nil)
        #expect(index.next(for: key, after: guideTime(22), count: 3).map(\.title) == ["late", "night"])
        #expect(index.next(for: key, after: guideTime(22), count: 1).map(\.title) == ["late"])
        #expect(index.next(for: key, after: guideTime(22), count: 0).isEmpty)
    }

    @Test("0014/AC-7 window, overlaps and reach")
    func window() {
        let key = GuideKey(sourceID: source, epgID: "ch")
        let nested = GuideKey(sourceID: source, epgID: "nested")
        let equal = GuideKey(sourceID: source, epgID: "equal")
        let index = GuideIndex(programmes: [
            source: [
                programme("ch", guideTime(19, 30), guideTime(20, 30), "before"),
                programme("ch", guideTime(21), guideTime(21, 30), "after gap"),
                programme("ch", guideTime(22), guideTime(23), "outside"),
                programme("ch", guideTime(21, 45), guideTime(21, 45), "no length"),
                programme("nested", guideTime(20), guideTime(22), "A"),
                programme("nested", guideTime(20, 30), guideTime(21), "B"),
                programme("equal", guideTime(21), guideTime(22), "C"),
                programme("equal", guideTime(21), guideTime(21, 30), "D"),
            ],
            other: [programme("x", guideTime(6), guideTime(7))],
        ])
        let window = DateInterval(start: guideTime(20), end: guideTime(22))
        let found = index.programmes(for: [key, nested, equal, GuideKey(sourceID: other, epgID: "x")], in: window)

        #expect(found[key]?.map(\.title) == ["before", "after gap"])
        #expect(found[nested]?.map(\.title) == ["A", "B"])
        #expect(found[nested]?.first?.stop == guideTime(20, 30))
        #expect(index.current(for: nested, at: guideTime(21, 30)) == nil)
        #expect(found[equal]?.map(\.title) == ["D"])
        #expect(index.current(for: equal, at: guideTime(21, 45)) == nil)
        #expect(found[GuideKey(sourceID: other, epgID: "x")] == nil)

        #expect(index.horizon == DateInterval(start: guideTime(6), end: guideTime(23)))
        #expect(GuideIndex().horizon == nil)
        #expect(GuideIndex(programmes: [source: []]).horizon == nil)
    }
}
