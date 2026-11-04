import Foundation
import Testing

@testable import AntennaCore

@Suite struct XMLTVParserTests {
    private func parse(_ xml: String) throws -> XMLTVParser.Result {
        try XMLTVParser().parse(Data(xml.utf8))
    }

    private func document(_ body: String) -> String {
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?><tv>\(body)</tv>"
    }

    private func programme(
        _ children: String, start: String = "20261103200000", stop: String = "20261103210000"
    ) -> String {
        document(#"<programme channel="a" start="\#(start)" stop="\#(stop)">\#(children)</programme>"#)
    }

    private func utc(_ iso: String) throws -> Date {
        try #require(ISO8601DateFormatter().date(from: iso))
    }

    @Test("0002/AC-1 first display-name wins")
    func channelDisplayNames() throws {
        let result = try parse(
            document(#"<channel id="a"><display-name>A HD</display-name><display-name>A</display-name></channel>"#))
        #expect(result.channelNames == ["a": "A HD"])
    }

    @Test("0002/AC-1b an empty first display-name still wins")
    func emptyDisplayNameWins() throws {
        let result = try parse(
            document(#"<channel id="a"><display-name></display-name><display-name>A</display-name></channel>"#))
        #expect(result.channelNames == ["a": ""])
    }

    @Test("0002/AC-2 programme fields map from the fixture")
    func programmeFields() throws {
        let url = try #require(
            Bundle.module.url(forResource: "sample.xmltv", withExtension: nil, subdirectory: "Fixtures"))
        let result = try XMLTVParser().parse(try Data(contentsOf: url))
        let expected = Programme(
            channelID: "SkySportsF1.uk",
            start: try utc("2026-11-03T18:00:00Z"),
            stop: try utc("2026-11-03T20:00:00Z"),
            title: "Grand Prix Live",
            subtitle: "São Paulo",
            summary: "Lights out.",
            category: "Sport",
            iconURL: URL(string: "http://img/gp.jpg"))
        #expect(result.programmes.first == expected)
    }

    @Test("0002/AC-3 absent optional fields are nil")
    func absentOptionalFields() throws {
        let result = try parse(programme("<title>T</title>"))
        let parsed = try #require(result.programmes.first)
        #expect(parsed.title == "T")
        #expect(parsed.subtitle == nil)
        #expect(parsed.summary == nil)
        #expect(parsed.category == nil)
        #expect(parsed.iconURL == nil)
    }

    @Test("0002/AC-3b whitespace-only desc is nil")
    func whitespaceDescIsNil() throws {
        let result = try parse(programme("<title>T</title><desc>  </desc>"))
        #expect(try #require(result.programmes.first).summary == nil)
    }

    @Test("0002/AC-4 timestamp with zone offset")
    func timestampWithOffset() throws {
        let result = try parse(programme("<title>T</title>", start: "20261103200000 +0100", stop: "20261103210000 +0100"))
        let parsed = try #require(result.programmes.first)
        #expect(parsed.start == (try utc("2026-11-03T19:00:00Z")))
        #expect(parsed.stop == (try utc("2026-11-03T20:00:00Z")))
    }

    @Test("0002/AC-4b negative zone offset")
    func timestampWithNegativeOffset() throws {
        let result = try parse(programme("<title>T</title>", start: "20261103200000 -0500", stop: "20261103210000 -0500"))
        let parsed = try #require(result.programmes.first)
        #expect(parsed.start == (try utc("2026-11-04T01:00:00Z")))
        #expect(parsed.stop == (try utc("2026-11-04T02:00:00Z")))
    }

    @Test("0002/AC-5 timestamp without zone is UTC")
    func timestampWithoutZone() throws {
        let result = try parse(programme("<title>T</title>"))
        let parsed = try #require(result.programmes.first)
        #expect(parsed.start == (try utc("2026-11-03T20:00:00Z")))
        #expect(parsed.stop == (try utc("2026-11-03T21:00:00Z")))
    }

    @Test(
        "0002/AC-6 invalid intervals are dropped and the rest kept (AC-6a to AC-6f in argument order)",
        arguments: [
            #"channel="a" start="20261103210000" stop="20261103200000""#,
            #"channel="a" start="20261103200000" stop="20261103200000""#,
            #"channel="a" stop="20261103210000""#,
            #"channel="a" start="20261103200000""#,
            #"start="20261103200000" stop="20261103210000""#,
            #"channel="a" start="2026XX03200000" stop="20261103210000""#,
        ])
    func invalidIntervalsDropped(attributes: String) throws {
        let result = try parse(
            document(
                """
                <programme \(attributes)><title>Bad</title></programme>
                <programme channel="a" start="20261103210000" stop="20261103220000"><title>Good</title></programme>
                """))
        #expect(result.programmes.map(\.title) == ["Good"])
    }

    @Test("0002/AC-7 malformed XML throws")
    func malformedThrows() {
        let xml = #"<tv><programme channel="a" start="20261103200000" stop="20261103210000"><title>T</title></tv>"#
        #expect(throws: (any Error).self) { try parse(xml) }
    }

    @Test(
        "0002/AC-7b empty data and gzip bytes throw",
        arguments: [Data(), Data([0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03])])
    func nonXMLDataThrows(data: Data) {
        #expect(throws: (any Error).self) { try XMLTVParser().parse(data) }
    }

    @Test("0002/AC-8 first repeated title wins")
    func firstTitleWins() throws {
        let result = try parse(programme(#"<title lang="en">A</title><title lang="sv">B</title>"#))
        #expect(try #require(result.programmes.first).title == "A")
    }

    @Test("0002/AC-8b an empty first element is skipped for a later non-empty one")
    func emptyFirstElementSkipped() throws {
        let result = try parse(
            programme(
                """
                <title></title><title>T</title>
                <sub-title> </sub-title><sub-title>S</sub-title>
                <desc></desc><desc>D</desc>
                <category/><category>C</category>
                """))
        let parsed = try #require(result.programmes.first)
        #expect(parsed.title == "T")
        #expect(parsed.subtitle == "S")
        #expect(parsed.summary == "D")
        #expect(parsed.category == "C")
    }

    @Test("0002/AC-9 channel icons are not attributed to programmes")
    func channelIconIgnored() throws {
        let result = try parse(
            document(
                """
                <channel id="a"><display-name>A</display-name><icon src="http://i/logo.png"/></channel>
                <programme channel="a" start="20261103200000" stop="20261103210000"><title>T</title></programme>
                """))
        #expect(try #require(result.programmes.first).iconURL == nil)
    }

    @Test(
        "0002/AC-10 airing check is start-inclusive and stop-exclusive",
        arguments: [
            ("2026-11-03T20:00:00Z", true),
            ("2026-11-03T20:30:00Z", true),
            ("2026-11-03T21:00:00Z", false),
        ])
    func airingCheck(at instant: String, airing: Bool) throws {
        let result = try parse(programme("<title>T</title>"))
        let parsed = try #require(result.programmes.first)
        #expect(parsed.isAiring(at: try utc(instant)) == airing)
    }

    @Test(
        "0002/AC-11 100,000 programmes parse within 20 seconds",
        .enabled(if: ProcessInfo.processInfo.environment["ANTENNA_BENCHMARKS"] == "1"),
        .timeLimit(.minutes(2)))
    func largeGuideBenchmark() throws {
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><tv>"
        for i in 0..<100_000 {
            let hour = i % 24
            let start = String(format: "20261103%02d0000 +0000", hour)
            let stop = String(format: "20261103%02d5900 +0000", hour)
            xml += "<programme start=\"\(start)\" stop=\"\(stop)\" channel=\"c\(i % 500)\">"
            xml += "<title>Programme \(i)</title><desc>Description \(i)</desc><category>Cat</category></programme>"
        }
        xml += "</tv>"
        let data = Data(xml.utf8)
        let clock = ContinuousClock()
        var count = 0
        let elapsed = try clock.measure { count = try XMLTVParser().parse(data).programmes.count }
        #expect(count == 100_000)
        #expect(elapsed < .seconds(20))
    }

    @Test("0002/AC-12 programmes keep document order, duplicates included")
    func documentOrder() throws {
        let result = try parse(
            document(
                """
                <programme channel="a" start="20261103200000" stop="20261103210000"><title>T1</title></programme>
                <programme channel="a" start="20261103200000" stop="20261103210000"><title>T2</title></programme>
                """))
        #expect(result.programmes.map(\.title) == ["T1", "T2"])
    }

    @Test("0002/AC-13 CDATA text is read")
    func cdataText() throws {
        let result = try parse(programme("<title><![CDATA[A & B]]></title><desc><![CDATA[D]]></desc>"))
        let parsed = try #require(result.programmes.first)
        #expect(parsed.title == "A & B")
        #expect(parsed.summary == "D")
    }
}
