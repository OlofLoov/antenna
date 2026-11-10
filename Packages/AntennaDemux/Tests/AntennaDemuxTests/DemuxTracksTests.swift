import AntennaCore
import AntennaTestSupport
import Foundation
import Testing

@testable import AntennaDemux

/// Sound and subtitle tracks, picks and cues, and the format reported on the FFmpeg path.
@MainActor
@Suite(.serialized, .timeLimit(.minutes(2))) struct DemuxTracksTests {
    private func playing(_ path: String, options: PlaybackOptions = PlaybackOptions()) async throws -> (FixtureServer, DemuxEngine) {
        let server = try FixtureServer()
        let base = try await server.start()
        let engine = DemuxEngine(sleep: { _ in }, log: { _ in })
        try await engine.load(base.appending(path: path), options: options)
        await engine.play()
        #expect(await eventually { engine.state == .playing })
        return (server, engine)
    }

    private func finish(_ server: FixtureServer, _ engine: DemuxEngine) async {
        await engine.stop()
        await server.stop()
    }

    @Test("playback-engine/audio-and-subtitle-languages starting by preference")
    func listsTracksAndStartsByPreference() async throws {
        let (server, engine) = try await playing("film.mkv", options: PlaybackOptions(preferredAudioLanguages: ["fr"]))
        let tracks = try #require(await current(engine.tracks()))
        #expect(tracks.audio.map(\.id) == ["audio-0", "audio-1"])
        #expect(tracks.audio.map(\.languageCode) == ["eng", "ger"])
        #expect(tracks.audio.map(\.isDefault) == [true, false])
        #expect(tracks.subtitles.map(\.id) == ["subtitle-0", "subtitle-1"])
        #expect(tracks.subtitles.map(\.languageCode) == ["eng", "swe"])
        #expect(tracks.selectedAudio == "audio-0", "no preferred language matches, so the default sound plays")
        #expect(tracks.selectedSubtitle == nil)
        await finish(server, engine)

        let (server2, swedish) = try await playing(
            "film.mkv", options: PlaybackOptions(preferredAudioLanguages: ["de"], preferredSubtitleLanguages: ["sv"]))
        let chosen = try #require(await current(swedish.tracks()))
        #expect(chosen.selectedAudio == "audio-1")
        #expect(chosen.selectedSubtitle == "subtitle-1")
        await finish(server2, swedish)
    }

    @Test("playback-engine/audio-and-subtitle-languages provider track names")
    func providerNames() async throws {
        let (server, engine) = try await playing("film.mkv")
        let tracks = try #require(await current(engine.tracks()))
        #expect(tracks.audio.map(\.name) == [nil, "Sport HD Kommentar"])
        await finish(server, engine)
    }

    @Test("playback-engine/audio-and-subtitle-languages picking and turning off")
    func subtitlesOnCueAndOff() async throws {
        let (server, engine) = try await playing("film.mkv")
        let cues = Recorded(await engine.subtitleCues())
        let picked = ContinuousClock.now
        await engine.selectSubtitle("subtitle-1")
        #expect(await eventually(timeout: .seconds(2)) { cues.values.last == [SubtitleCue(text: "Svensk rad ett")] })
        #expect(ContinuousClock.now - picked <= .seconds(2))
        #expect(await current(engine.tracks())?.selectedSubtitle == "subtitle-1")
        await engine.selectSubtitle(nil)
        #expect(await eventually { cues.values.last == [] })
        #expect(await current(engine.tracks())?.selectedSubtitle == nil)
        cues.cancel()
        await finish(server, engine)
    }

    @Test("playback-engine/audio-and-subtitle-languages picking sound plays on")
    func soundSwitch() async throws {
        let (server, engine) = try await playing("film.mkv")
        let states = Recorded(await engine.states())
        await engine.selectAudio("audio-1")
        #expect(await current(engine.tracks())?.selectedAudio == "audio-1")
        let format = Recorded(await engine.presentation())
        try await Task.sleep(for: .seconds(1))
        #expect(states.values.allSatisfy { $0 == .playing }, "the switch does not stall or reconnect: \(states.values)")
        #expect(format.values.last??.audio == PresentationInfo.Audio(codec: "aac", channels: 2, isDecodable: true))
        states.cancel()
        format.cancel()
        await finish(server, engine)
    }

    @Test("playback-engine/audio-and-subtitle-languages returning to a channel")
    func rememberedPick() async throws {
        let (server, engine) = try await playing(
            "film.mkv", options: PlaybackOptions(preferredAudioLanguages: ["en"], remembered: LanguagePick(audio: "ger", subtitle: "swe")))
        let tracks = try #require(await current(engine.tracks()))
        #expect(tracks.selectedAudio == "audio-1")
        #expect(tracks.selectedSubtitle == "subtitle-1")
        await finish(server, engine)
    }

    @Test("playback-engine/the-screen-learns-the-picture-and-sound-format undecodable sound plays without it and says so")
    func undecodableSound() async throws {
        let (server, engine) = try await playing("undecodable-sound.ts")
        let format = try #require(await current(engine.presentation()).flatMap { $0 })
        #expect(format.video?.width == 320)
        #expect(format.audio?.codec == "opus")
        #expect(format.audio?.isDecodable == false)
        await finish(server, engine)
    }

    @Test("playback-engine/the-screen-learns-the-picture-and-sound-format a mid-stream change reports the new values")
    func resolutionChange() async throws {
        let (server, engine) = try await playing("resize.ts")
        let format = Recorded(await engine.presentation())
        #expect(await eventually { format.values.last??.video?.width == 320 })
        #expect(await eventually(timeout: .seconds(6)) { format.values.last??.video?.width == 640 })
        #expect(format.values.last??.video?.height == 360)
        format.cancel()
        await finish(server, engine)
    }

    @Test("playback-engine/the-screen-learns-the-picture-and-sound-format the format arrives within 2 seconds of the first frame")
    func formatInTime() async throws {
        let server = try FixtureServer()
        let base = try await server.start()
        let engine = DemuxEngine(sleep: { _ in }, log: { _ in })
        let format = Recorded(await engine.presentation())
        try await engine.load(base.appending(path: "channel.ts"))
        await engine.play()
        #expect(await eventually { engine.state == .playing })
        let first = ContinuousClock.now
        #expect(await eventually(timeout: .seconds(2)) { format.values.last??.video?.frameRate == 25 })
        #expect(ContinuousClock.now - first <= .seconds(2))
        let video = try #require(format.values.last??.video)
        #expect((video.width, video.height, video.codec, video.dynamicRange) == (320, 180, "h264", .sdr))
        format.cancel()
        await finish(server, engine)
    }

    @Test("playback-engine/starting-a-channel-replaces-the-old-one-cleanly the picture stays over a hand-over to Apple's player")
    func handOverHoldsThePicture() async throws {
        let (server, engine) = try await playing("channel.ts")
        try await Task.sleep(for: .milliseconds(500))
        await engine.handOver()
        #expect(engine.state == .idle)
        #expect(engine.hold.isHolding, "the last picture is held for the other engine")
        #expect(!engine.videoLayer.isHidden, "the picture stays on screen until the other engine's first frame")
        await engine.stop()
        #expect(!engine.hold.isHolding, "stop clears the held picture")
        #expect(engine.videoLayer.isHidden)
        await server.stop()
    }
}
