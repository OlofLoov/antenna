import AntennaCore
import AntennaTestSupport
import CoreMedia
import Foundation
import Testing

@testable import AntennaDemux

/// Interlaced broadcasts: telling them apart from progressive streams.
@Suite struct DemuxInterlaceTests {
    @Test(
        "playback-engine/interlaced-broadcasts-are-deinterlaced an H.264 stream's SPS says whether it is interlaced",
        arguments: [("interlaced-1080i.ts", true), ("channel.ts", false)])
    func spsSaysInterlaced(file: String, interlaced: Bool) throws {
        let units = try firstKeyframeUnits(file)
        let sps = try #require(units.first { SampleBuilder.h264Type($0) == 7 })
        #expect(SampleBuilder.h264IsInterlaced(sps: sps) == interlaced)
    }

    @MainActor
    @Test(
        "playback-engine/interlaced-broadcasts-are-deinterlaced the screen is told a stream is interlaced and the rate it is shown at",
        arguments: [("interlaced-1080i.ts", true, 50.0), ("interlaced-576i.ts", true, 50.0), ("channel.ts", false, 25.0)])
    func reportsInterlacing(file: String, interlaced: Bool, rate: Double) async throws {
        let server = try FixtureServer()
        let base = try await server.start()
        let engine = DemuxEngine(sleep: { _ in }, log: { _ in })
        let presentation = Recorded(await engine.presentation())
        try await engine.load(base.appending(path: file))
        #expect(await eventually { presentation.values.last??.video?.frameRate == rate })
        let video = try #require(presentation.values.last??.video)
        #expect(video.isInterlaced == interlaced)
        presentation.cancel()
        await engine.stop()
        await server.stop()
    }

    @Test func emulationPreventionBytesAreRemoved() {
        #expect(SampleBuilder.withoutEmulationPrevention(Data([0, 0, 3, 1, 0, 0, 3, 0, 5])) == [0, 0, 1, 0, 0, 0, 5])
    }

    @Test func golombCodesRead() {
        // 1 → 0, 010 → 1, 011 → 2, 00100 → 3; as signed, 010 → +1 and 011 → -1.
        var reader = BitReader([0b1010_0110, 0b0100_0000])
        #expect(reader.unsignedGolomb() == 0)
        #expect(reader.unsignedGolomb() == 1)
        #expect(reader.unsignedGolomb() == 2)
        #expect(reader.unsignedGolomb() == 3)
        var signed = BitReader([0b0100_1100])
        #expect(signed.signedGolomb() == 1)
        #expect(signed.signedGolomb() == -1)
    }
}

/// The NAL units of the first video keyframe in a fixture.
func firstKeyframeUnits(_ file: String) throws -> [Data] {
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
    let video = try #require(demuxer.streams.first { $0.kind == .video })
    while let packet = demuxer.nextPacket() {
        if packet.streamIndex == video.index, packet.isKeyframe { return SampleBuilder.nalUnits(annexB: packet.data) }
    }
    return []
}
