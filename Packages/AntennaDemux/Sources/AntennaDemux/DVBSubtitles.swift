import AntennaCore
import CoreMedia
import FFmpeg
import Foundation

/// Decodes the picture subtitles of one DVB subtitle stream into images
/// placed on the picture (playback-engine/picture-subtitles-in-broadcast-streams).
/// One thread at a time, like the demuxer it reads beside.
final class DVBSubtitleDecoder {
    /// FFmpeg's name for DVB picture subtitles. Teletext is `dvb_teletext`
    /// and is not decoded.
    static let codec = "dvb_subtitle"

    /// True when this FFmpeg build has the DVB subtitle decoder.
    static var isAvailable: Bool { avcodec_find_decoder(AV_CODEC_ID_DVB_SUBTITLE) != nil }

    /// One decoded page: its pictures, empty when the page clears the
    /// screen, and when it shows on the stream's clock.
    struct Page: Equatable {
        let start: CMTime
        /// Nil when the page stays until the next one.
        let end: CMTime?
        let images: [SubtitleImage]
    }

    private var context: UnsafeMutablePointer<AVCodecContext>?
    private var packet: UnsafeMutablePointer<AVPacket>?

    /// Nil when the build has no DVB subtitle decoder or it does not open.
    init?(stream: DemuxedStream) {
        guard let decoder = avcodec_find_decoder(AV_CODEC_ID_DVB_SUBTITLE), var context = avcodec_alloc_context3(decoder) else {
            return nil
        }
        // The composition and ancillary page ids from the PMT.
        if !stream.extradata.isEmpty, let buffer = av_mallocz(stream.extradata.count + Int(AV_INPUT_BUFFER_PADDING_SIZE)) {
            let bytes = buffer.assumingMemoryBound(to: UInt8.self)
            stream.extradata.copyBytes(to: bytes, count: stream.extradata.count)
            context.pointee.extradata = bytes
            context.pointee.extradata_size = Int32(stream.extradata.count)
        }
        guard avcodec_open2(context, decoder, nil) == 0 else {
            var opened: UnsafeMutablePointer<AVCodecContext>? = context
            avcodec_free_context(&opened)
            return nil
        }
        self.context = context
        packet = av_packet_alloc()
    }

    deinit {
        if packet != nil { av_packet_free(&packet) }
        if context != nil { avcodec_free_context(&context) }
    }

    /// The page completed by `data`, the payload of a packet due at `time`,
    /// or nil when the packet completes none.
    func decode(_ payload: Data, at time: CMTime) -> Page? {
        // MPEG-TS hands over the whole PES payload. Its data identifier
        // (0x20) and stream id (0x00) come before the segments; FFmpeg's
        // dvbsub parser strips them, and this build has no parser.
        let data = payload.starts(with: [0x20, 0x00]) ? payload.dropFirst(2) : payload[...]
        guard let context, let packet, !data.isEmpty, av_new_packet(packet, Int32(data.count)) == 0 else { return nil }
        defer { av_packet_unref(packet) }
        data.copyBytes(to: packet.pointee.data, count: data.count)
        var subtitle = AVSubtitle()
        var got: Int32 = 0
        guard avcodec_decode_subtitle2(context, &subtitle, &got, packet) >= 0, got != 0 else { return nil }
        defer { avsubtitle_free(&subtitle) }
        // The display definition segment sets the page size; without one
        // DVB subtitles are drawn on a 720x576 page.
        let width = context.pointee.width > 0 ? Int(context.pointee.width) : 720
        let height = context.pointee.height > 0 ? Int(context.pointee.height) : 576
        var images: [SubtitleImage] = []
        for index in 0..<Int(subtitle.num_rects) {
            guard let rect = subtitle.rects?[index]?.pointee, rect.type == SUBTITLE_BITMAP,
                let image = Self.image(rect, pageWidth: width, pageHeight: height)
            else { continue }
            images.append(image)
        }
        let start = CMTimeAdd(time, CMTime(value: Int64(subtitle.start_display_time), timescale: 1000))
        let lasts = subtitle.end_display_time > subtitle.start_display_time && subtitle.end_display_time != UInt32.max
        let end = lasts ? CMTimeAdd(time, CMTime(value: Int64(subtitle.end_display_time), timescale: 1000)) : nil
        return Page(start: start, end: end, images: images)
    }

    /// The region's 8-bit color indices through its palette, as RGBA,
    /// placed as a fraction of the page.
    static func image(_ rect: AVSubtitleRect, pageWidth: Int, pageHeight: Int) -> SubtitleImage? {
        let width = Int(rect.w)
        let height = Int(rect.h)
        let stride = Int(rect.linesize.0)
        guard width > 0, height > 0, stride >= width, let indices = rect.data.0, let paletteBytes = rect.data.1 else { return nil }
        let colorCount = Int(max(rect.nb_colors, 0))
        // FFmpeg's palette is one native-endian 0xAARRGGBB word per color.
        let palette = UnsafeRawPointer(paletteBytes).bindMemory(to: UInt32.self, capacity: max(colorCount, 1))
        var rgba = Data(count: width * height * 4)
        rgba.withUnsafeMutableBytes { raw in
            guard let out = raw.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            for row in 0..<height {
                for column in 0..<width {
                    let index = Int(indices[row * stride + column])
                    let color = index < colorCount ? palette[index] : 0
                    let offset = (row * width + column) * 4
                    out[offset] = UInt8(truncatingIfNeeded: color >> 16)
                    out[offset + 1] = UInt8(truncatingIfNeeded: color >> 8)
                    out[offset + 2] = UInt8(truncatingIfNeeded: color)
                    out[offset + 3] = UInt8(truncatingIfNeeded: color >> 24)
                }
            }
        }
        return SubtitleImage(
            width: width, height: height, rgba: rgba,
            frame: SubtitleImage.Frame(
                x: Double(rect.x) / Double(pageWidth), y: Double(rect.y) / Double(pageHeight),
                width: Double(width) / Double(pageWidth), height: Double(height) / Double(pageHeight)))
    }

    /// A decoder for each DVB subtitle track, by container stream index.
    static func decoders(for tracks: [TrackStream]) -> [Int: DVBSubtitleDecoder] {
        var decoders: [Int: DVBSubtitleDecoder] = [:]
        for track in tracks where track.stream.codec == codec {
            decoders[track.stream.index] = DVBSubtitleDecoder(stream: track.stream)
        }
        return decoders
    }
}

extension DemuxRun {
    /// How long a DVB page stays when the stream gives no time-out, unless
    /// the next page replaces it first.
    static let pageTimeout = CMTime(value: 30, timescale: 1)

    /// Sends each picture of the DVB page `packet` completes, or an empty
    /// page that clears the stream's pictures.
    func pictureCues(from packet: DemuxedPacket, decoder: DVBSubtitleDecoder) {
        guard packet.presentationTime.isNumeric, let page = decoder.decode(packet.data, at: packet.presentationTime) else { return }
        let end = page.end ?? CMTimeAdd(page.start, Self.pageTimeout)
        guard !page.images.isEmpty else {
            cueFound?(TimedCue(streamIndex: packet.streamIndex, start: page.start, end: end, text: "", image: nil, isPage: true))
            return
        }
        for image in page.images {
            cueFound?(TimedCue(streamIndex: packet.streamIndex, start: page.start, end: end, text: "", image: image, isPage: true))
        }
    }
}
