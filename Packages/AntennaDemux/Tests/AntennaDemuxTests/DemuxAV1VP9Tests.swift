import AntennaCore
import AntennaTestSupport
import CoreMedia
import Foundation
import Testing

@testable import AntennaDemux

/// AV1 and VP9 on the FFmpeg path decode in hardware or not at all
/// (playback-engine/av1-and-vp9-play-where-the-device-decodes-them).
@MainActor
@Suite(.serialized, .timeLimit(.minutes(1))) struct DemuxAV1VP9Tests {
    @Test(
        "playback-engine/av1-and-vp9-play-where-the-device-decodes-them VP9 plays where the device decodes it",
        .enabled(if: SampleBuilder.hardwareDecodes("vp9")), arguments: ["vp9.webm", "vp9.mp4"])
    func vp9Plays(file: String) async throws {
        try await plays(file, codec: "vp9")
    }

    @Test(
        "playback-engine/av1-and-vp9-play-where-the-device-decodes-them AV1 plays where the device decodes it",
        .enabled(if: SampleBuilder.hardwareDecodes("av1")), arguments: ["av1.mkv", "av1.mp4"])
    func av1Plays(file: String) async throws {
        try await plays(file, codec: "av1")
    }

    @Test(
        "playback-engine/av1-and-vp9-play-where-the-device-decodes-them without the decoder AV1 in Matroska fails naming the codec",
        .enabled(if: !SampleBuilder.hardwareDecodes("av1")))
    func av1WithoutDecoderFails() async throws {
        let server = try FixtureServer()
        let base = try await server.start()
        let engine = DemuxEngine(sleep: { _ in }, log: { _ in })
        await #expect(throws: PlaybackFailure.cannotDecode(codec: "av1")) { try await engine.load(base.appending(path: "av1.mkv")) }
        await engine.stop()
        await server.stop()
    }

    @Test(
        "playback-engine/av1-and-vp9-play-where-the-device-decodes-them without the decoder AV1 in MP4 goes to Apple's player",
        .enabled(if: !SampleBuilder.hardwareDecodes("av1")))
    func av1InMP4WithoutDecoderHandsOver() async throws {
        let server = try FixtureServer()
        let base = try await server.start()
        let engine = DemuxEngine(sleep: { _ in }, log: { _ in })
        await #expect(throws: EngineHandoff.toSystemPlayer) { try await engine.load(base.appending(path: "av1.mp4")) }
        await engine.stop()
        await server.stop()
    }

    @Test("playback-engine/av1-and-vp9-play-where-the-device-decodes-them the VP9 configuration names profile, depth and colors")
    func vpcCBody() {
        var video = DemuxedStream.VideoParameters()
        video.profile = 2
        video.level = 31
        video.bitDepth = 10
        video.chromaSubsampling = 1
        video.fullRange = true
        video.primaries = 9
        video.transfer = 16
        video.matrix = 9
        #expect(SampleBuilder.vpcC(video) == Data([1, 0, 0, 0, 2, 31, 0xA3, 9, 16, 9, 0, 0]))
    }

    private func plays(_ file: String, codec: String) async throws {
        let outcome = try await PictureCheck.run(FixtureServer.fixtures().appending(path: file))
        #expect(outcome.refused == 0)
        #expect(outcome.pictures.count >= 40, "\(outcome.pictures.count) of \(outcome.queued.count), hidden \(outcome.hidden)")
        #expect(outcome.pictures.allSatisfy { $0.status == noErr })
        let server = try FixtureServer()
        let base = try await server.start()
        let engine = DemuxEngine(sleep: { _ in }, log: { _ in })
        try await engine.load(base.appending(path: file))
        let format = try #require(await current(engine.presentation()).flatMap { $0 })
        #expect(format.video?.codec == codec)
        #expect(format.video?.width == 320)
        await engine.play()
        #expect(await eventually { engine.state == .playing })
        await engine.stop()
        await server.stop()
    }
}
