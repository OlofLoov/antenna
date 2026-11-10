import AntennaCore
import AntennaTestSupport
import CoreMedia
import CoreVideo
import Foundation
import Testing

@testable import AntennaDemux

/// Old SD channels: MPEG-2 video and MP2 sound, decoded by FFmpeg in
/// software since no Apple device decodes them in hardware.
@MainActor
@Suite(.serialized, .timeLimit(.minutes(1))) struct DemuxSoftwareDecodeTests {
    @Test("playback-engine/every-common-stream-type-plays an old SD channel in MPEG-2 and MP2 plays with picture and sound")
    func oldSDChannelOpens() async throws {
        let server = try FixtureServer()
        let base = try await server.start()
        let engine = DemuxEngine(sleep: { _ in }, log: { _ in })
        try await engine.load(base.appending(path: "mpeg2.ts"))
        let presented = await current(engine.presentation())
        let format = try #require(presented.flatMap { $0 })
        #expect(format.video?.codec == "mpeg2video")
        #expect(format.video?.width == 320 && format.video?.height == 180)
        #expect(format.audio?.codec == "mp2")
        let tracks = try #require(await current(engine.tracks()))
        #expect(tracks.selectedAudio == "audio-0")
        await engine.stop()
        await server.stop()
    }

    @Test("playback-engine/every-common-stream-type-plays MPEG-2 pictures come out as NV12 and MP2 as float PCM")
    func decodesBoth() throws {
        let data = try Data(contentsOf: FixtureServer.fixtures().appending(path: "mpeg2.ts"))
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
        let audio = try #require(demuxer.streams.first { $0.kind == .audio })
        let pictures = try SampleBuilder(stream: video)
        let sounds = try SampleBuilder(stream: audio)
        var picture: CMSampleBuffer?
        var sound: CMSampleBuffer?
        while picture == nil || sound == nil, let packet = demuxer.nextPacket() {
            if packet.streamIndex == video.index, picture == nil { picture = try pictures.sampleBuffers(for: packet).first }
            if packet.streamIndex == audio.index, sound == nil { sound = try sounds.sampleBuffers(for: packet).first }
        }
        let image = try #require(picture.flatMap(CMSampleBufferGetImageBuffer))
        #expect(CVPixelBufferGetPixelFormatType(image) == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)
        #expect(CVPixelBufferGetWidth(image) == 320 && CVPixelBufferGetHeight(image) == 180)
        let pcm = try #require(sound)
        let description = try #require(CMSampleBufferGetFormatDescription(pcm).flatMap(CMAudioFormatDescriptionGetStreamBasicDescription))
        #expect(description.pointee.mFormatID == kAudioFormatLinearPCM)
        #expect(description.pointee.mFormatFlags & kAudioFormatFlagIsFloat != 0)
        #expect(CMSampleBufferGetNumSamples(pcm) == 1152)
    }
}
