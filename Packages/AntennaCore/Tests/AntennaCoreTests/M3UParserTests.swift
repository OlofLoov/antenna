import Foundation
import Testing

@testable import AntennaCore

@Suite struct M3UParserTests {
    private func fixture(_ name: String) throws -> String {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures"))
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func parse(_ text: String) -> Playlist {
        M3UParser().parse(text)
    }

    @Test("0001/AC-1 header EPG URLs in order")
    func headerEPGURLs() throws {
        let playlist = parse(#"#EXTM3U url-tvg="http://a/epg.xml,http://b/epg.xml.gz""#)
        let expected = try [#require(URL(string: "http://a/epg.xml")), #require(URL(string: "http://b/epg.xml.gz"))]
        #expect(playlist.epgURLs == expected)
    }

    @Test("0001/AC-2 standard attributes map to the channel")
    func standardAttributes() throws {
        let playlist = parse(
            """
            #EXTM3U
            #EXTINF:-1 tvg-id="x.uk" tvg-name="X" tvg-logo="http://l/x.png" group-title="UK" tvg-chno="12",Ignored
            http://s/x.ts
            """)
        let channel = try #require(playlist.channels.first)
        #expect(channel.epgID == "x.uk")
        #expect(channel.name == "X")
        #expect(channel.logoURL?.absoluteString == "http://l/x.png")
        #expect(channel.group == "UK")
        #expect(channel.number == 12)
    }

    @Test("0001/AC-3 title fallback when tvg-name is missing or empty")
    func titleFallback() {
        let playlist = parse(
            """
            #EXTM3U
            #EXTINF:-1 tvg-id="a",Channel Title
            http://s/a.ts
            #EXTINF:-1 tvg-name="",Channel Title
            http://s/b.ts
            """)
        #expect(playlist.channels.map(\.name) == ["Channel Title", "Channel Title"])
    }

    @Test("0001/AC-4 comma inside a quoted attribute")
    func commaInsideQuotedAttribute() throws {
        let playlist = parse(
            """
            #EXTM3U
            #EXTINF:-1 group-title="Kids, Family",Cartoon Network
            http://s/c.ts
            """)
        let channel = try #require(playlist.channels.first)
        #expect(channel.group == "Kids, Family")
        #expect(channel.name == "Cartoon Network")
    }

    @Test("0001/AC-5 empty tvg-id is not an EPG id")
    func emptyTvgID() throws {
        let playlist = parse(
            """
            #EXTM3U
            #EXTINF:-1 tvg-id="",Name
            http://s/n.ts
            """)
        #expect(try #require(playlist.channels.first).epgID == nil)
    }

    @Test("0001/AC-6 EXTGRP applies when no group-title, then clears")
    func extgrpAppliesOnce() {
        let playlist = parse(
            """
            #EXTM3U
            #EXTINF:-1,First
            #EXTGRP:News
            http://s/1.ts
            #EXTINF:-1,Second
            http://s/2.ts
            """)
        #expect(playlist.channels.map(\.group) == ["News", nil])
    }

    @Test("0001/AC-7 group-title wins over EXTGRP")
    func groupTitleWinsOverExtgrp() throws {
        let playlist = parse(
            """
            #EXTM3U
            #EXTINF:-1 group-title="Sport",Match
            #EXTGRP:News
            http://s/m.ts
            """)
        #expect(try #require(playlist.channels.first).group == "Sport")
    }

    @Test("0001/AC-8 catch-up flags")
    func catchupFlags() throws {
        let playlist = parse(
            """
            #EXTM3U
            #EXTINF:-1 catchup="default" catchup-days="7",Name
            http://s/n.ts
            """)
        let channel = try #require(playlist.channels.first)
        #expect(channel.hasCatchup)
        #expect(channel.catchupDays == 7)
    }

    @Test("0001/AC-9 ids are stable across runs and unique within one")
    func stableUniqueIDs() {
        let text = """
            #EXTM3U
            #EXTINF:-1 tvg-id="same.uk",One
            http://s/one.ts
            #EXTINF:-1 tvg-id="same.uk",Two
            http://s/two.ts
            #EXTINF:-1,Three
            http://s/three.ts
            """
        let first = parse(text).channels.map(\.id)
        let second = parse(text).channels.map(\.id)
        #expect(first.count == 3)
        #expect(Set(first).count == 3)
        #expect(first == second)
        // A per-process hash would pass the equality above; the literal id would not.
        #expect(first.first == "same.uk#http://s/one.ts")
    }

    @Test("0001/AC-10 unknown directives are ignored")
    func unknownDirectivesIgnored() throws {
        let playlist = parse(
            """
            #EXTM3U
            #EXTINF:-1,Name
            #EXTVLCOPT:http-user-agent=Foo
            http://s/after.ts
            """)
        #expect(try #require(playlist.channels.first).streamURL.absoluteString == "http://s/after.ts")
    }

    @Test("0001/AC-11 orphan URL lines are skipped")
    func orphanURLSkipped() {
        let playlist = parse(
            """
            #EXTM3U
            http://s/orphan.ts
            #EXTINF:-1,Real
            http://s/real.ts
            """)
        #expect(playlist.channels.map(\.streamURL.absoluteString) == ["http://s/real.ts"])
    }

    @Test("0001/AC-12 empty input", arguments: ["", "#EXTM3U"])
    func emptyInput(text: String) {
        let playlist = parse(text)
        #expect(playlist.channels.isEmpty)
        #expect(playlist.epgURLs.isEmpty)
    }

    @Test("0001/AC-13 group list keeps first-seen order")
    func groupOrder() {
        let playlist = parse(
            """
            #EXTM3U
            #EXTINF:-1 group-title="B",1
            http://s/1.ts
            #EXTINF:-1 group-title="A",2
            http://s/2.ts
            #EXTINF:-1 group-title="B",3
            http://s/3.ts
            #EXTINF:-1 group-title="C",4
            http://s/4.ts
            """)
        #expect(playlist.groups == ["B", "A", "C"])
    }

    /// Benchmark, not CI-gated. Run with `ANTENNA_BENCHMARK=1 swift test`.
    /// Reference machine: Apple M1, 16 GB, debug build.
    @Test(
        "0001/AC-14 50,000 entries parse within 5 seconds",
        .enabled(if: ProcessInfo.processInfo.environment["ANTENNA_BENCHMARK"] != nil),
        .timeLimit(.minutes(1)))
    func largePlaylistBenchmark() {
        var text = "#EXTM3U\n"
        for i in 0..<50_000 {
            text += "#EXTINF:-1 tvg-id=\"c\(i)\" group-title=\"G\(i % 40)\",Channel \(i)\nhttp://s/\(i).ts\n"
        }
        let clock = ContinuousClock()
        var count = 0
        let elapsed = clock.measure { count = parse(text).channels.count }
        #expect(count == 50_000)
        #expect(elapsed < .seconds(5))
    }

    @Test("0001/AC-15 catchup=\"0\" disables catch-up")
    func catchupDisabled() throws {
        let playlist = parse(
            """
            #EXTM3U
            #EXTINF:-1 catchup="0",Name
            http://s/n.ts
            """)
        #expect(try #require(playlist.channels.first).hasCatchup == false)
    }

    @Test("0001/AC-16 legacy tvg-rec")
    func legacyTvgRec() throws {
        let playlist = parse(
            """
            #EXTM3U
            #EXTINF:-1 tvg-rec="3",Name
            http://s/n.ts
            """)
        let channel = try #require(playlist.channels.first)
        #expect(channel.hasCatchup)
        #expect(channel.catchupDays == 3)
    }

    @Test func parsesSampleFixture() throws {
        let playlist = parse(try fixture("sample.m3u"))
        #expect(playlist.epgURLs.map(\.absoluteString) == ["http://example.com/epg.xml.gz"])
        #expect(playlist.channels.count == 3)

        let f1 = playlist.channels[0]
        #expect(f1.name == "Sky Sports F1 FHD")
        #expect(f1.epgID == "SkySportsF1.uk")
        #expect(f1.group == "UK | Sports")
        #expect(f1.hasCatchup)
        #expect(f1.catchupDays == 7)

        #expect(playlist.channels[1].group == "Kids, Family")
        #expect(playlist.channels[2].group == "News")
        #expect(playlist.groups == ["UK | Sports", "Kids, Family", "News"])
    }
}
