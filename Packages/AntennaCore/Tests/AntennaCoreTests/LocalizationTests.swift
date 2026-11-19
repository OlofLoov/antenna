import Foundation
import Testing

@testable import AntennaCore

/// Core's own catalog: the sentences, plural forms, isolates and built-in
/// names every text helper builds through `Words`.
@Suite struct LocalizationTests {
    let english = Locale(identifier: "en_US")

    @Test("localization/counts-use-the-language-s-plural-forms one channel and two channels")
    func englishPlurals() {
        let text = SetupText(locale: english)
        #expect(text.liveChannels(1) == "1 live channel")
        #expect(text.liveChannels(2) == "2 live channels")
        #expect(text.channels(ChannelTally(channels: 1, groups: ["News"])) == "1 live channel in 1 group")
        #expect(SourceStatusText(locale: english).count(1) == "1 channel")
    }

    @Test("localization/numbers-use-the-region-s-digits-and-separators a count groups in the locale's way")
    func grouping() {
        #expect(SetupText(locale: Locale(identifier: "de_DE")).liveChannels(12_500) == "12.500 Live-Sender")
        #expect(SetupText(locale: english).liveChannels(12_500) == "12,500 live channels")
    }

    @Test("localization/no-screen-shows-a-key-or-a-blank-label a language without a table falls back to English")
    func fallback() {
        let japanese = Locale(identifier: "ja_JP")
        #expect(Words(japanese)("Guide unavailable") == "Guide unavailable")
        #expect(ZapBarText.guideUnavailable(japanese) == "Guide unavailable")
    }

    @Test("localization/built-in-names-follow-the-language built-in groups take their name from the catalog")
    func builtInNames() {
        #expect(CatalogueGroup.favorites.label(english) == "Favorites")
        #expect(CatalogueGroup.all.label(english) == "All channels")
        #expect(CatalogueGroup.ungrouped(UUID()).label(english) == "Ungrouped")
        #expect(CatalogueGroup.named(UUID(), "Nyheter").label(english) == "Nyheter")
    }

    @Test("localization/mixed-scripts-keep-their-own-direction source text is isolated where directions mix")
    func isolates() {
        let arabic = Words(Locale(identifier: "ar_SA"))
        #expect(arabic.source("Champions League Live") == "\u{2068}Champions League Live\u{2069}")
        #expect(Words(english).source("الجزيرة") == "\u{2068}الجزيرة\u{2069}")
        #expect(Words(english).source("Sport One") == "Sport One")
        #expect("\u{2068}Sport\u{2069}".withoutIsolates == "Sport")
    }

    @Test("localization/numbers-use-the-region-s-digits-and-separators a channel number never groups and uses the region's digits")
    func channelNumbers() {
        #expect(ChannelNumber(major: 1001).text(english) == "1001")
        #expect(ChannelNumber(major: 6, minor: 1).text(english) == "6.1")
        #expect(ChannelNumber(major: 105).text(Locale(identifier: "ar_SA")) == "١٠٥")
        #expect(ChannelNumber.digit("٥") == "5")
        #expect(ChannelNumber.digit("x") == nil)
        #expect(ChannelNumber.digits("007", locale: Locale(identifier: "ar_SA")) == "٠٠٧")
    }

    @Test("localization/times-and-dates-follow-the-user-s-region a 24-hour region and a forced 12-hour clock")
    func clock() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        let nine = Date(timeIntervalSince1970: 1_799_971_200 + 21 * 3_600)
        #expect(SearchText(calendar: calendar, locale: Locale(identifier: "sv_SE")).time(nine) == "21:00")
        let german12 = SearchText(calendar: calendar, locale: Locale(identifier: "de_DE@hours=h12")).time(nine)
        #expect(german12.hasPrefix("9:00"), "\(german12)")
        #expect(ReminderText(calendar: calendar, locale: Locale(identifier: "sv_SE")).time(nine) == "21:00")
        #expect(SearchText(calendar: calendar, locale: english).time(nine) == "9:00\u{202F}PM")
    }
}
