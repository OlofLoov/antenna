@preconcurrency import AVFoundation
import AntennaCore
import AntennaTestSupport
import CoreMedia
import Foundation
import Testing
import VideoToolbox

@testable import AntennaDemux

/// The FFmpeg path up to the renderers: bytes over HTTP from the fixture
/// server, FFmpeg's demuxer, and sample buffers that Apple's own decoders
/// accept. Building blocks for playback-engine/every-common-stream-type-plays;
/// the engine's tests cite it once streams play.
@Suite(.serialized) struct DemuxPipelineTests {
    @Test func aRefusedStreamFailsWithItsReason() async throws {
        let server = try FixtureServer()
        let base = try await server.start()
        await server.always("/channel.ts", .status(404))
        let stream = HTTPByteStream(url: base.appending(path: "channel.ts"))
        await #expect(throws: PlaybackFailure.notFound) { try await stream.open() }
        await server.stop()
    }

    @Test(arguments: [("channel.ts", "mpegts"), ("channel.mkv", "matroska,webm")])
    func demuxesOverHTTP(file: String, format: String) async throws {
        let opened = try await Opened(file)
        #expect(opened.demuxer.format == format)
        #expect(opened.demuxer.streams.map(\.codec) == ["h264", "aac"])
        #expect(opened.demuxer.streams.first { $0.kind == .video }?.interlaced == false)
        await opened.close()
    }

    @Test(arguments: ["channel.ts", "channel.mkv", "channel.avi"])
    func videoToolboxDecodesTheFirstKeyframe(file: String) async throws {
        let opened = try await Opened(file)
        let video = try #require(opened.demuxer.streams.first { $0.kind == .video })
        let builder = try SampleBuilder(stream: video)
        var keyframe: CMSampleBuffer?
        while keyframe == nil, let packet = opened.demuxer.nextPacket() {
            guard packet.streamIndex == video.index, packet.isKeyframe else { continue }
            keyframe = try builder.sampleBuffer(for: packet)
        }
        let sample = try #require(keyframe)
        let format = try #require(builder.formatDescription)
        let size = try decodeVideo(sample, format: format)
        #expect(size == CGSize(width: 320, height: 180))
        await opened.close()
    }

    @Test(arguments: ["channel.ts", "channel.mkv", "channel.avi"])
    func audioConverterDecodesAAC(file: String) async throws {
        let opened = try await Opened(file)
        let audio = try #require(opened.demuxer.streams.first { $0.kind == .audio })
        let builder = try SampleBuilder(stream: audio)
        var built: CMSampleBuffer?
        while built == nil, let packet = opened.demuxer.nextPacket() {
            guard packet.streamIndex == audio.index else { continue }
            built = try builder.sampleBuffer(for: packet)
        }
        let sample = try #require(built)
        let frames = try decodeAudio(sample)
        #expect(frames >= 1024 || (audio.codec == "mp3" && frames >= 1152))
        await opened.close()
    }

    @Test func everySoundBufferIsTimedInOrder() async throws {
        let opened = try await Opened("channel.ts")
        let audio = try #require(opened.demuxer.streams.first { $0.kind == .audio })
        let builder = try SampleBuilder(stream: audio)
        var times: [Double] = []
        while let packet = opened.demuxer.nextPacket() {
            guard packet.streamIndex == audio.index, let buffer = try builder.sampleBuffer(for: packet) else { continue }
            times.append(CMSampleBufferGetPresentationTimeStamp(buffer).seconds)
        }
        #expect(times.count > 100)
        #expect(times.allSatisfy { $0.isFinite })
        let rising = zip(times, times.dropFirst()).allSatisfy { earlier, later in earlier < later }
        #expect(rising)
        await opened.close()
    }

    @Test func adtsHeadersBecomeAnAudioSpecificConfig() throws {
        // AAC LC, 48 kHz, stereo, a 9-byte frame (7 header + 2 payload).
        let frame = Data([0xFF, 0xF1, 0x4C, 0x80, 0x01, 0x3F, 0xFC, 0xAA, 0xBB])
        let frames = try SampleBuilder.adtsFrames(frame + frame)
        #expect(frames.count == 2)
        #expect(frames[0].config == Data([0x11, 0x90]))
        #expect(frames[0].payload == Data([0xAA, 0xBB]))
    }

    @Test func annexBSplitsOnThreeAndFourByteStartCodes() {
        let data = Data([0, 0, 0, 1, 0x67, 1, 2, 0, 0, 1, 0x68, 3, 0, 0, 0, 1, 0x65, 4, 5])
        let units = SampleBuilder.nalUnits(annexB: data)
        #expect(units == [Data([0x67, 1, 2]), Data([0x68, 3]), Data([0x65, 4, 5])])
    }
}

/// A fixture opened through `HTTPByteStream` and `Demuxer`, as the engine will.
private struct Opened {
    let server: FixtureServer
    let stream: HTTPByteStream
    let demuxer: Demuxer

    init(_ file: String) async throws {
        server = try FixtureServer()
        let base = try await server.start()
        let stream = HTTPByteStream(url: base.appending(path: file))
        try await stream.open()
        self.stream = stream
        demuxer = try await Task.detached { try Demuxer(read: { stream.read(into: $0, count: $1) }) }.value
    }

    func close() async {
        demuxer.close()
        stream.cancel()
        await server.stop()
    }
}

private struct DecodeFailed: Error {
    let status: OSStatus
}

/// Decodes one video sample with VideoToolbox and returns the picture size.
private func decodeVideo(_ sample: CMSampleBuffer, format: CMFormatDescription) throws -> CGSize {
    var session: VTDecompressionSession?
    var status = VTDecompressionSessionCreate(
        allocator: nil, formatDescription: format, decoderSpecification: nil, imageBufferAttributes: nil,
        outputCallback: nil, decompressionSessionOut: &session)
    guard status == noErr, let session else { throw DecodeFailed(status: status) }
    defer { VTDecompressionSessionInvalidate(session) }
    nonisolated(unsafe) var size = CGSize.zero
    nonisolated(unsafe) var frameStatus = noErr
    let handler: VTDecompressionOutputHandler = { decoded, _, image, _, _ in
        frameStatus = decoded
        if let image { size = CGSize(width: CVPixelBufferGetWidth(image), height: CVPixelBufferGetHeight(image)) }
    }
    status = VTDecompressionSessionDecodeFrame(
        session, sampleBuffer: sample, flags: [], infoFlagsOut: nil, outputHandler: handler)
    VTDecompressionSessionWaitForAsynchronousFrames(session)
    guard status == noErr, frameStatus == noErr else { throw DecodeFailed(status: status == noErr ? frameStatus : status) }
    return size
}

/// Decodes one compressed audio sample to PCM and returns the frame count.
private func decodeAudio(_ sample: CMSampleBuffer) throws -> Int {
    guard let description = CMSampleBufferGetFormatDescription(sample) else { throw DecodeFailed(status: -1) }
    let input = AVAudioFormat(cmAudioFormatDescription: description)
    guard let output = AVAudioFormat(standardFormatWithSampleRate: input.sampleRate, channels: input.channelCount),
        let converter = AVAudioConverter(from: input, to: output),
        let pcm = AVAudioPCMBuffer(pcmFormat: output, frameCapacity: 4096)
    else { throw DecodeFailed(status: -2) }
    var packetCount = 0
    var dataSize = 0
    CMSampleBufferCallBlockForEachSample(sample) { _, _ in
        packetCount += 1
        return noErr
    }
    guard let block = CMSampleBufferGetDataBuffer(sample) else { throw DecodeFailed(status: -3) }
    dataSize = CMBlockBufferGetDataLength(block)
    let compressed = AVAudioCompressedBuffer(format: input, packetCapacity: AVAudioPacketCount(packetCount), maximumPacketSize: dataSize)
    var descriptionsPointer: UnsafePointer<AudioStreamPacketDescription>?
    var descriptionsSize = 0
    CMSampleBufferGetAudioStreamPacketDescriptionsPtr(
        sample, packetDescriptionsPointerOut: &descriptionsPointer, sizeOut: &descriptionsSize)
    guard let descriptionsPointer else { throw DecodeFailed(status: -4) }
    CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: dataSize, destination: compressed.data)
    compressed.packetDescriptions?.update(from: descriptionsPointer, count: packetCount)
    compressed.packetCount = AVAudioPacketCount(packetCount)
    compressed.byteLength = UInt32(dataSize)
    nonisolated(unsafe) var supplied = false
    var error: NSError?
    let result = converter.convert(to: pcm, error: &error) { _, outStatus in
        if supplied {
            outStatus.pointee = .endOfStream
            return nil
        }
        supplied = true
        outStatus.pointee = .haveData
        return compressed
    }
    guard result != .error, error == nil else { throw DecodeFailed(status: Int32((error?.code) ?? -5)) }
    return Int(pcm.frameLength)
}
