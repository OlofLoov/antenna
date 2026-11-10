import AntennaCore
import AntennaTestSupport
import Foundation
import Testing

@testable import Antenna

/// Sound and subtitle tracks, the format and the held picture on Apple's player.
@MainActor
@Suite(.serialized, .timeLimit(.minutes(2))) struct AVPlayerEngineTracksTests {
    private func playing(_ harness: PlayerHarness, _ path: String, options: PlaybackOptions = PlaybackOptions()) async throws {
        try await harness.engine.load(harness.url(path), options: options)
        await harness.engine.play()
        #expect(await eventually { harness.engine.state == .playing })
    }

    @Test("playback-engine/audio-and-subtitle-languages starting by preference")
    func listsTracksAndStartsByPreference() async throws {
        let harness = try await PlayerHarness()
        try await playing(harness, "hls-tracks/index.m3u8", options: PlaybackOptions(preferredAudioLanguages: ["fr"]))
        let tracks = try #require(await current(harness.engine.tracks()))
        #expect(tracks.audio.map(\.id) == ["audio-0", "audio-1"])
        #expect(tracks.audio.map(\.languageCode) == ["en", "de"])
        #expect(tracks.subtitles.map(\.id) == ["subtitle-0", "subtitle-1"])
        #expect(tracks.subtitles.map(\.languageCode) == ["en", "sv"])
        #expect(tracks.selectedAudio == "audio-0", "no preferred language matches, so the default sound plays")
        #expect(tracks.selectedSubtitle == nil)

        try await playing(
            harness, "hls-tracks/index.m3u8", options: PlaybackOptions(preferredAudioLanguages: ["de"], preferredSubtitleLanguages: ["sv"]))
        let chosen = try #require(await current(harness.engine.tracks()))
        #expect(chosen.selectedAudio == "audio-1")
        #expect(chosen.selectedSubtitle == "subtitle-1")
        await harness.stop()
    }

    @Test("playback-engine/audio-and-subtitle-languages provider track names")
    func providerNames() async throws {
        let harness = try await PlayerHarness()
        try await playing(harness, "hls-tracks/index.m3u8")
        let tracks = try #require(await current(harness.engine.tracks()))
        #expect(tracks.audio.last?.name == "Sport HD Kommentar")
        await harness.stop()
    }

    @Test("playback-engine/audio-and-subtitle-languages tracks and names in a film file", .progressiveHTTP)
    func filmTracks() async throws {
        let harness = try await PlayerHarness()
        try await playing(harness, "film.mp4", options: PlaybackOptions(preferredSubtitleLanguages: ["sv"]))
        let tracks = try #require(await current(harness.engine.tracks()))
        #expect(zip(tracks.audio, ["en", "de"]).allSatisfy { TrackChoice.sameLanguage($0.languageCode, $1) })
        #expect(tracks.audio.last?.name == "Sport HD Kommentar")
        #expect(zip(tracks.subtitles, ["en", "sv"]).allSatisfy { TrackChoice.sameLanguage($0.languageCode, $1) })
        #expect(tracks.selectedSubtitle == "subtitle-1")
        await harness.stop()
    }

    @Test("playback-engine/audio-and-subtitle-languages picking and turning off")
    func subtitlesOnCueAndOff() async throws {
        let harness = try await PlayerHarness()
        try await playing(harness, "hls-tracks/index.m3u8")
        let cues = Recorded(await harness.engine.subtitleCues())
        await harness.engine.selectSubtitle("subtitle-1")
        #expect(await current(harness.engine.tracks())?.selectedSubtitle == "subtitle-1")
        #expect(await eventually(timeout: .seconds(4)) { cues.values.contains { $0.contains { $0.text.hasPrefix("Svensk rad") } } })
        await harness.engine.selectSubtitle(nil)
        #expect(await eventually { cues.last == [] })
        #expect(await current(harness.engine.tracks())?.selectedSubtitle == nil)
        cues.cancel()
        await harness.stop()
    }

    @Test("playback-engine/audio-and-subtitle-languages returning to a channel")
    func rememberedPick() async throws {
        let harness = try await PlayerHarness()
        try await playing(
            harness, "hls-tracks/index.m3u8",
            options: PlaybackOptions(preferredAudioLanguages: ["en"], remembered: LanguagePick(audio: "de", subtitle: "sv")))
        let tracks = try #require(await current(harness.engine.tracks()))
        #expect(tracks.selectedAudio == "audio-1")
        #expect(tracks.selectedSubtitle == "subtitle-1")
        await harness.engine.selectAudio("audio-0")
        #expect(await current(harness.engine.tracks())?.selectedAudio == "audio-0")
        await harness.stop()
    }

    @Test("playback-engine/the-screen-learns-the-picture-and-sound-format known formats on Apple's player")
    func reportsTheFormat() async throws {
        let harness = try await PlayerHarness()
        let format = Recorded(await harness.engine.presentation())
        try await playing(harness, "hls/index.m3u8")
        let first = ContinuousClock.now
        #expect(await eventually(timeout: .seconds(2)) { format.last??.video != nil })
        #expect(ContinuousClock.now - first <= .seconds(2))
        let video = try #require(format.last??.video)
        #expect((video.width, video.height, video.codec, video.dynamicRange) == (320, 180, "h264", .sdr))
        if let rate = video.frameRate { #expect(abs(rate - 25) < 0.5) }
        #expect(await eventually { format.last??.audio != nil })
        let audio = try #require(format.last??.audio)
        #expect(audio.codec == "aac")
        #expect(audio.isDecodable)
        await harness.engine.stop()
        #expect(await eventually { format.last == .some(nil) })
        format.cancel()
        await harness.stop()
    }

    @Test("playback-engine/starting-a-channel-replaces-the-old-one-cleanly the old picture stays on Apple's player")
    func holdsThePictureWhileTheNextOpens() async throws {
        let harness = try await PlayerHarness()
        try await playing(harness, "hls/index.m3u8")
        try await Task.sleep(for: .milliseconds(500))
        let next = Task { try await harness.engine.load(harness.url("hls-tracks/index.m3u8")) }
        #expect(
            await eventually(timeout: .seconds(2)) { harness.engine.hold.isHolding }, "the last picture is held while the next item opens")
        try await next.value
        await harness.engine.play()
        #expect(await eventually { harness.engine.state == .playing })
        #expect(!harness.engine.hold.isHolding, "the first frame of the next item replaces it")
        await harness.engine.stop()
        #expect(!harness.engine.hold.isHolding)
        await harness.stop()
    }
}

/// The value a broadcast stream yields first, its current one.
func current<Value: Sendable>(_ stream: AsyncStream<Value>) async -> Value? {
    var iterator = stream.makeAsyncIterator()
    return await iterator.next()
}
