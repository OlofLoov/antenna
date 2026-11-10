import AntennaCore
import AntennaTestSupport
import CoreMedia
import Foundation
import Testing
import VideoToolbox

@testable import AntennaDemux

/// HEVC on the FFmpeg path, with its dynamic range: hvcC from MP4 and
/// Matroska, and Annex B as raw broadcast streams carry it.
@MainActor
@Suite(.serialized, .timeLimit(.minutes(1))) struct DemuxHEVCTests {
    @Test(
        "playback-engine/the-screen-learns-the-picture-and-sound-format HEVC reports its dynamic range on the FFmpeg path",
        arguments: [("hdr10.mp4", PresentationInfo.DynamicRange.hdr10), ("hlg.mp4", .hlg)])
    func reportsDynamicRange(file: String, range: PresentationInfo.DynamicRange) async throws {
        let server = try FixtureServer()
        let base = try await server.start()
        let engine = DemuxEngine(sleep: { _ in }, log: { _ in })
        try await engine.load(base.appending(path: file))
        let presented = await current(engine.presentation())
        let video = try #require(presented.flatMap { $0 }?.video)
        #expect(video.codec == "hevc")
        #expect(video.dynamicRange == range)
        #expect(video.width == 320 && video.height == 180)
        await engine.stop()
        await server.stop()
    }

    @Test(
        "playback-engine/the-screen-learns-the-picture-and-sound-format HEVC in Annex B keeps its dynamic range and decodes",
        arguments: [("hdr10.mp4", PresentationInfo.DynamicRange.hdr10), ("hlg.mp4", .hlg)])
    func annexB(file: String, range: PresentationInfo.DynamicRange) throws {
        let source = try FileDemuxer(file)
        let stream = try #require(source.demuxer.streams.first { $0.kind == .video })
        let sets = try SampleBuilder.hevcParameterSets(hvcC: stream.extradata)
        let keyframe = try #require(source.firstKeyframe(of: stream.index))
        let startCode = Data([0, 0, 0, 1])
        let annexB = sets.reduce(Data()) { $0 + startCode + $1 } + Self.annexB(lengthPrefixed: keyframe.data)
        let raw = DemuxedStream(
            index: stream.index, kind: .video, codec: "hevc", extradata: Data(), width: 0, height: 0, sampleRate: 0,
            channels: 0, interlaced: false, language: nil, frameRate: nil, isDefault: true)
        let builder = try SampleBuilder(stream: raw)
        let packet = DemuxedPacket(
            streamIndex: stream.index, data: annexB, presentationTime: keyframe.presentationTime,
            decodeTime: keyframe.decodeTime, duration: keyframe.duration, isKeyframe: true)
        let sample = try #require(try builder.sampleBuffer(for: packet))
        let format = try #require(builder.formatDescription)
        #expect(SampleBuilder.dynamicRange(of: format) == range)
        #expect(try decodedSize(sample, format: format) == CGSize(width: 320, height: 180))
    }

    @Test("playback-engine/the-screen-learns-the-picture-and-sound-format VideoToolbox decodes HEVC from hvcC")
    func decodesHVCC() throws {
        let source = try FileDemuxer("hdr10.mp4")
        let stream = try #require(source.demuxer.streams.first { $0.kind == .video })
        let builder = try SampleBuilder(stream: stream)
        let keyframe = try #require(source.firstKeyframe(of: stream.index))
        let sample = try #require(try builder.sampleBuffer(for: keyframe))
        let format = try #require(builder.formatDescription)
        #expect(try decodedSize(sample, format: format) == CGSize(width: 320, height: 180))
    }

    /// Start codes in place of the 4-byte lengths of an hvcC packet.
    static func annexB(lengthPrefixed data: Data) -> Data {
        let bytes = [UInt8](data)
        var out = Data()
        var index = 0
        while index + 4 <= bytes.count {
            let length = bytes[index..<(index + 4)].reduce(0) { $0 << 8 | Int($1) }
            index += 4
            guard index + length <= bytes.count else { break }
            out += Data([0, 0, 0, 1]) + Data(bytes[index..<(index + length)])
            index += length
        }
        return out
    }
}

/// A fixture file opened with `Demuxer` from memory.
private struct FileDemuxer {
    let demuxer: Demuxer

    init(_ file: String) throws {
        let reader = MemoryReader(try Data(contentsOf: FixtureServer.fixtures().appending(path: file)))
        demuxer = try Demuxer(read: { reader.read(into: $0, count: $1) })
    }

    func firstKeyframe(of index: Int) -> DemuxedPacket? {
        while let packet = demuxer.nextPacket() {
            if packet.streamIndex == index, packet.isKeyframe { return packet }
        }
        return nil
    }
}

private final class MemoryReader: @unchecked Sendable {
    let data: Data
    var offset = 0

    init(_ data: Data) {
        self.data = data
    }

    func read(into destination: UnsafeMutablePointer<UInt8>, count: Int) -> Int {
        let taken = min(count, data.count - offset)
        guard taken > 0 else { return 0 }
        data.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return }
            destination.update(from: base.advanced(by: offset).assumingMemoryBound(to: UInt8.self), count: taken)
        }
        offset += taken
        return taken
    }
}

private struct DecodeError: Error {
    let status: OSStatus
}

private func decodedSize(_ sample: CMSampleBuffer, format: CMFormatDescription) throws -> CGSize {
    var session: VTDecompressionSession?
    var status = VTDecompressionSessionCreate(
        allocator: nil, formatDescription: format, decoderSpecification: nil, imageBufferAttributes: nil,
        outputCallback: nil, decompressionSessionOut: &session)
    guard status == noErr, let session else { throw DecodeError(status: status) }
    defer { VTDecompressionSessionInvalidate(session) }
    nonisolated(unsafe) var size = CGSize.zero
    nonisolated(unsafe) var frameStatus = noErr
    let handler: VTDecompressionOutputHandler = { decoded, _, image, _, _ in
        frameStatus = decoded
        if let image { size = CGSize(width: CVPixelBufferGetWidth(image), height: CVPixelBufferGetHeight(image)) }
    }
    status = VTDecompressionSessionDecodeFrame(session, sampleBuffer: sample, flags: [], infoFlagsOut: nil, outputHandler: handler)
    VTDecompressionSessionWaitForAsynchronousFrames(session)
    guard status == noErr, frameStatus == noErr else { throw DecodeError(status: status == noErr ? frameStatus : status) }
    return size
}
