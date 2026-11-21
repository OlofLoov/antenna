import Foundation
import Testing

@testable import AntennaCore

/// Guide ids that differ by case, and programmes without a stop.
@Suite struct GuideMatchingTests {
    let source = UUID()

    private func channel(_ epgID: String) -> Channel {
        Channel(id: epgID, name: epgID, streamURL: URL(filePath: "/\(epgID)"), epgID: epgID, sourceID: source)
    }

    @Test("guide-data/programmes-land-on-the-right-channels ids that differ by case match after an exact miss")
    func caseInsensitive() throws {
        let index = GuideIndex(programmes: [source: [programme("bbcone.uk", guideTime(20), guideTime(21), "News")]])
        let bbc = channel("BBCOne.uk")
        let key = try #require(index.key(for: bbc))
        #expect(index.current(for: key, at: guideTime(20, 30))?.title == "News")
        #expect(index.loadingState(for: bbc) == .loaded)
        #expect(index.summary(sourceID: source, channels: [bbc], now: guideTime(19)).channelsWithGuide == 1)
        #expect(index.summary(sourceID: source, channels: [bbc], now: guideTime(19)).unmatched == 0)
        // The playlist's id stays the key, so reminders and favorites compare the same text.
        #expect(key.epgID == "BBCOne.uk")
        let mixed = GuideIndex(programmes: [source: [programme("ONE.se", guideTime(20), guideTime(21), "One")]])
        #expect(mixed.current(for: GuideKey(sourceID: source, epgID: "one.SE"), at: guideTime(20, 30))?.title == "One")
    }

    @Test("guide-data/programmes-land-on-the-right-channels an exact id in a lower guide beats a higher one that differs by case")
    func exactWins() throws {
        let upper = SourceGuide([programme("one", guideTime(20), guideTime(21), "folded")])
        let lower = SourceGuide([programme("One", guideTime(20), guideTime(21), "exact")])
        let index = GuideIndex(sources: [
            source: .init(layers: [.init(reference: .saved, guide: upper), .init(reference: .provider, guide: lower)], state: .loading)
        ])
        let key = GuideKey(sourceID: source, epgID: "One")
        #expect(index.current(for: key, at: guideTime(20, 30))?.title == "exact")
        let both = SourceGuide([
            programme("one", guideTime(20), guideTime(21), "lower case"), programme("One", guideTime(20), guideTime(21), "as written"),
        ])
        let single = GuideIndex(sources: [source: .init(guide: both, state: .loading)])
        #expect(single.current(for: key, at: guideTime(20, 30))?.title == "as written")
    }

    @Test("guide-data/programmes-land-on-the-right-channels a numeric Xtream guide id finds its programmes")
    func numericXtreamID() throws {
        let stream = try JSONDecoder().decode(
            XtreamLiveStream.self, from: Data(#"{"stream_id":42,"name":"A","epg_channel_id":1234}"#.utf8))
        let client = XtreamClient(credentials: .init(server: try #require(URL(string: "http://panel")), username: "u", password: "p"))
        var mapped = client.channel(from: stream, categoryName: nil)
        mapped.sourceID = source
        let index = GuideIndex(programmes: [source: [programme("1234", guideTime(20), guideTime(21), "Match")]])
        #expect(index.loadingState(for: mapped) == .loaded)
    }

    private func parse(_ body: String) throws -> [Programme] {
        try XMLTVParser().parse(Data("<tv>\(body)</tv>".utf8)).programmes
    }

    private func streamed(_ body: String) throws -> [Programme] {
        let file = FileManager.default.temporaryDirectory.appending(path: "stopless-\(UUID().uuidString).xml")
        defer { try? FileManager.default.removeItem(at: file) }
        try Data("<tv>\(body)</tv>".utf8).write(to: file)
        let stream = try #require(InputStream(url: file))
        var programmes: [Programme] = []
        try XMLTVParser().parseSanitized(stream) { programmes.append($0) }
        return programmes.sorted { ($0.channelID, $0.start) < ($1.channelID, $1.start) }
    }

    @Test("xmltv-guide-parsing/programmes-without-a-stop back-to-back programmes end at the next start, the last after two hours")
    func backToBack() throws {
        let body = """
            <programme channel="a" start="20261103200000"><title>A1</title></programme>
            <programme channel="a" start="20261103210000"><title>A2</title></programme>
            <programme channel="a" start="20261103223000"><title>A3</title></programme>
            """
        for programmes in [try parse(body), try streamed(body)] {
            #expect(programmes.map(\.title) == ["A1", "A2", "A3"])
            #expect(programmes.map(\.stop) == [guideTime(21), guideTime(22, 30), guideTime(24, 30)])
        }
    }

    @Test("xmltv-guide-parsing/programmes-without-a-stop mixed with stops and other channels, and an unsorted next start")
    func mixed() throws {
        let body = """
            <programme channel="a" start="20261103200000"><title>A1</title></programme>
            <programme channel="b" start="20261103201000" stop="20261103203000"><title>B1</title></programme>
            <programme channel="a" start="20261103204500" stop="20261103214500"><title>A2</title></programme>
            <programme channel="c" start="20261103220000"><title>C2</title></programme>
            <programme channel="c" start="20261103210000" stop="20261103213000"><title>C1</title></programme>
            """
        let parsed = try parse(body)
        #expect(parsed.map(\.title) == ["A1", "B1", "A2", "C2", "C1"])
        #expect(parsed.map(\.stop) == [guideTime(20, 45), guideTime(20, 30), guideTime(21, 45), guideTime(24), guideTime(21, 30)])
        #expect(try streamed(body).map(\.title) == ["A1", "A2", "B1", "C1", "C2"])
        let guide = SourceGuide(parsed)
        #expect(guide.programmes["a"]?.map(\.stop) == [guideTime(20, 45), guideTime(21, 45)])
    }
}
