import Testing

@testable import AntennaCore

/// The Subtitles preference and how it reads.
@Suite struct SubtitlePreferenceTests {
    @Test("sources-and-settings/choose-when-subtitles-show a new user starts on Auto, and each choice says what it does")
    func defaultsAndWords() {
        #expect(AppPreferences().subtitles == .auto)
        #expect(SubtitleMode.allCases.map(\.title) == ["Off", "Auto", "Always"])
        #expect(SubtitleMode.auto.explanation == "Subtitles show when the sound is not in one of your languages.")
        #expect(Set(SubtitleMode.allCases.map(\.explanation)).count == 3)
        #expect(AppPreferences(subtitles: .always).subtitles == .always)
    }
}
