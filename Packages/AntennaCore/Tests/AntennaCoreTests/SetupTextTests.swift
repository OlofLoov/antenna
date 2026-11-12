import Foundation
import Testing

@testable import AntennaCore

@Suite struct SetupTextTests {
    let text = SetupText(locale: Locale(identifier: "sv-SE"), timeZone: TimeZone(identifier: "UTC") ?? .current)

    @Test("first-run-onboarding/the-checklist-shows-real-progress: the account line shows what the server gave")
    func accountLine() {
        // 1 773 446 400 is 14 March 2026, 00:00 UTC.
        #expect(text.account(expiry: "1773446400", connections: "2") == "Account active until 14 mars 2026 · 2 connections")
        #expect(text.account(expiry: nil, connections: "2") == "2 connections")
        #expect(text.account(expiry: "0", connections: "1") == "1 connection")
        #expect(text.account(expiry: "never", connections: "0") == nil)
        #expect(text.account(expiry: nil, connections: nil) == nil)
        #expect(text.account(expiry: "1773446400", connections: nil) == "Account active until 14 mars 2026")
    }

    @Test("first-run-onboarding/the-checklist-shows-real-progress: channels, groups, movies and guide with real numbers")
    func numbers() {
        let tally = ChannelTally(channels: 1412, groups: (1...10).map { "G\($0)" })
        #expect(text.channels(tally) == "1\u{a0}412 live channels in 10 groups")
        #expect(text.groupNames(tally.groups) == "G1, G2, G3, G4, G5, G6, G7, G8 and 2 more")
        #expect(text.groupNames(["News", "Sport"]) == "News, Sport")
        #expect(text.movies(1240, series: 86) == "1\u{a0}240 movies and 86 series")
        #expect(text.guide(days: 7, matched: 388, total: 412) == "Guide for 7 days · 388 of 412 channels")
        #expect(text.downloading(bytes: 2_400_000).hasPrefix("Downloading the guide · 2,4"))
    }

    @Test("first-run-onboarding/a-summary-when-everything-has-loaded: the first channel and catch-up come from the catalogue")
    func tally() throws {
        let source = UUID()
        let url = try #require(URL(string: "http://tally.test/1.ts"))
        let channels = Channel.tagged(
            [
                Channel(id: "a", name: "Sport 2", streamURL: url, group: "Sport", number: 102, hasCatchup: true, catchupDays: 7),
                Channel(id: "b", name: "Sport 1", streamURL: url, group: "Sport", number: 101, hasCatchup: true, catchupDays: 7),
                Channel(id: "c", name: "News", streamURL: url, group: "News", number: 1, hasCatchup: true, catchupDays: 3),
                Channel(id: "d", name: "Loose", streamURL: url),
            ], sourceID: source)
        let tally = ChannelTally(tagged: channels)
        #expect(tally.channels == 4)
        #expect(tally.groups == ["Sport", "News", "Ungrouped"])
        #expect(tally.catchUpChannels == 3)
        #expect(tally.catchUpDays == 7)
        #expect(tally.firstChannel?.name == "Sport 1")
        #expect(tally.firstNumber == 101)
        #expect(ChannelTally(tagged: []).firstChannel == nil)
    }
}
