import AntennaCore
import CoreMedia
import FFmpeg
import Foundation

/// One elementary stream in a container, as FFmpeg found it.
public struct DemuxedStream: Sendable, Equatable {
    public enum Kind: Sendable, Equatable { case video, audio, subtitle, other }

    public let index: Int
    public let kind: Kind
    /// FFmpeg's codec name, such as "h264", "aac" or "mpeg2video".
    public let codec: String
    /// Codec setup from the container (avcC, an AudioSpecificConfig), empty
    /// when the codec carries it in band, as H.264 and AAC in MPEG-TS do.
    public let extradata: Data
    /// The picture size the container header gives, 0 when only the
    /// stream itself says (MPEG-TS); `SampleBuilder.formatDescription` has
    /// it once the first keyframe arrives.
    public let width: Int
    public let height: Int
    /// The sound format the container header gives, 0 when only the stream
    /// itself says.
    public let sampleRate: Int
    public let channels: Int
    /// True when the container or codec marks the video as interlaced.
    public let interlaced: Bool
    /// The stream's language tag, if the container has one.
    public let language: String?
    /// Average frames a second for video, nil when the container does not say.
    public let frameRate: Double?
    /// True for the stream the container marks as its default.
    public let isDefault: Bool
    /// The provider's name for the stream, as written, if the container has one.
    public var title: String?
    /// True for subtitles the container marks as forced.
    public var isForced = false
}

/// One compressed packet with its timing.
public struct DemuxedPacket: Sendable {
    public let streamIndex: Int
    public let data: Data
    public let presentationTime: CMTime
    public let decodeTime: CMTime
    public let duration: CMTime
    public let isKeyframe: Bool
}

/// FFmpeg's demuxer over a byte source, read through a custom AVIO callback.
/// One thread at a time: it may be opened on one thread and handed to the
/// demuxing thread, but never used from two at once. Reads block on the
/// network, so keep them off the main actor.
public final class Demuxer: @unchecked Sendable {
    public enum DemuxError: Error, Equatable {
        /// FFmpeg could not recognise a container in the bytes.
        case unrecognised
        /// The bytes ended before any stream information.
        case noStreams
    }

    /// Reads up to `count` bytes into the pointer; returns the count, 0 at
    /// the end, or -1 on failure.
    public typealias Read = @Sendable (UnsafeMutablePointer<UInt8>, Int) -> Int
    /// Moves to a byte offset and returns the new position, or -1; asked for
    /// `Int64(AVSEEK_SIZE)` it returns the total length, or -1.
    public typealias Seek = @Sendable (Int64, Int32) -> Int64

    public private(set) var streams: [DemuxedStream] = []
    /// The container's name, such as "mpegts" or "matroska,webm".
    public private(set) var format = ""
    /// The container's length, nil for live streams.
    public private(set) var duration: CMTime?
    /// When the container's first picture or sound is due, the zero point
    /// of a film's position.
    public private(set) var startTime: CMTime = .invalid

    private var context: UnsafeMutablePointer<AVFormatContext>?
    private var io: UnsafeMutablePointer<AVIOContext>?
    private var packet: UnsafeMutablePointer<AVPacket>?
    private let reader: Unmanaged<ReadBox>
    private var readerReleased = false
    private var timeBases: [Int: AVRational] = [:]

    /// Opens the container and reads enough to know its streams. Blocks
    /// while `read` waits for bytes.
    /// With `seek`, FFmpeg may jump in the bytes, as films need.
    public init(read: @escaping Read, seek: Seek? = nil) throws {
        av_log_set_level(AV_LOG_QUIET)
        reader = Unmanaged.passRetained(ReadBox(read, seek: seek))
        let size: Int32 = 64 * 1024
        guard let buffer = av_malloc(Int(size)) else { throw DemuxError.unrecognised }
        io = avio_alloc_context(
            buffer.assumingMemoryBound(to: UInt8.self), size, 0, reader.toOpaque(), ReadBox.callback, nil,
            seek == nil ? nil : ReadBox.seekCallback)
        if seek != nil { io?.pointee.seekable = AVIO_SEEKABLE_NORMAL }
        var context = avformat_alloc_context()
        context?.pointee.pb = io
        context?.pointee.probesize = 256 * 1024
        // The container names each codec, so FFmpeg does not probe streams
        // for theirs. While a stream waits for that probe, FFmpeg holds back
        // the packets of every stream.
        context?.pointee.max_probe_packets = 0
        guard avformat_open_input(&context, nil, nil, nil) == 0, let opened = context else {
            close()
            throw DemuxError.unrecognised
        }
        self.context = opened
        // No avformat_find_stream_info: it decodes a little of every stream,
        // and with no H.264 or AAC decoder in this build it reads until its
        // limit before giving up, seconds on a slow stream. The container
        // header names each codec; picture size and sound format come from
        // the first keyframe and the first AAC frame instead.
        guard opened.pointee.nb_streams > 0 else {
            close()
            throw DemuxError.noStreams
        }
        format = String(cString: opened.pointee.iformat.pointee.name)
        if opened.pointee.duration > 0, opened.pointee.duration != Int64.min {
            duration = CMTime(value: opened.pointee.duration, timescale: CMTimeScale(AV_TIME_BASE))
        }
        if opened.pointee.start_time != Int64.min {
            startTime = CMTime(value: opened.pointee.start_time, timescale: CMTimeScale(AV_TIME_BASE))
        }
        streams = (0..<Int(opened.pointee.nb_streams)).compactMap { index in
            guard let stream = opened.pointee.streams[index], let parameters = stream.pointee.codecpar else { return nil }
            timeBases[index] = stream.pointee.time_base
            return Self.describe(index: index, stream: stream, parameters: parameters.pointee)
        }
        packet = av_packet_alloc()
    }

    deinit {
        close()
    }

    /// The next packet, or nil at the end of the stream. Blocks while the
    /// byte source waits for data.
    public func nextPacket() -> DemuxedPacket? {
        guard let context, let packet else { return nil }
        while true {
            guard av_read_frame(context, packet) >= 0 else { return nil }
            defer { av_packet_unref(packet) }
            let index = Int(packet.pointee.stream_index)
            guard let timeBase = timeBases[index], let bytes = packet.pointee.data, packet.pointee.size > 0 else { continue }
            let data = Data(bytes: bytes, count: Int(packet.pointee.size))
            let pts = Self.time(packet.pointee.pts, timeBase)
            let dts = Self.time(packet.pointee.dts, timeBase)
            return DemuxedPacket(
                streamIndex: index, data: data,
                presentationTime: pts.isValid ? pts : dts, decodeTime: dts,
                duration: Self.time(packet.pointee.duration, timeBase),
                isKeyframe: packet.pointee.flags & AV_PKT_FLAG_KEY != 0)
        }
    }

    /// Where a film's position counts from when it starts somewhere other
    /// than its first frame: the container's start time, or zero when the
    /// container does not say.
    public var seekOrigin: CMTime {
        startTime.isNumeric ? startTime : .zero
    }

    /// Moves to the keyframe at or before `time` into the film, counted from
    /// `origin`, by default `seekOrigin`. Returns false when the bytes cannot
    /// be skipped.
    public func seek(to time: CMTime, from origin: CMTime? = nil) -> Bool {
        guard let context, time.isNumeric else { return false }
        let origin = origin ?? seekOrigin
        let target = CMTimeConvertScale(CMTimeAdd(origin, time), timescale: CMTimeScale(AV_TIME_BASE), method: .roundTowardNegativeInfinity)
        return av_seek_frame(context, -1, target.value, AVSEEK_FLAG_BACKWARD) >= 0
    }

    /// Frees FFmpeg's state. Safe to call more than once.
    public func close() {
        if packet != nil { av_packet_free(&packet) }
        if context != nil { avformat_close_input(&context) }
        if let buffer = io?.pointee.buffer {
            av_free(buffer)
            io?.pointee.buffer = nil
        }
        if io != nil { avio_context_free(&io) }
        if !readerReleased {
            readerReleased = true
            reader.release()
        }
    }

    private static func time(_ value: Int64, _ base: AVRational) -> CMTime {
        guard value != Int64.min, base.den != 0 else { return .invalid }
        return CMTime(value: value * Int64(base.num), timescale: base.den)
    }

    private static func describe(
        index: Int, stream: UnsafeMutablePointer<AVStream>, parameters: AVCodecParameters
    ) -> DemuxedStream {
        let kind: DemuxedStream.Kind =
            switch parameters.codec_type {
            case AVMEDIA_TYPE_VIDEO: .video
            case AVMEDIA_TYPE_AUDIO: .audio
            case AVMEDIA_TYPE_SUBTITLE: .subtitle
            default: .other
            }
        let extradata =
            parameters.extradata.map { Data(bytes: $0, count: Int(parameters.extradata_size)) } ?? Data()
        let language = av_dict_get(stream.pointee.metadata, "language", nil, 0).flatMap { entry in
            entry.pointee.value.map { String(cString: $0) }
        }
        let title = av_dict_get(stream.pointee.metadata, "title", nil, 0).flatMap { entry in
            entry.pointee.value.map { String(cString: $0) }
        }
        let interlaced = [AV_FIELD_TT, AV_FIELD_BB, AV_FIELD_TB, AV_FIELD_BT].contains(parameters.field_order)
        let rate = stream.pointee.avg_frame_rate
        return DemuxedStream(
            index: index, kind: kind, codec: String(cString: avcodec_get_name(parameters.codec_id)),
            extradata: extradata, width: Int(parameters.width), height: Int(parameters.height),
            sampleRate: Int(parameters.sample_rate), channels: Int(parameters.ch_layout.nb_channels),
            interlaced: interlaced, language: language,
            frameRate: rate.den > 0 && rate.num > 0 ? Double(rate.num) / Double(rate.den) : nil,
            isDefault: stream.pointee.disposition & AV_DISPOSITION_DEFAULT != 0, title: title,
            isForced: stream.pointee.disposition & AV_DISPOSITION_FORCED != 0)
    }
}

/// Holds the read closure for FFmpeg's C callback.
private final class ReadBox {
    let read: Demuxer.Read
    let seek: Demuxer.Seek?

    init(_ read: @escaping Demuxer.Read, seek: Demuxer.Seek?) {
        self.read = read
        self.seek = seek
    }

    typealias SeekCallback = @convention(c) (UnsafeMutableRawPointer?, Int64, Int32) -> Int64

    static let seekCallback: SeekCallback = { opaque, offset, whence in
        guard let opaque else { return -1 }
        let box = Unmanaged<ReadBox>.fromOpaque(opaque).takeUnretainedValue()
        return box.seek?(offset, whence) ?? -1
    }

    typealias Callback = @convention(c) (UnsafeMutableRawPointer?, UnsafeMutablePointer<UInt8>?, Int32) -> Int32

    static let callback: Callback = { opaque, destination, count in
        guard let opaque, let destination else { return -1 }
        let box = Unmanaged<ReadBox>.fromOpaque(opaque).takeUnretainedValue()
        let read = box.read(destination, Int(count))
        if read > 0 { return Int32(read) }
        return read == 0 ? -541_478_725 : -5  // AVERROR_EOF, AVERROR(EIO)
    }
}
