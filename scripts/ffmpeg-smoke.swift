// Checks a built FFmpeg.framework: the licence is LGPL 2.1, the only decoders
// are MPEG-2 video and MP2, and each fixture container opens through a custom
// AVIO read callback (the way the app feeds FFmpeg) with the expected streams.
// Run by .github/workflows/ffmpeg.yml against the macOS slice:
//   swiftc -F <frameworks/macos> -framework FFmpeg scripts/ffmpeg-smoke.swift -o smoke
//   ./smoke Packages/AntennaCore/Sources/AntennaTestSupport/Fixtures
import FFmpeg
import Foundation

final class Source {
    let data: Data
    var offset = 0

    init(_ data: Data) {
        self.data = data
    }
}

let readPacket: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutablePointer<UInt8>?, Int32) -> Int32 = { opaque, out, want in
    guard let opaque, let out else { return -1 }
    let source = Unmanaged<Source>.fromOpaque(opaque).takeUnretainedValue()
    let count = min(Int(want), source.data.count - source.offset)
    guard count > 0 else { return -541_478_725 }  // AVERROR_EOF
    source.data.withUnsafeBytes { raw in
        guard let base = raw.baseAddress else { return }
        out.update(from: base.advanced(by: source.offset).assumingMemoryBound(to: UInt8.self), count: count)
    }
    source.offset += count
    return Int32(count)
}

/// The container name and the codec of each stream, in order.
func probe(_ url: URL) throws -> (format: String, codecs: [String]) {
    let source = Source(try Data(contentsOf: url))
    let opaque = Unmanaged.passRetained(source).toOpaque()
    defer { Unmanaged<Source>.fromOpaque(opaque).release() }
    let size: Int32 = 32 * 1024
    guard let buffer = av_malloc(Int(size)) else { throw SmokeError("out of memory") }
    var io = avio_alloc_context(buffer.assumingMemoryBound(to: UInt8.self), size, 0, opaque, readPacket, nil, nil)
    defer { avio_context_free(&io) }
    var context = avformat_alloc_context()
    context?.pointee.pb = io
    guard avformat_open_input(&context, nil, nil, nil) == 0, let opened = context else {
        throw SmokeError("\(url.lastPathComponent) did not open")
    }
    defer { avformat_close_input(&context) }
    guard avformat_find_stream_info(opened, nil) >= 0 else { throw SmokeError("\(url.lastPathComponent) has no stream info") }
    let codecs = (0..<Int(opened.pointee.nb_streams)).compactMap { index in
        opened.pointee.streams[index]?.pointee.codecpar.map { String(cString: avcodec_get_name($0.pointee.codec_id)) }
    }
    return (String(cString: opened.pointee.iformat.pointee.name), codecs)
}

struct SmokeError: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}

let fixtures = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? ".")
var failures: [String] = []

func check(_ condition: Bool, _ message: String) {
    print(condition ? "ok  " : "FAIL", message)
    if !condition { failures.append(message) }
}

av_log_set_level(AV_LOG_QUIET)
for library in [avformat_license(), avcodec_license(), avutil_license(), swresample_license()] {
    check(library.map { String(cString: $0) } == "LGPL version 2.1 or later", "licence is LGPL 2.1")
}
check(avcodec_find_decoder(AV_CODEC_ID_MPEG2VIDEO) != nil, "MPEG-2 video decoder present")
check(avcodec_find_decoder(AV_CODEC_ID_MP2) != nil, "MP2 decoder present")
check(avcodec_find_decoder(AV_CODEC_ID_H264) == nil, "no H.264 decoder, Apple's hardware decodes it")

struct Expected {
    let file: String
    let format: String
    let codecs: [String]
}

let expected = [
    Expected(file: "channel.ts", format: "mpegts", codecs: ["h264", "aac"]),
    Expected(file: "mpeg2.ts", format: "mpegts", codecs: ["mpeg2video", "mp2"]),
    Expected(file: "channel.mkv", format: "matroska,webm", codecs: ["h264", "aac"]),
    Expected(file: "channel.avi", format: "avi", codecs: ["mpeg4", "mp3"]),
]
for fixture in expected {
    do {
        let found = try probe(fixtures.appending(path: fixture.file))
        check(
            found.format == fixture.format && found.codecs == fixture.codecs,
            "\(fixture.file): \(found.format) \(found.codecs.joined(separator: "+"))")
    } catch {
        check(false, "\(fixture.file): \(error)")
    }
}
exit(failures.isEmpty ? 0 : 1)
