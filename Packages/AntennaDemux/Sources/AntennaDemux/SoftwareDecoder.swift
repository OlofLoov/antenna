import CoreMedia
import CoreVideo
import FFmpeg
import Foundation

/// FFmpeg's decoder for the codecs no Apple device decodes: MPEG-2 video
/// and MP2 sound from old SD broadcast channels, DTS, Dolby TrueHD and MLP
/// from films, AAC in LATM framing, multichannel Opus and SMPTE 302M PCM.
/// Pictures come out as NV12 pixel buffers and sound as interleaved 32-bit
/// float PCM on the speakers the decoder names, both as `CMSampleBuffer`s
/// the sample-buffer renderers take.
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
    private var soundShape: SoundShape?
    /// Where the next sound frame starts, for frames that arrive untimed.
    private var nextSoundTime: CMTime = .invalid
    private var heldSound: HeldSound?

    /// A decoder for the stream FFmpeg names `name`, such as "mpeg2video",
    /// "mp2" or "dts", set up with the container's `extradata`.
    init(codec name: String, extradata: Data = Data()) throws {
        guard let descriptor = avcodec_descriptor_get_by_name(name), let codec = avcodec_find_decoder(descriptor.pointee.id),
            let context = avcodec_alloc_context3(codec)
        else { throw DecodeError.unavailable(name) }
        context.pointee.pkt_timebase = AVRational(num: 1, den: Self.timescale)
        context.pointee.thread_count = 2
        if !extradata.isEmpty, let copy = av_mallocz(extradata.count + Int(AV_INPUT_BUFFER_PADDING_SIZE)) {
            extradata.withUnsafeBytes { raw in
                if let base = raw.baseAddress { copy.copyMemory(from: base, byteCount: extradata.count) }
            }
            context.pointee.extradata = copy.assumingMemoryBound(to: UInt8.self)
            context.pointee.extradata_size = Int32(extradata.count)
        }
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
            if isVideo {
                if let buffer = try picture(frame, at: time) { buffers.append(buffer) }
            } else {
                buffers += try sound(frame, at: time)
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
        PictureTags.apply(from: frame, to: pixels)
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

    /// The fewest samples a sound buffer holds, about 21 ms at 48 kHz.
    /// TrueHD frames hold 40 samples and DTS frames 512; one buffer each
    /// would fill the audio feed's limit with a fraction of a second.
    static let soundSamples = 1024

    /// Interleaves a decoded sound frame into 32-bit float PCM, on the
    /// speakers the decoder names, and joins short frames into buffers of at
    /// least `soundSamples`. Returns the buffers that are complete.
    private func sound(_ frame: UnsafeMutablePointer<AVFrame>, at time: CMTime) throws -> [CMSampleBuffer] {
        let samples = Int(frame.pointee.nb_samples)
        let channels = Int(frame.pointee.ch_layout.nb_channels)
        let rate = Int(frame.pointee.sample_rate)
        guard samples > 0, channels > 0, rate > 0, let planes = frame.pointee.extended_data,
            let pcm = Self.interleaved(planes, format: AVSampleFormat(rawValue: frame.pointee.format), samples: samples, channels: channels)
        else { return [] }
        let layout = frame.pointee.ch_layout
        let shape = SoundShape(rate: rate, channels: channels, mask: layout.order == AV_CHANNEL_ORDER_NATIVE ? layout.u.mask : 0)
        // Sound frames the container gave no time follow the previous one,
        // as the frames FFmpeg's parser cuts from one packet do.
        let start = SampleBuilder.soundStart(time.value == Int64.min ? .invalid : time, following: nextSoundTime)
        guard start.isValid else { return [] }
        nextSoundTime = CMTimeAdd(start, CMTime(value: CMTimeValue(samples), timescale: CMTimeScale(rate)))
        var buffers: [CMSampleBuffer] = []
        // A frame from before the end of the held sound, as when the run
        // queues sound again from its ring, replaces it: the ring brings
        // that sound again. A frame that changes format or comes after a gap
        // starts a new buffer, as when a broadcast goes from stereo to mono
        // between programmes.
        if let held = heldSound {
            let gap = CMTimeSubtract(start, held.end).seconds
            if gap < -0.001 {
                heldSound = nil
            } else if held.shape != shape || gap > 0.001 {
                buffers += try releaseSound()
            }
        }
        if var held = heldSound {
            held.pcm += pcm
            held.samples += samples
            heldSound = held
        } else {
            heldSound = HeldSound(pcm: pcm, start: start, samples: samples, shape: shape)
        }
        if (heldSound?.samples ?? 0) >= Self.soundSamples { buffers += try releaseSound() }
        return buffers
    }

    /// Sound decoded but not yet in a buffer.
    private struct HeldSound {
        var pcm: [Float]
        let start: CMTime
        var samples: Int
        let shape: SoundShape

        var end: CMTime {
            CMTimeAdd(start, CMTime(value: CMTimeValue(samples), timescale: CMTimeScale(shape.rate)))
        }
    }

    /// The held sound as one buffer, in a new format when its shape changed.
    private func releaseSound() throws -> [CMSampleBuffer] {
        guard let held = heldSound else { return [] }
        heldSound = nil
        if soundShape != held.shape {
            soundFormat = try Self.pcmFormat(rate: held.shape.rate, channels: held.shape.channels, mask: held.shape.mask)
            soundShape = held.shape
        }
        guard let format = soundFormat else { throw DecodeError.failed }
        return [try Self.pcmBuffer(held.pcm, format: format, samples: held.samples, time: held.start)]
    }

    /// The rate, channel count and speakers of the newest PCM format.
    private struct SoundShape: Equatable {
        let rate: Int
        let channels: Int
        let mask: UInt64
    }

    /// The samples of a decoded frame as interleaved floats, nil for a
    /// sample format no decoder in this build gives.
    private static func interleaved(
        _ planes: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>, format: AVSampleFormat, samples: Int, channels: Int
    ) -> [Float]? {
        var pcm = [Float](repeating: 0, count: samples * channels)
        func planar<Sample>(_: Sample.Type, _ convert: (Sample) -> Float) {
            for channel in 0..<channels {
                guard let plane = planes[channel] else { continue }
                plane.withMemoryRebound(to: Sample.self, capacity: samples) { source in
                    for index in 0..<samples { pcm[index * channels + channel] = convert(source[index]) }
                }
            }
        }
        func packed<Sample>(_: Sample.Type, _ convert: (Sample) -> Float) -> Bool {
            guard let plane = planes[0] else { return false }
            plane.withMemoryRebound(to: Sample.self, capacity: samples * channels) { source in
                for index in 0..<(samples * channels) { pcm[index] = convert(source[index]) }
            }
            return true
        }
        switch format {
        case AV_SAMPLE_FMT_FLTP: planar(Float.self) { $0 }
        case AV_SAMPLE_FMT_S16P: planar(Int16.self) { Float($0) / 32768 }
        case AV_SAMPLE_FMT_S32P: planar(Int32.self) { Float($0) / 2_147_483_648 }
        case AV_SAMPLE_FMT_FLT: guard packed(Float.self, { $0 }) else { return nil }
        case AV_SAMPLE_FMT_S16: guard packed(Int16.self, { Float($0) / 32768 }) else { return nil }
        case AV_SAMPLE_FMT_S32: guard packed(Int32.self, { Float($0) / 2_147_483_648 }) else { return nil }
        default: return nil
        }
        return pcm
    }

    /// A buffer of interleaved float PCM.
    static func pcmBuffer(_ pcm: [Float], format: CMAudioFormatDescription, samples: Int, time: CMTime) throws -> CMSampleBuffer {
        let data = pcm.withUnsafeBytes { Data($0) }
        let block = try SampleBuilder.blockBuffer(data)
        var buffer: CMSampleBuffer?
        guard
            CMAudioSampleBufferCreateReadyWithPacketDescriptions(
                allocator: nil, dataBuffer: block, formatDescription: format, sampleCount: samples,
                presentationTimeStamp: time, packetDescriptions: nil, sampleBufferOut: &buffer) == noErr, let buffer
        else { throw DecodeError.failed }
        return buffer
    }

    /// Speaker masks whose bitmap names the wrong speakers. Core Audio's
    /// bitmap reads the WAVE side pair as "surround direct" speakers, so
    /// 5.1 from TrueHD or DTS, which FFmpeg gives with side speakers, had no
    /// surround pair, and 7.1 and 6.1 swapped the side and back speakers.
    /// These layouts name them as Apple's own WAVE and MPEG layouts do.
    static let waveMasks: [UInt64: (channels: Int, tag: AudioChannelLayoutTag)] = [
        0x607: (5, kAudioChannelLayoutTag_MPEG_5_0_A),
        0x60F: (6, kAudioChannelLayoutTag_MPEG_5_1_A),
        0x70F: (7, kAudioChannelLayoutTag_WAVE_6_1),
        0x63F: (8, kAudioChannelLayoutTag_WAVE_7_1),
    ]

    /// Interleaved 32-bit float PCM. `mask` names the speakers as FFmpeg
    /// does, one bit each in WAVE order, which is Core Audio's channel
    /// bitmap too. With no mask, the channels are taken in WAVE order for
    /// their count.
    static func pcmFormat(rate: Int, channels: Int, mask: UInt64 = 0) throws -> CMAudioFormatDescription {
        var description = AudioStreamBasicDescription(
            mSampleRate: Float64(rate), mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked, mBytesPerPacket: UInt32(4 * channels),
            mFramesPerPacket: 1, mBytesPerFrame: UInt32(4 * channels), mChannelsPerFrame: UInt32(channels),
            mBitsPerChannel: 32, mReserved: 0)
        let bitmap = AudioChannelBitmap(rawValue: UInt32(truncatingIfNeeded: mask & 0x3FFFF))
        let known = waveMasks[mask].flatMap { $0.channels == channels ? $0.tag : nil }
        let named = known == nil && mask != 0 && bitmap.rawValue.nonzeroBitCount == channels
        let tag =
            known
            ?? (named
                ? kAudioChannelLayoutTag_UseChannelBitmap
                : SampleBuilder.waveLayouts[channels] ?? kAudioChannelLayoutTag_DiscreteInOrder | UInt32(channels))
        var layout = AudioChannelLayout(
            mChannelLayoutTag: tag, mChannelBitmap: named ? bitmap : [], mNumberChannelDescriptions: 0,
            mChannelDescriptions: AudioChannelDescription())
        var format: CMAudioFormatDescription?
        guard
            CMAudioFormatDescriptionCreate(
                allocator: nil, asbd: &description, layoutSize: MemoryLayout<AudioChannelLayout>.size, layout: &layout,
                magicCookieSize: 0, magicCookie: nil, extensions: nil, formatDescriptionOut: &format) == noErr, let format
        else { throw DecodeError.failed }
        return format
    }
}
