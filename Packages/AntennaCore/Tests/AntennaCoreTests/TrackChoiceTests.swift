import Foundation
import Testing

@testable import AntennaCore

/// Which sound and subtitles a stream starts with, and the picks kept per channel.
@Suite struct TrackChoiceTests {
    /// English (default) and German sound, English and Swedish subtitles.
    let audio = [
        MediaTrack(id: "audio-0", kind: .audio, languageCode: "eng", name: nil, isDefault: true),
        MediaTrack(id: "audio-1", kind: .audio, languageCode: "ger", name: "Sport HD Kommentar", isDefault: false),
    ]
    let subtitles = [
        MediaTrack(id: "subtitle-0", kind: .subtitle, languageCode: "eng", name: nil, isDefault: false),
        MediaTrack(id: "subtitle-1", kind: .subtitle, languageCode: "swe", name: nil, isDefault: false),
    ]

    private func choice(_ options: PlaybackOptions) -> (audio: MediaTrack.ID?, subtitle: MediaTrack.ID?) {
        TrackChoice.initial(audio: audio, subtitles: subtitles, options: options)
    }

    @Test("playback-engine/audio-and-subtitle-languages starting by preference")
    func startsByPreference() {
        let swedishFirst = choice(PlaybackOptions(preferredAudioLanguages: ["sv", "de-DE"], preferredSubtitleLanguages: ["fi", "sv"]))
        #expect(swedishFirst.audio == "audio-1")
        #expect(swedishFirst.subtitle == "subtitle-1")
        let nothingMatches = choice(PlaybackOptions(preferredAudioLanguages: ["fr"], preferredSubtitleLanguages: ["fr"]))
        #expect(nothingMatches.audio == "audio-0")
        #expect(nothingMatches.subtitle == nil)
        let noDefault = TrackChoice.initial(
            audio: audio.map { MediaTrack(id: $0.id, kind: .audio, languageCode: $0.languageCode, name: nil, isDefault: false) },
            subtitles: [], options: PlaybackOptions())
        #expect(noDefault.audio == "audio-0")
    }

    @Test("playback-engine/audio-and-subtitle-languages returning to a channel")
    func remembered() {
        let picked = LanguagePick(audio: "ger", subtitle: "swe")
        let back = choice(PlaybackOptions(preferredAudioLanguages: ["en"], remembered: picked))
        #expect(back.audio == "audio-1")
        #expect(back.subtitle == "subtitle-1")
        let off = choice(PlaybackOptions(preferredSubtitleLanguages: ["en"], remembered: LanguagePick(audio: "eng", subtitle: nil)))
        #expect(off.subtitle == nil, "subtitles turned off on the channel stay off")
        let gone = choice(PlaybackOptions(preferredAudioLanguages: ["en"], remembered: LanguagePick(audio: "fra", subtitle: "fra")))
        #expect(gone.audio == "audio-0", "a remembered language the stream no longer has falls back to preference")
        #expect(gone.subtitle == nil)
    }

    @Test("playback-engine/audio-and-subtitle-languages the next channel chooses by preference again")
    func nextChannel() {
        var memory = LanguageMemory()
        memory.remember(LanguagePick(audio: "ger", subtitle: "swe"), for: "source/sport")
        let next = choice(PlaybackOptions(preferredAudioLanguages: ["en"], remembered: memory.pick(for: "source/news")))
        #expect(next.audio == "audio-0")
        #expect(next.subtitle == nil)
    }

    @Test("playback-engine/audio-and-subtitle-languages language codes in their two- and three-letter forms match")
    func sameLanguage() {
        #expect(TrackChoice.sameLanguage("eng", "en"))
        #expect(TrackChoice.sameLanguage("en-GB", "en_US"))
        #expect(TrackChoice.sameLanguage("ger", "de"))
        #expect(TrackChoice.sameLanguage("deu", "de-AT"))
        #expect(TrackChoice.sameLanguage("swe", "sv"))
        #expect(TrackChoice.sameLanguage("pt-BR", "por"))
        #expect(!TrackChoice.sameLanguage("und", "en"))
        #expect(!TrackChoice.sameLanguage(nil, "en"))
        #expect(!TrackChoice.sameLanguage("nor", "sv"))
    }

    @Test("playback-engine/audio-and-subtitle-languages a pick is kept per channel, newest 500, by channel and not address")
    func memoryKeepsTheNewest() throws {
        var memory = LanguageMemory()
        for number in 0...LanguageMemory.limit {
            memory.remember(LanguagePick(audio: "eng", subtitle: nil), for: "channel-\(number)")
        }
        #expect(memory.entries.count == LanguageMemory.limit)
        #expect(memory.pick(for: "channel-0") == nil, "the oldest channel is dropped")
        memory.remember(LanguagePick(audio: "ger", subtitle: "swe"), for: "channel-1")
        memory.remember(LanguagePick(audio: "eng", subtitle: nil), for: "channel-501")
        #expect(memory.pick(for: "channel-1") == LanguagePick(audio: "ger", subtitle: "swe"), "a pick made again is kept as newest")
        let decoded = try JSONDecoder().decode(LanguageMemory.self, from: JSONEncoder().encode(memory))
        #expect(decoded == memory)
    }

    @Test("playback-engine/audio-and-subtitle-languages the pick comes from the selected tracks")
    func pickFromTracks() {
        let tracks = TrackList(audio: audio, subtitles: subtitles, selectedAudio: "audio-1", selectedSubtitle: nil)
        #expect(LanguagePick(tracks) == LanguagePick(audio: "ger", subtitle: nil))
    }
}

/// Subtitle text from the containers the FFmpeg path reads.
@Suite struct SubtitleTextTests {
    @Test("playback-engine/audio-and-subtitle-languages text subtitles lose their markup and keep their lines")
    func decodes() {
        #expect(SubtitleText.decode(Data("<i>Svensk</i> rad\r\nett".utf8), codec: "subrip") == "Svensk rad\nett")
        #expect(SubtitleText.decode(Data("{\\an8}Up top".utf8), codec: "subrip") == "Up top")
        #expect(SubtitleText.decode(Data("3,0,Default,,0,0,0,,{\\i1}One\\NTwo, three".utf8), codec: "ass") == "One\nTwo, three")
        var movText = Data([0, 5])
        movText.append(Data("Hello trailing".utf8))
        #expect(SubtitleText.decode(movText, codec: "mov_text") == "Hello")
        #expect(SubtitleText.decode(Data("  ".utf8), codec: "subrip") == nil)
        #expect(!SubtitleText.textCodecs.contains("dvb_subtitle"))
    }
}

/// The TV's mode across channel changes.
@MainActor
@Suite struct DisplayModeKeeperTests {
    @Test("playback-engine/the-screen-learns-the-picture-and-sound-format zapping between channels in the same mode")
    func sameModeKeepsTheTV() async throws {
        var left = 0
        let gate = AsyncStream<Void>.makeStream()
        let keeper = DisplayModeKeeper(sleep: { _ in
            var iterator = gate.stream.makeAsyncIterator()
            await iterator.next()
        }) { left += 1 }
        let pal = DisplayMode(frameRate: 25, dynamicRange: .sdr)
        #expect(keeper.match(pal))
        // Stopping one path and starting the other within the delay.
        keeper.letGo()
        #expect(!keeper.match(pal), "the same mode is not asked for again")
        #expect(keeper.match(DisplayMode(frameRate: 50, dynamicRange: .sdr)))
        #expect(left == 0)
        gate.continuation.finish()
    }

    @Test("playback-engine/the-screen-learns-the-picture-and-sound-format the TV leaves the mode when playback stops")
    func stopLeavesTheMode() async throws {
        var left = 0
        let keeper = DisplayModeKeeper(sleep: { _ in }) { left += 1 }
        #expect(keeper.match(DisplayMode(frameRate: 25, dynamicRange: .hdr10)))
        keeper.letGo()
        for _ in 0..<20 where left == 0 { await Task.yield() }
        #expect(left == 1)
        #expect(keeper.mode == nil)
        #expect(keeper.match(DisplayMode(frameRate: 25, dynamicRange: .hdr10)), "after leaving, the next stream asks again")
    }
}
