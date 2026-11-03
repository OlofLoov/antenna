import Foundation
import Testing
@testable import AntennaCore

@Suite struct M3UParserTests {
    private func fixture(_ name: String) throws -> String {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures"))
        return try String(contentsOf: url, encoding: .utf8)
    }

    @Test func parsesHeaderAndAttributes() throws {
        let playlist = M3UParser().parse(try fixture("sample.m3u"))
        #expect(playlist.epgURLs == [URL(string: "http://example.com/epg.xml.gz")!])
        #expect(playlist.channels.count == 3)

        let f1 = playlist.channels[0]
        #expect(f1.name == "Sky Sports F1 FHD")
        #expect(f1.epgID == "SkySportsF1.uk")
        #expect(f1.group == "UK | Sports")
        #expect(f1.logoURL?.absoluteString == "http://logo/f1.png")
        #expect(f1.hasCatchup)
        #expect(f1.catchupDays == 7)
        #expect(f1.streamURL.pathExtension == "ts")
    }

    @Test func titleWithCommaInsideQuotedGroupSurvives() throws {
        let playlist = M3UParser().parse(try fixture("sample.m3u"))
        let cartoon = playlist.channels[1]
        #expect(cartoon.name == "Cartoon Network")
        #expect(cartoon.group == "Kids, Family")
        #expect(cartoon.epgID == nil, "empty tvg-id must not become an EPG id")
    }

    @Test func extgrpAppliesWhenNoGroupTitle() throws {
        let playlist = M3UParser().parse(try fixture("sample.m3u"))
        #expect(playlist.channels[2].group == "News")
        #expect(playlist.groups == ["UK | Sports", "Kids, Family", "News"])
    }

    @Test func idsAreStableAndUnique() throws {
        let playlist = M3UParser().parse(try fixture("sample.m3u"))
        #expect(Set(playlist.channels.map(\.id)).count == 3)
        let again = M3UParser().parse(try fixture("sample.m3u"))
        #expect(again.channels.map(\.id) == playlist.channels.map(\.id))
    }
}
