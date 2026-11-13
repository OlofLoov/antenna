import CoreMedia
import CoreVideo
import FFmpeg
import Foundation

/// FFmpeg's decoder for the two codecs no Apple device decodes in
/// hardware: MPEG-2 video and MP2 sound, from old SD broadcast channels.
/// Pictures come out as NV12 pixel buffers and sound as interleaved 32-bit
/// float PCM, both as `CMSampleBuffer`s the sample-buffer renderers take.
///
/// One thread at a time, like `Demuxer`.
final class SoftwareDecoder: @unchecked Sendable {
    enum DecodeError: Error, Equatable {
        case unavailable(String)
        case failed
    }

    /// The timebase packets are timed in when they reach FFmpeg: 90 kHz,
    /// the MPEG-TS clock.
    private static let timescale: Int32 = 90000

    private var context: UnsafeMutablePointer<AVCodecContext>?
    private var packet: UnsafeMutablePointer<AVPacket>?
    private var frame: UnsafeMutablePointer<AVFrame>?
    private let isVideo: Bool
    private var pixelFormat: CMVideoFormatDescription?
    private var soundFormat: CMAudioFormatDescription?

    /// A decoder for FFmpeg's codec `name`, "mpeg2video" or "mp2".
    init(codec name: String) throws {
        guard let codec = avcodec_find_decoder_by_name(name), let context = avcodec_alloc_context3(codec) else {
            throw DecodeError.unavailable(name)
        }
        context.pointee.pkt_timebase = AVRational(num: 1, den: Self.timescale)
        context.pointee.thread_count = 2
        guard avcodec_open2(context, codec, nil) == 0 else {
            var context: UnsafeMutablePointer<AVCodecContext>? = context
            avcodec_free_context(&context)
            throw DecodeError.unavailable(name)
        }
        self.context = context
        isVideo = codec.pointee.type == AVMEDIA_TYPE_VIDEO
        packet = av_packet_alloc()
        frame = av_frame_alloc()
    }

    deinit {
        av_frame_free(&frame)
        av_packet_free(&packet)
        avcodec_free_context(&context)
    }

    /// The decoded sample buffers for `compressed`: none while the decoder
    /// waits for a reference frame, usually one.
    func decode(_ compressed: DemuxedPacket) throws -> [CMSampleBuffer] {
        guard let context, let packet, let frame else { throw DecodeError.failed }
        guard av_new_packet(packet, Int32(compressed.data.count)) == 0, let target = packet.pointee.data else {
            throw DecodeError.failed
        }
        defer { av_packet_unref(packet) }
        compressed.data.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return }
            target.update(from: base.assumingMemoryBound(to: UInt8.self), count: compressed.data.count)
        }
        packet.pointee.pts = Self.ticks(compressed.presentationTime)
        packet.pointee.dts = Self.ticks(compressed.decodeTime)
        if compressed.isKeyframe { packet.pointee.flags |= AV_PKT_FLAG_KEY }
        guard avcodec_send_packet(context, packet) == 0 else { return [] }
        var buffers: [CMSampleBuffer] = []
        while avcodec_receive_frame(context, frame) == 0 {
            defer { av_frame_unref(frame) }
            let time = CMTime(value: frame.pointee.best_effort_timestamp, timescale: Self.timescale)
            if let buffer = try isVideo ? picture(frame, at: time) : sound(frame, at: time) {
                buffers.append(buffer)
            }
        }
        return buffers
    }

    private static func ticks(_ time: CMTime) -> Int64 {
        guard time.isValid, time.isNumeric else { return Int64.min }
        return CMTimeConvertScale(time, timescale: timescale, method: .roundHalfAwayFromZero).value
    }

    // MARK: Pictures

    /// Copies a planar 4:2:0 frame into an NV12 pixel buffer: the luma rows
    /// as they are, the two chroma planes interleaved.
    private func picture(_ frame: UnsafeMutablePointer<AVFrame>, at time: CMTime) throws -> CMSampleBuffer? {
        let width = Int(frame.pointee.width)
        let height = Int(frame.pointee.height)
        guard frame.pointee.format == AV_PIX_FMT_YUV420P.rawValue, width > 0, height > 0,
            let luma = frame.pointee.data.0, let blue = frame.pointee.data.1, let red = frame.pointee.data.2
        else { return nil }
        let attributes: [CFString: Any] = [kCVPixelBufferIOSurfacePropertiesKey: [String: Any]()]
        var pixels: CVPixelBuffer?
        guard
            CVPixelBufferCreate(
                nil, width, height, kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, attributes as CFDictionary, &pixels)
                == kCVReturnSuccess, let pixels
        else { throw DecodeError.failed }
        CVPixelBufferLockBaseAddress(pixels, [])
        defer { CVPixelBufferUnlockBaseAddress(pixels, []) }
        guard let lumaOut = CVPixelBufferGetBaseAddressOfPlane(pixels, 0)?.assumingMemoryBound(to: UInt8.self),
            let chromaOut = CVPixelBufferGetBaseAddressOfPlane(pixels, 1)?.assumingMemoryBound(to: UInt8.self)
        else { throw DecodeError.failed }
        let lumaStride = CVPixelBufferGetBytesPerRowOfPlane(pixels, 0)
        let chromaStride = CVPixelBufferGetBytesPerRowOfPlane(pixels, 1)
        let lumaIn = Int(frame.pointee.linesize.0)
        let blueIn = Int(frame.pointee.linesize.1)
        let redIn = Int(frame.pointee.linesize.2)
        for row in 0..<height {
            (lumaOut + row * lumaStride).update(from: luma + row * lumaIn, count: width)
        }
        let chromaWidth = (width + 1) / 2
        for row in 0..<((height + 1) / 2) {
            let out = chromaOut + row * chromaStride
            let cb = blue + row * blueIn
            let cr = red + row * redIn
            for column in 0..<chromaWidth {
                out[2 * column] = cb[column]
                out[2 * column + 1] = cr[column]
            }
        }
        // Field order the way VideoToolbox marks it, so interlaced MPEG-2
        // reaches the deinterlacer like interlaced H.264 does.
        let flags = frame.pointee.flags
        if flags & (1 << 3) != 0 {  // AV_FRAME_FLAG_INTERLACED
            let topFirst = flags & (1 << 4) != 0  // AV_FRAME_FLAG_TOP_FIELD_FIRST
            CVBufferSetAttachment(pixels, kCVImageBufferFieldCountKey, 2 as CFNumber, .shouldPropagate)
            CVBufferSetAttachment(
                pixels, kCVImageBufferFieldDetailKey,
                topFirst ? kCVImageBufferFieldDetailTemporalTopFirst : kCVImageBufferFieldDetailTemporalBottomFirst, .shouldPropagate)
        }
        if pixelFormat.map({ !CMVideoFormatDescriptionMatchesImageBuffer($0, imageBuffer: pixels) }) ?? true {
            var format: CMVideoFormatDescription?
            CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil, imageBuffer: pixels, formatDescriptionOut: &format)
            pixelFormat = format
        }
        guard let format = pixelFormat else { throw DecodeError.failed }
        let rate = context?.pointee.framerate ?? AVRational(num: 25, den: 1)
        let duration = rate.num > 0 ? CMTime(value: CMTimeValue(rate.den), timescale: rate.num) : .invalid
        var timing = CMSampleTimingInfo(duration: duration, presentationTimeStamp: time, decodeTimeStamp: .invalid)
        var buffer: CMSampleBuffer?
        guard
            CMSampleBufferCreateReadyWithImageBuffer(
                allocator: nil, imageBuffer: pixels, formatDescription: format, sampleTiming: &timing, sampleBufferOut: &buffer)
                == noErr
        else { throw DecodeError.failed }
        return buffer
    }

    // MARK: Sound

    /// Interleaves a decoded sound frame into 32-bit float PCM.
    private func sound(_ frame: UnsafeMutablePointer<AVFrame>, at time: CMTime) throws -> CMSampleBuffer? {
        let samples = Int(frame.pointee.nb_samples)
        let channels = Int(frame.pointee.ch_layout.nb_channels)
        let rate = Int(frame.pointee.sample_rate)
        guard samples > 0, channels > 0, rate > 0, let planes = frame.pointee.extended_data else { return nil }
        var pcm = [Float](repeating: 0, count: samples * channels)
        switch AVSampleFormat(rawValue: frame.pointee.format) {
        case AV_SAMPLE_FMT_FLTP:
            for channel in 0..<channels {
                guard let plane = planes[channel] else { continue }
                plane.withMemoryRebound(to: Float.self, capacity: samples) { source in
                    for index in 0..<samples { pcm[index * channels + channel] = source[index] }
                }
            }
        case AV_SAMPLE_FMT_S16P:
            for channel in 0..<channels {
                guard let plane = planes[channel] else { continue }
                plane.withMemoryRebound(to: Int16.self, capacity: samples) { source in
                    for index in 0..<samples { pcm[index * channels + channel] = Float(source[index]) / 32768 }
                }
            }
        case AV_SAMPLE_FMT_S16:
            guard let plane = planes[0] else { return nil }
            plane.withMemoryRebound(to: Int16.self, capacity: samples * channels) { source in
                for index in 0..<(samples * channels) { pcm[index] = Float(source[index]) / 32768 }
            }
        default:
            return nil
        }
        // A new format when the rate or the channel count changes, as when a
        // broadcast goes from stereo to mono between programmes.
        let current = soundFormat.flatMap { CMAudioFormatDescriptionGetStreamBasicDescription($0)?.pointee }
        if current?.mSampleRate != Float64(rate) || current?.mChannelsPerFrame != UInt32(channels) {
            soundFormat = try Self.pcmFormat(rate: rate, channels: channels)
        }
        guard let format = soundFormat else { throw DecodeError.failed }
        let data = pcm.withUnsafeBytes { Data($0) }
        let block = try SampleBuilder.blockBuffer(data)
        var buffer: CMSampleBuffer?
        guard
            CMAudioSampleBufferCreateReadyWithPacketDescriptions(
                allocator: nil, dataBuffer: block, formatDescription: format, sampleCount: samples,
                presentationTimeStamp: time, packetDescriptions: nil, sampleBufferOut: &buffer) == noErr
        else { throw DecodeError.failed }
        return buffer
    }

    private static func pcmFormat(rate: Int, channels: Int) throws -> CMAudioFormatDescription {
        var description = AudioStreamBasicDescription(
            mSampleRate: Float64(rate), mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked, mBytesPerPacket: UInt32(4 * channels),
            mFramesPerPacket: 1, mBytesPerFrame: UInt32(4 * channels), mChannelsPerFrame: UInt32(channels),
            mBitsPerChannel: 32, mReserved: 0)
        var format: CMAudioFormatDescription?
        guard
            CMAudioFormatDescriptionCreate(
                allocator: nil, asbd: &description, layoutSize: 0, layout: nil, magicCookieSize: 0, magicCookie: nil,
                extensions: nil, formatDescriptionOut: &format) == noErr, let format
        else { throw DecodeError.failed }
        return format
    }
}
