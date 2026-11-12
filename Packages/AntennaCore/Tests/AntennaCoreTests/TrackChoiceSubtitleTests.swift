import Foundation
import Testing

@testable import AntennaCore

/// The subtitles a stream starts with by the Subtitles setting, forced
/// subtitles, and the one-press switch.
@Suite struct TrackChoiceSubtitleTests {
    private func sound(_ code: String?, _ number: Int = 0, isDefault: Bool = false) -> MediaTrack {
        MediaTrack(id: "audio-\(number)", kind: .audio, languageCode: code, name: nil, isDefault: isDefault)
    }

    private func subtitle(_ code: String?, _ number: Int, forced: Bool = false) -> MediaTrack {
        MediaTrack(id: "subtitle-\(number)", kind: .subtitle, languageCode: code, name: nil, isDefault: false, isForced: forced)
    }

    private func start(
        sound: [MediaTrack], subtitles: [MediaTrack], languages: [String], mode: SubtitleMode, remembered: LanguagePick? = nil
    ) -> MediaTrack.ID? {
        TrackChoice.initial(
            audio: sound, subtitles: subtitles,
            options: PlaybackOptions(
                preferredAudioLanguages: languages, preferredSubtitleLanguages: languages, subtitleMode: mode, remembered: remembered)
        ).subtitle
    }

    @Test("playback-engine/subtitles-start-by-the-subtitle-setting Auto with sound the user understands starts off")
    func autoUnderstood() {
        let english = start(
            sound: [sound("eng", isDefault: true)], subtitles: [subtitle("eng", 0), subtitle("swe", 1)], languages: ["en", "sv"],
            mode: .auto)
        #expect(english == nil)
        let secondLanguage = start(
            sound: [sound("swe", isDefault: true)], subtitles: [subtitle("eng", 0)], languages: ["en-GB", "sv-SE"], mode: .auto)
        #expect(secondLanguage == nil, "sound in any of the user's languages counts")
    }

    @Test("playback-engine/subtitles-start-by-the-subtitle-setting Auto with sound in another language starts the first language")
    func autoForeign() {
        let chosen = start(
            sound: [sound("ger", isDefault: true)], subtitles: [subtitle("ger", 0), subtitle("swe", 1), subtitle("eng", 2)],
            languages: ["en", "sv"], mode: .auto)
        #expect(chosen == "subtitle-2")
    }

    @Test("playback-engine/subtitles-start-by-the-subtitle-setting Auto when the stream has none of the user's languages")
    func autoNoMatch() {
        let chosen = start(sound: [sound("ger", isDefault: true)], subtitles: [subtitle("ger", 0)], languages: ["en"], mode: .auto)
        #expect(chosen == nil)
    }

    @Test("playback-engine/subtitles-start-by-the-subtitle-setting sound with no language counts as understood")
    func autoUntagged() {
        #expect(start(sound: [sound(nil)], subtitles: [subtitle("eng", 0)], languages: ["en"], mode: .auto) == nil)
        #expect(start(sound: [sound("und")], subtitles: [subtitle("eng", 0)], languages: ["en"], mode: .auto) == nil)
    }

    @Test("playback-engine/subtitles-start-by-the-subtitle-setting Always starts the first language whatever the sound")
    func always() {
        let chosen = start(sound: [sound("eng", isDefault: true)], subtitles: [subtitle("eng", 0)], languages: ["sv", "en"], mode: .always)
        #expect(chosen == "subtitle-0")
    }

    @Test("playback-engine/subtitles-start-by-the-subtitle-setting Off starts off")
    func off() {
        let chosen = start(sound: [sound("ger", isDefault: true)], subtitles: [subtitle("eng", 0)], languages: ["en"], mode: .off)
        #expect(chosen == nil)
    }

    @Test("playback-engine/subtitles-start-by-the-subtitle-setting a pick on the channel wins")
    func rememberedWins() {
        let tracks = [subtitle("eng", 0), subtitle("swe", 1)]
        let swedish = start(
            sound: [sound("eng", isDefault: true)], subtitles: tracks, languages: ["en"], mode: .auto,
            remembered: LanguagePick(audio: "eng", subtitle: "swe"))
        #expect(swedish == "subtitle-1")
        let turnedOff = start(
            sound: [sound("ger", isDefault: true)], subtitles: tracks, languages: ["en"], mode: .always,
            remembered: LanguagePick(audio: "ger", subtitle: nil))
        #expect(turnedOff == nil, "off on this channel stays off, even with Always")
        let gone = start(
            sound: [sound("ger", isDefault: true)], subtitles: tracks, languages: ["en"], mode: .auto,
            remembered: LanguagePick(audio: "ger", subtitle: "fra"))
        #expect(gone == "subtitle-0", "a language the stream no longer has falls back to the setting")
    }

    @Test("playback-engine/forced-subtitles-in-your-language-show forced subtitles with subtitles off")
    func forcedShows() {
        let tracks = [subtitle("eng", 0), subtitle("eng", 1, forced: true), subtitle("ger", 2, forced: true)]
        let auto = start(sound: [sound("eng", isDefault: true)], subtitles: tracks, languages: ["en"], mode: .auto)
        #expect(auto == "subtitle-1")
        let off = start(sound: [sound("eng", isDefault: true)], subtitles: tracks, languages: ["en"], mode: .off)
        #expect(off == "subtitle-1", "forced subtitles show whatever the setting")
        let turnedOff = start(
            sound: [sound("eng", isDefault: true)], subtitles: tracks, languages: ["en"], mode: .auto,
            remembered: LanguagePick(audio: "eng", subtitle: nil))
        #expect(turnedOff == "subtitle-1")
        let otherLanguage = start(sound: [sound("eng", isDefault: true)], subtitles: tracks, languages: ["sv"], mode: .auto)
        #expect(otherLanguage == nil, "forced subtitles in another language stay off")
    }

    @Test("playback-engine/forced-subtitles-in-your-language-show full subtitles replace forced ones")
    func fullReplacesForced() {
        let tracks = [subtitle("eng", 0, forced: true), subtitle("eng", 1)]
        let chosen = start(sound: [sound("ger", isDefault: true)], subtitles: tracks, languages: ["en"], mode: .auto)
        #expect(chosen == "subtitle-1")
    }

    @Test("playback-engine/forced-subtitles-in-your-language-show a forced selection is kept as off")
    func forcedPickIsOff() {
        let list = TrackList(
            audio: [sound("eng", isDefault: true)], subtitles: [subtitle("eng", 0, forced: true)], selectedAudio: "audio-0",
            selectedSubtitle: "subtitle-0")
        #expect(LanguagePick(list) == LanguagePick(audio: "eng", subtitle: nil))
    }

    @Test("playback-engine/forced-subtitles-in-your-language-show forced subtitles in the list")
    func forcedNames() {
        #expect(TrackName.display(subtitle("eng", 0, forced: true), position: 0, isForced: true) == "English (Forced)")
        #expect(TrackName.display(subtitle(nil, 0, forced: true), position: 0, isForced: true) == "Forced")
        let list = TrackList(audio: [], subtitles: [subtitle("eng", 0, forced: true)], selectedAudio: nil, selectedSubtitle: nil)
        #expect(TrackMenu.subtitles(list).map(\.name) == ["Off", "English (Forced)"])
    }

    @Test("player-controls-and-playback-errors/turn-subtitles-on-or-off-in-one-step one press turns subtitles on or off")
    func switched() {
        let tracks = [subtitle("ger", 0), subtitle("eng", 1, forced: true), subtitle("eng", 2)]
        var list = TrackList(audio: [], subtitles: tracks, selectedAudio: nil, selectedSubtitle: nil)
        #expect(!TrackChoice.fullSubtitlesOn(list))
        #expect(TrackChoice.switched(list, preferred: ["en"]) == "subtitle-2")
        #expect(TrackChoice.switched(list, preferred: ["fr"]) == "subtitle-0", "with no match, the first full track")
        list.selectedSubtitle = "subtitle-1"
        #expect(!TrackChoice.fullSubtitlesOn(list), "forced subtitles alone read as off")
        #expect(TrackChoice.switched(list, preferred: ["en"]) == "subtitle-2")
        list.selectedSubtitle = "subtitle-2"
        #expect(TrackChoice.fullSubtitlesOn(list))
        #expect(TrackChoice.switched(list, preferred: ["en"]) == nil)
        let none = TrackList(audio: [], subtitles: [], selectedAudio: nil, selectedSubtitle: nil)
        #expect(TrackChoice.switched(none, preferred: ["en"]) == nil)
    }
}
