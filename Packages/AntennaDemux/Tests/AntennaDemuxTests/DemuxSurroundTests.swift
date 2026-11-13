import AntennaCore
import AntennaTestSupport
import AudioToolbox
import Foundation
import Testing

@testable import AntennaDemux

/// Dolby Digital and Dolby Digital Plus on the FFmpeg path, and HEVC HDR
/// in raw broadcast streams.
@MainActor
@Suite(.serialized, .timeLimit(.minutes(1))) struct DemuxSurroundTests {
    @Test(
        "playback-engine/surround-sound-reaches-the-speakers 5.1 Dolby Digital and Dolby Digital Plus are reported as sent",
        arguments: [("surround-ac3.ts", "ac3"), ("surround-eac3.ts", "eac3")])
    func surroundReported(file: String, codec: String) async throws {
        let harness = try await SurroundHarness()
        try await harness.engine.load(harness.url(file))
        let presented = await current(harness.engine.presentation())
        let audio = try #require(presented.flatMap { $0 }?.audio)
        #expect(audio == PresentationInfo.Audio(codec: codec, channels: 6, isDecodable: true))
        await harness.stop()
    }

    @Test(
        "playback-engine/surround-sound-reaches-the-speakers the frame header gives the sound's rate, channels and length",
        arguments: [("surround-ac3.ts", false), ("surround-eac3.ts", true)])
    func headerParses(file: String, enhanced: Bool) throws {
        let data = try Data(contentsOf: FixtureServer.fixtures().appending(path: file))
        final class Reader: @unchecked Sendable {
            let data: Data
            var offset = 0
            init(_ data: Data) { self.data = data }
        }
        let reader = Reader(data)
        let demuxer = try Demuxer(read: { destination, count in
            let taken = min(count, reader.data.count - reader.offset)
            guard taken > 0 else { return 0 }
            reader.data.withUnsafeBytes { raw in
                guard let base = raw.baseAddress else { return }
                destination.update(from: base.advanced(by: reader.offset).assumingMemoryBound(to: UInt8.self), count: taken)
            }
            reader.offset += taken
            return taken
        })
        let audio = try #require(demuxer.streams.first { $0.kind == .audio })
        var header: SampleBuilder.DolbyHeader?
        while header == nil, let packet = demuxer.nextPacket() {
            if packet.streamIndex == audio.index { header = SampleBuilder.dolbyHeader(packet.data) }
        }
        #expect(
            header
                == SampleBuilder.DolbyHeader(
                    isEnhanced: enhanced, sampleRate: 48000, channels: 6, samples: 1536, layoutTag: kAudioChannelLayoutTag_MPEG_5_1_C))
    }

    @Test(
        "playback-engine/the-screen-learns-the-picture-and-sound-format HEVC in a raw broadcast stream reports its dynamic range",
        arguments: [("hdr10.ts", PresentationInfo.DynamicRange.hdr10), ("hlg.ts", .hlg)])
    func hevcBroadcast(file: String, range: PresentationInfo.DynamicRange) async throws {
        let harness = try await SurroundHarness()
        try await harness.engine.load(harness.url(file))
        let presentation = Recorded(await harness.engine.presentation())
        #expect(await eventually { presentation.values.last??.video?.frameRate == 25 })
        let video = try #require(presentation.values.last??.video)
        #expect(video.codec == "hevc" && video.dynamicRange == range)
        presentation.cancel()
        await harness.stop()
    }
}

/// A fixture server and an engine with no retry waits.
@MainActor
private struct SurroundHarness {
    let server: FixtureServer
    let base: URL
    let engine: DemuxEngine

    init() async throws {
        server = try FixtureServer()
        base = try await server.start()
        engine = DemuxEngine(sleep: { _ in }, log: { _ in })
    }

    func url(_ path: String) -> URL {
        base.appending(path: path)
    }

    func stop() async {
        await engine.stop()
        await server.stop()
    }
}
