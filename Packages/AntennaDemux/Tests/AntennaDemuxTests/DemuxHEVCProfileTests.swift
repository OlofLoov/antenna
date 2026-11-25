import AntennaCore
import AntennaTestSupport
import CoreMedia
import Foundation
import Testing

@testable import AntennaDemux

/// HEVC films that reached "this device cannot play" on devices that decode
/// HEVC: parameter sets only in the samples, and profiles beyond 4:2:0.
@MainActor
@Suite(.serialized, .timeLimit(.minutes(1))) struct DemuxHEVCProfileTests {
    @Test(
        "playback-engine/hevc-plays-wherever-the-device-decodes-it an hev1 film with its parameter sets only in the samples plays"
    )
    func inBandParameterSets() async throws {
        let server = try FixtureServer()
        let base = try await server.start()
        let engine = DemuxEngine(sleep: { _ in }, log: { _ in })
        try await engine.load(base.appending(path: "hev1-in-band.mp4"))
        let presented = await current(engine.presentation())
        let video = try #require(presented.flatMap { $0 }?.video)
        #expect(video.codec == "hevc")
        #expect(video.width == 320 && video.height == 180)
        await engine.play()
        #expect(await eventually { engine.state == .playing })
        await engine.stop()
        await server.stop()
    }

    @Test("playback-engine/hevc-plays-wherever-the-device-decodes-it the in-band pictures decode")
    func inBandPicturesDecode() async throws {
        let outcome = try await PictureCheck.run(FixtureServer.fixtures().appending(path: "hev1-in-band.mp4"))
        #expect(outcome.pictures.count >= 40)
        #expect(outcome.pictures.allSatisfy { $0.status == noErr })
        #expect(outcome.refused == 0)
    }

    @Test(
        "playback-engine/hevc-plays-wherever-the-device-decodes-it HEVC 4:2:2 plays, or fails naming the profile"
    )
    func fourTwoTwo() async throws {
        let source = try FileDemuxer("hevc-422.mp4")
        let stream = try #require(source.demuxer.streams.first { $0.kind == .video })
        let format = try #require(try SampleBuilder(stream: stream).formatDescription)
        #expect(SampleBuilder.codecName(of: format) == "hevc 4:2:2 10-bit")
        let missing = SampleBuilder.decoderMissing(for: format)

        let server = try FixtureServer()
        let base = try await server.start()
        let engine = DemuxEngine(sleep: { _ in }, log: { _ in })
        if let missing {
            #expect(missing == "hevc 4:2:2 10-bit")
            await #expect(throws: PlaybackFailure.cannotDecode(codec: missing)) {
                try await engine.load(base.appending(path: "hevc-422.mp4"))
            }
        } else {
            try await engine.load(base.appending(path: "hevc-422.mp4"))
            await engine.play()
            #expect(await eventually { engine.state == .playing })
        }
        await engine.stop()
        await server.stop()
    }

    @Test(
        "player-controls-and-playback-errors/format-not-supported-names-the-profile a format with no decoder is named"
    )
    func missingDecoderIsNamed() throws {
        // A 4:2:2 10-bit record with no parameter sets: no decoder can
        // be made for it.
        var record = [UInt8](repeating: 0, count: 23)
        record[0] = 1
        record[1] = 4
        record[16] = 0xFC | 2
        record[17] = 0xF8 | 2
        record[18] = 0xF8 | 2
        let extensions: [CFString: Any] = [kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms: ["hvcC": Data(record)]]
        var format: CMFormatDescription?
        let status = CMVideoFormatDescriptionCreate(
            allocator: nil, codecType: kCMVideoCodecType_HEVC, width: 320, height: 180, extensions: extensions as CFDictionary,
            formatDescriptionOut: &format)
        #expect(status == noErr)
        #expect(SampleBuilder.decoderMissing(for: try #require(format)) == "hevc 4:2:2 10-bit")
    }

    @Test("playback-engine/hevc-plays-wherever-the-device-decodes-it a broken configuration fails as unreadable, not can't decode")
    func brokenConfiguration() {
        let broken = DemuxRun.undecodable(video: "hevc", format: "mov,mp4,m4a,3gp,3g2,mj2", error: SampleBuilder.BuildError.malformed)
        #expect(broken as? PlaybackFailure == .unreadable)
        let unknown = DemuxRun.undecodable(video: "vc1", format: "matroska,webm", error: SampleBuilder.BuildError.unsupportedCodec("vc1"))
        #expect(unknown as? PlaybackFailure == .cannotDecode(codec: "vc1"))
    }
}
