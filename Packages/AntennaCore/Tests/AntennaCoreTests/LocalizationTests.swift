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
        #expect(SetupText(locale: Locale(identifier: "de_DE")).liveChannels(12_500) == "12.500 live channels")
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
}
