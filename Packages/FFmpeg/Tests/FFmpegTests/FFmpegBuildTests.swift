import AntennaTestSupport
import FFmpeg
import Foundation
import Testing

/// The FFmpeg build the app links: LGPL, demuxers plus the MPEG-2 and MP2
/// decoders only, and every fixture container opening through a custom read
/// callback, the way the demuxing engine feeds it. Tooling for the
/// playback-engine change, so these tests cite no requirement.
@Suite struct FFmpegBuildTests {
    @Test func everyLibraryIsLGPL() {
        let licences = [avformat_license(), avcodec_license(), avutil_license(), swresample_license()]
        #expect(licences.allSatisfy { $0.map { String(cString: $0) } == "LGPL version 2.1 or later" })
    }

    @Test func decodesOnlyWhatAppleCannot() {
        #expect(avcodec_find_decoder(AV_CODEC_ID_MPEG2VIDEO) != nil)
        #expect(avcodec_find_decoder(AV_CODEC_ID_MP2) != nil)
        #expect(avcodec_find_decoder(AV_CODEC_ID_H264) == nil)
        #expect(avcodec_find_decoder(AV_CODEC_ID_AAC) == nil)
    }

    @Test(
        "fixture containers open through a read callback",
        arguments: [
            ("channel.ts", "mpegts", ["h264", "aac"]),
            ("mpeg2.ts", "mpegts", ["mpeg2video", "mp2"]),
            ("channel.mkv", "matroska,webm", ["h264", "aac"]),
            ("channel.avi", "avi", ["mpeg4", "mp3"]),
        ])
    func opens(file: String, format: String, codecs: [String]) throws {
        let data = try Data(contentsOf: FixtureServer.fixtures().appending(path: file))
        let found = try Demuxed(data)
        #expect(found.format == format)
        #expect(found.codecs == codecs)
        #expect(found.packets > 0)
    }
}

/// Opens bytes in memory with FFmpeg and reads every packet.
private struct Demuxed {
    let format: String
    let codecs: [String]
    let packets: Int

    struct OpenFailed: Error {}

    init(_ data: Data) throws {
        av_log_set_level(AV_LOG_QUIET)
        let source = Unmanaged.passRetained(Reader(data)).toOpaque()
        defer { Unmanaged<Reader>.fromOpaque(source).release() }
        let size: Int32 = 32 * 1024
        guard let buffer = av_malloc(Int(size)) else { throw OpenFailed() }
        var io = avio_alloc_context(buffer.assumingMemoryBound(to: UInt8.self), size, 0, source, Reader.read, nil, nil)
        defer { avio_context_free(&io) }
        var context = avformat_alloc_context()
        context?.pointee.pb = io
        guard avformat_open_input(&context, nil, nil, nil) == 0, let opened = context else { throw OpenFailed() }
        defer { avformat_close_input(&context) }
        guard avformat_find_stream_info(opened, nil) >= 0 else { throw OpenFailed() }
        format = String(cString: opened.pointee.iformat.pointee.name)
        codecs = (0..<Int(opened.pointee.nb_streams)).compactMap { index in
            opened.pointee.streams[index]?.pointee.codecpar.map { String(cString: avcodec_get_name($0.pointee.codec_id)) }
        }
        var packet = av_packet_alloc()
        defer { av_packet_free(&packet) }
        var count = 0
        while av_read_frame(opened, packet) >= 0 {
            count += 1
            av_packet_unref(packet)
        }
        packets = count
    }
}

private final class Reader {
    let data: Data
    var offset = 0

    init(_ data: Data) {
        self.data = data
    }

    static let read: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutablePointer<UInt8>?, Int32) -> Int32 = { opaque, out, want in
        guard let opaque, let out else { return -1 }
        let reader = Unmanaged<Reader>.fromOpaque(opaque).takeUnretainedValue()
        let count = min(Int(want), reader.data.count - reader.offset)
        guard count > 0 else { return -541_478_725 }  // AVERROR_EOF
        reader.data.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return }
            out.update(from: base.advanced(by: reader.offset).assumingMemoryBound(to: UInt8.self), count: count)
        }
        reader.offset += count
        return Int32(count)
    }
}
