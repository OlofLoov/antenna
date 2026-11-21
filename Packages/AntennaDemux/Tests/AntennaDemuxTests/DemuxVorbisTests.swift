import AntennaCore
import AntennaTestSupport
import Foundation
import Testing

@testable import AntennaDemux

/// Vorbis sound through FFmpeg's decoder, once the FFmpeg build carries it
/// (playback-engine/vorbis-sound-plays).
@MainActor
@Suite(.serialized, .timeLimit(.minutes(1))) struct DemuxVorbisTests {
    nonisolated static var buildDecodesVorbis: Bool { (try? SoftwareDecoder(codec: "vorbis")) != nil }

    @Test("playback-engine/vorbis-sound-plays a film with Vorbis sound plays it", .enabled(if: buildDecodesVorbis))
    func vorbisPlays() async throws {
        let server = try FixtureServer()
        let base = try await server.start()
        let engine = DemuxEngine(sleep: { _ in }, log: { _ in })
        try await engine.load(base.appending(path: "vorbis.mkv"))
        let format = try #require(await current(engine.presentation()).flatMap { $0 })
        #expect(format.audio == PresentationInfo.Audio(codec: "vorbis", channels: 2, isDecodable: true))
        await engine.play()
        #expect(await eventually { engine.state == .playing })
        await engine.stop()
        await server.stop()
    }

    @Test("playback-engine/vorbis-sound-plays Vorbis is sent to FFmpeg's decoder, and is unsupported only while the build lacks it")
    func vorbisGoesToTheSoftwareDecoder() throws {
        let source = try FileDemuxer("vorbis.mkv")
        let sound = try #require(source.demuxer.streams.first { $0.kind == .audio })
        #expect(sound.codec == "vorbis")
        let builder = try? SampleBuilder(stream: sound)
        #expect((builder != nil) == Self.buildDecodesVorbis)
    }
}
