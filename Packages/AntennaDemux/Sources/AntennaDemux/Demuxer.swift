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
    public let width: Int
    public let height: Int
    public let sampleRate: Int
    public let channels: Int
    /// True when the container or codec marks the video as interlaced.
    public let interlaced: Bool
    /// The stream's language tag, if the container has one.
    public let language: String?
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

    public private(set) var streams: [DemuxedStream] = []
    /// The container's name, such as "mpegts" or "matroska,webm".
    public private(set) var format = ""

    private var context: UnsafeMutablePointer<AVFormatContext>?
    private var io: UnsafeMutablePointer<AVIOContext>?
    private var packet: UnsafeMutablePointer<AVPacket>?
    private let reader: Unmanaged<ReadBox>
    private var readerReleased = false
    private var timeBases: [Int: AVRational] = [:]

    /// Opens the container and reads enough to know its streams. Blocks
    /// while `read` waits for bytes.
    public init(read: @escaping Read) throws {
        av_log_set_level(AV_LOG_QUIET)
        reader = Unmanaged.passRetained(ReadBox(read))
        let size: Int32 = 64 * 1024
        guard let buffer = av_malloc(Int(size)) else { throw DemuxError.unrecognised }
        io = avio_alloc_context(
            buffer.assumingMemoryBound(to: UInt8.self), size, 0, reader.toOpaque(), ReadBox.callback, nil, nil)
        var context = avformat_alloc_context()
        context?.pointee.pb = io
        // Fast start: look at about half a second of a live stream, not the default five.
        context?.pointee.probesize = 512 * 1024
        context?.pointee.max_analyze_duration = 500_000
        guard avformat_open_input(&context, nil, nil, nil) == 0, let opened = context else {
            close()
            throw DemuxError.unrecognised
        }
        self.context = opened
        guard avformat_find_stream_info(opened, nil) >= 0, opened.pointee.nb_streams > 0 else {
            close()
            throw DemuxError.noStreams
        }
        format = String(cString: opened.pointee.iformat.pointee.name)
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
        let interlaced = [AV_FIELD_TT, AV_FIELD_BB, AV_FIELD_TB, AV_FIELD_BT].contains(parameters.field_order)
        return DemuxedStream(
            index: index, kind: kind, codec: String(cString: avcodec_get_name(parameters.codec_id)),
            extradata: extradata, width: Int(parameters.width), height: Int(parameters.height),
            sampleRate: Int(parameters.sample_rate), channels: Int(parameters.ch_layout.nb_channels),
            interlaced: interlaced, language: language)
    }
}

/// Holds the read closure for FFmpeg's C callback.
private final class ReadBox {
    let read: Demuxer.Read

    init(_ read: @escaping Demuxer.Read) {
        self.read = read
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
