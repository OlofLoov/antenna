import AntennaCore
import AudioToolbox
import CoreMedia
import Foundation

/// Turns one stream's compressed packets into `CMSampleBuffer`s that
/// Apple's decoders and sample-buffer renderers read: H.264 (Annex B from
/// MPEG-TS, or avcC from Matroska and MP4), HEVC (Annex B, or hvcC),
/// MPEG-4 Part 2 video (AVI), AAC
/// (ADTS from MPEG-TS, or raw with an AudioSpecificConfig), MP3, and Dolby
/// Digital and Dolby Digital Plus (AC-3, E-AC-3), which Apple TV passes to
/// a receiver that takes them and every device decodes otherwise.
public final class SampleBuilder {
    public enum BuildError: Error, Equatable {
        case unsupportedCodec(String)
        case malformed
    }

    private enum Codec {
        case h264AnnexB
        case h264AVCC
        case aacADTS
        case aacRaw(config: Data)
        case mpeg4Video
        case mp3
        case hevcAnnexB
        case hevcHVCC
        case dolby
        /// MPEG-2 video or MP2 sound, decoded in software.
        case software(SoftwareDecoder)
        /// MPEG audio of a layer the first frame header will tell: MPEG-TS
        /// labels MP2 and MP3 alike.
        case mpegAudio
    }

    private var codec: Codec
    public let stream: DemuxedStream
    /// The codec the stream turned out to carry: the container's name, or
    /// "mp2" or "mp3" once an MPEG audio frame header has said which.
    public private(set) var codecName: String
    /// The format of the buffers built so far; nil for H.264 in MPEG-TS
    /// until the first parameter sets arrive.
    public private(set) var formatDescription: CMFormatDescription?
    /// Where the next AAC frame starts, for frames FFmpeg gives no time:
    /// it times only the first frame of a multi-frame packet.
    private var nextSoundTime: CMTime = .invalid
    /// What the newest sound frame header said, so a change of channels or
    /// rate partway through gets a new format: an AudioSpecificConfig from
    /// ADTS, a Dolby header, or an MPEG audio header.
    private var soundHeader: SoundHeader?

    private enum SoundHeader: Equatable {
        case aac(Data)
        case dolby(DolbyHeader)
        case mpeg(MPEGAudioHeader)
    }

    /// Throws `unsupportedCodec` for a codec with no builder yet.
    public init(stream: DemuxedStream) throws {
        self.stream = stream
        codecName = stream.codec
        switch stream.codec {
        case "h264" where stream.extradata.first == 1:
            codec = .h264AVCC
            formatDescription = try Self.h264Format(avcC: stream.extradata, width: stream.width, height: stream.height)
        case "h264":
            codec = .h264AnnexB
        case "aac" where !stream.extradata.isEmpty:
            codec = .aacRaw(config: stream.extradata)
        case "aac":
            codec = .aacADTS
        case "hevc" where stream.extradata.first == 1:
            codec = .hevcHVCC
            formatDescription = try Self.hevcFormat(parameterSets: Self.hevcParameterSets(hvcC: stream.extradata))
        case "hevc":
            codec = .hevcAnnexB
        case "ac3", "eac3":
            codec = .dolby
        case "mpeg2video":
            codec = .software(try SoftwareDecoder(codec: stream.codec))
        case "mp2", "mp3":
            codec = .mpegAudio
        case "mpeg4":
            codec = .mpeg4Video
            if !stream.extradata.isEmpty {
                formatDescription = try Self.mpeg4VideoFormat(config: stream.extradata, width: stream.width, height: stream.height)
            }
        default:
            throw BuildError.unsupportedCodec(stream.codec)
        }
    }

    /// The sample buffers for `packet`. A compressed codec gives one, or none
    /// before its first parameter sets; a software decoder gives none while it
    /// waits for a reference frame, and sometimes more than one.
    public func sampleBuffers(for packet: DemuxedPacket) throws -> [CMSampleBuffer] {
        if case .mpegAudio = codec {
            try resolveMPEGAudio(packet)
            // No frame header yet: nothing to build until one arrives.
            if case .mpegAudio = codec { return [] }
        }
        guard case .software(let decoder) = codec else { return try sampleBuffer(for: packet).map { [$0] } ?? [] }
        let buffers = try decoder.decode(packet)
        if let last = buffers.last, let format = CMSampleBufferGetFormatDescription(last) {
            formatDescription = format
        }
        return buffers
    }

    /// The sample buffer for `packet`, or nil when it cannot be shown yet
    /// (H.264 or HEVC before their first parameter sets). For a software
    /// decoder, the first of `sampleBuffers(for:)`.
    public func sampleBuffer(for packet: DemuxedPacket) throws -> CMSampleBuffer? {
        switch codec {
        case .h264AnnexB:
            return try annexB(packet, parameterSets: [7, 8], dropped: [7, 8, 9], type: Self.h264Type) {
                try Self.h264Format(sps: $0[0], pps: $0[1])
            }
        case .hevcAnnexB:
            return try annexB(packet, parameterSets: [32, 33, 34], dropped: [32, 33, 34, 35], type: Self.hevcType) {
                try Self.hevcFormat(parameterSets: $0)
            }
        case .h264AVCC, .hevcHVCC:
            return try formatDescription.map { try Self.videoBuffer(packet.data, format: $0, packet: packet) }
        case .mpeg4Video:
            // No configuration in the header: AVI often carries it in front
            // of the first frame.
            if formatDescription == nil, let config = Self.mpeg4Config(inFrame: packet.data) {
                formatDescription = try Self.mpeg4VideoFormat(config: config, width: stream.width, height: stream.height)
            }
            return try formatDescription.map { try Self.videoBuffer(packet.data, format: $0, packet: packet) }
        case .aacADTS:
            let frames = try Self.adtsFrames(packet.data)
            guard let first = frames.first else { return nil }
            if soundHeader != .aac(first.config) {
                formatDescription = try Self.aacFormat(config: first.config)
                soundHeader = .aac(first.config)
            }
            return try formatDescription.flatMap { try soundBuffer(frames.map(\.payload), format: $0, packet: packet) }
        case .aacRaw(let config):
            if formatDescription == nil { formatDescription = try Self.aacFormat(config: config) }
            return try formatDescription.flatMap { try soundBuffer([packet.data], format: $0, packet: packet) }
        case .mp3:
            if let header = Self.mpegAudioHeader(packet.data), header.layer == 3, soundHeader != .mpeg(header) {
                formatDescription = try Self.mp3Format(sampleRate: header.sampleRate, channels: header.channels, samples: header.samples)
                soundHeader = .mpeg(header)
            }
            return try formatDescription.flatMap { try soundBuffer([packet.data], format: $0, packet: packet) }
        case .software, .mpegAudio:
            return try sampleBuffers(for: packet).first
        case .dolby:
            if let header = Self.dolbyHeader(packet.data), soundHeader != .dolby(header) {
                formatDescription = try Self.dolbyFormat(header)
                soundHeader = .dolby(header)
            }
            return try formatDescription.flatMap { try soundBuffer([packet.data], format: $0, packet: packet) }
        }
    }

    /// Picks the path for MPEG audio from its first frame header: layer III
    /// is MP3, which Apple decodes; layers I and II go to the software
    /// decoder.
    private func resolveMPEGAudio(_ packet: DemuxedPacket) throws {
        guard let header = Self.mpegAudioHeader(packet.data) else { return }
        if header.layer == 3 {
            codec = .mp3
            codecName = "mp3"
        } else {
            codec = .software(try SoftwareDecoder(codec: "mp2"))
            codecName = "mp2"
        }
    }

    /// A video buffer from Annex B bytes: the format is taken from the
    /// parameter sets when a packet carries all of them, and the units of
    /// the `dropped` types are left out of the sample.
    private func annexB(
        _ packet: DemuxedPacket, parameterSets: [Int], dropped: Set<Int>, type: (Data) -> Int?,
        format makeFormat: ([Data]) throws -> CMFormatDescription
    ) throws -> CMSampleBuffer? {
        let units = Self.nalUnits(annexB: packet.data)
        let sets = parameterSets.compactMap { wanted in units.last { type($0) == wanted } }
        if sets.count == parameterSets.count { formatDescription = try makeFormat(sets) }
        guard let format = formatDescription else { return nil }
        let payload = units.filter { unit in type(unit).map { !dropped.contains($0) } ?? false }
        guard !payload.isEmpty else { return nil }
        return try Self.videoBuffer(Self.lengthPrefixed(payload), format: format, packet: packet)
    }

    /// An AAC or MP3 buffer timed by the packet, or right after the previous
    /// one when the packet has no time.
    private func soundBuffer(_ frames: [Data], format: CMFormatDescription, packet: DemuxedPacket) throws -> CMSampleBuffer? {
        let time = packet.presentationTime.isValid ? packet.presentationTime : nextSoundTime
        guard time.isValid, let description = CMAudioFormatDescriptionGetStreamBasicDescription(format)?.pointee,
            description.mSampleRate > 0
        else { return nil }
        let buffer = try Self.audioBuffer(frames, format: format, time: time)
        let samples = frames.count * Int(description.mFramesPerPacket)
        nextSoundTime = CMTimeAdd(time, CMTime(value: CMTimeValue(samples), timescale: CMTimeScale(description.mSampleRate)))
        return buffer
    }
}
