import Foundation
import Testing

@testable import AntennaCore

@Suite struct SetupTextTests {
    let text = SetupText(locale: Locale(identifier: "sv-SE"), timeZone: TimeZone(identifier: "UTC") ?? .current)

    @Test("first-run-onboarding/the-checklist-shows-real-progress: the account line shows what the server gave")
    func accountLine() {
        // 1 773 446 400 is 14 March 2026, 00:00 UTC.
        #expect(text.account(expiry: "1773446400", connections: "2") == "Kontot är aktivt till 14 mars 2026 · 2 anslutningar")
        #expect(text.account(expiry: nil, connections: "2") == "2 anslutningar")
        #expect(text.account(expiry: "0", connections: "1") == "1 anslutning")
        #expect(text.account(expiry: "never", connections: "0") == nil)
        #expect(text.account(expiry: nil, connections: nil) == nil)
        #expect(text.account(expiry: "1773446400", connections: nil) == "Kontot är aktivt till 14 mars 2026")
    }

    @Test("first-run-onboarding/the-checklist-shows-real-progress: the account date uses the locale's calendar, not the Mac's")
    func accountCalendar() {
        // On a Mac set to Saudi Arabic the device calendar is Hijri; the date
        // follows the locale passed in, whatever the device uses.
        let japanese = SetupText(locale: Locale(identifier: "en_US@calendar=japanese"), timeZone: .gmt)
        let line = japanese.account(expiry: "1773446400", connections: nil) ?? ""
        #expect(line.contains("Reiwa") && !line.contains("2026"))
        let english = SetupText(locale: .english, timeZone: .gmt)
        #expect(english.account(expiry: "1773446400", connections: nil) == "Account active until March 14, 2026")
    }

    @Test("first-run-onboarding/the-checklist-shows-real-progress: channels, groups, movies and guide with real numbers")
    func numbers() {
        let tally = ChannelTally(channels: 1412, groups: (1...10).map { "G\($0)" })
        #expect(text.channels(tally) == "1\u{a0}412 livekanaler i 10 grupper")
        #expect(text.groupNames(tally.groups) == "G1, G2, G3, G4, G5, G6, G7, G8 och 2 till")
        #expect(text.groupNames(["News", "Sport"]) == "News, Sport")
        #expect(text.movies(1240, series: 86) == "1\u{a0}240 filmer och 86 serier")
        #expect(text.guide(days: 7, matched: 388, total: 412) == "Tablå för 7 dagar · 388 av 412 kanaler")
        #expect(text.downloading(bytes: 2_400_000).hasPrefix("Hämtar tablån · 2,4"))
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
        let tally = ChannelTally(tagged: channels, locale: .english)
        #expect(tally.channels == 4)
        #expect(tally.groups == ["Sport", "News", "Ungrouped"])
        #expect(tally.catchUpChannels == 3)
        #expect(tally.catchUpDays == 7)
        #expect(tally.firstChannel?.name == "Sport 1")
        #expect(tally.firstNumber == 101)
        #expect(ChannelTally(tagged: [], locale: .english).firstChannel == nil)
    }
}
