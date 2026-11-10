import AntennaCore
import CoreMedia
import Foundation

extension DemuxRun {
    /// The builder's stream under the codec name the stream turned out to carry.
    static func named(_ builder: SampleBuilder) -> DemuxedStream {
        let stream = builder.stream
        return DemuxedStream(
            index: stream.index, kind: stream.kind, codec: builder.codecName, extradata: stream.extradata, width: stream.width,
            height: stream.height, sampleRate: stream.sampleRate, channels: stream.channels, interlaced: stream.interlaced,
            language: stream.language, frameRate: stream.frameRate, isDefault: stream.isDefault, title: stream.title)
    }

    /// Channel count from the sound buffers built so far.
    static func channels(_ builder: SampleBuilder) -> Int? {
        builder.formatDescription.flatMap(CMAudioFormatDescriptionGetStreamBasicDescription).map { Int($0.pointee.mChannelsPerFrame) }
    }

    /// Pictures of MPEG-2 can be interlaced frame by frame; H.264 only when
    /// its SPS allows fields, and then VideoToolbox decodes it first.
    static func fieldPictures(for builder: SampleBuilder, keyframe: DemuxedPacket) -> FieldPictures? {
        if builder.codecName == "mpeg2video" { return FieldPictures(decoder: nil) }
        guard builder.codecName == "h264" else { return nil }
        let sps = SampleBuilder.nalUnits(annexB: keyframe.data).first { SampleBuilder.h264Type($0) == 7 }
        guard let sps, SampleBuilder.h264IsInterlaced(sps: sps) == true else { return nil }
        _ = try? builder.sampleBuffer(for: keyframe)
        guard let format = builder.formatDescription, let decoder = try? VideoDecoder(format: format) else { return nil }
        return FieldPictures(decoder: decoder, isInterlacedBySPS: true)
    }

    /// FFmpeg's seek callback over `bytes`: SEEK_SET, SEEK_CUR and SEEK_END
    /// move, and AVSEEK_SIZE asks for the length.
    static func seeker(_ bytes: SeekableSource) -> Demuxer.Seek {
        { offset, whence in
            if whence & 0x10000 != 0 { return Int64(bytes.length ?? -1) }  // AVSEEK_SIZE
            let base: Int
            switch whence & 0x3 {
            case 0: base = 0
            case 1: base = bytes.position
            case 2: base = bytes.length ?? -1
            default: return -1
            }
            guard base >= 0 else { return -1 }
            let target = base + Int(offset)
            return bytes.seek(to: target) ? Int64(target) : -1
        }
    }
}
