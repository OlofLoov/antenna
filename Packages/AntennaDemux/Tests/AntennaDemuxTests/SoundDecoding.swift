@preconcurrency import AVFoundation
import CoreMedia
import Foundation

@testable import AntennaDemux

/// Runs a file's sound through `SampleBuilder` and Apple's decoder, the way
/// the audio renderer takes it, and measures what comes out.
enum SoundDecoding {
    struct Piece: Equatable {
        let sampleRate: Double
        let channels: Int
        var frames: Int
        /// Root mean square of every decoded sample in the piece.
        var level: Double
    }

    struct Outcome {
        /// One piece per run of buffers with the same decoded format.
        var pieces: [Piece] = []
        /// Buffers whose duration does not match the frames they decode to.
        var mistimed = 0
        /// Buffers Apple's decoder refused.
        var failures = 0
        var codecName = ""
        var buffers = 0
    }

    /// Reads `file` with FFmpeg and decodes the sound stream `pick` chooses.
    static func decode(_ file: URL, pick: (DemuxedStream) -> Bool = { $0.kind == .audio }) throws -> Outcome {
        let data = try Data(contentsOf: file)
        final class Reader: @unchecked Sendable {
            let data: Data
            var offset = 0
            init(_ data: Data) { self.data = data }
        }
        let reader = Reader(data)
        let demuxer = try Demuxer(read: { destination, count in
            let taken = min(count, reader.data.count - reader.offset)
            guard taken > 0 else { return 0 }
            reader.data.withUnsafeBytes { raw in
                guard let base = raw.baseAddress else { return }
                destination.update(from: base.advanced(by: reader.offset).assumingMemoryBound(to: UInt8.self), count: taken)
            }
            reader.offset += taken
            return taken
        })
        guard let stream = demuxer.streams.first(where: pick) else { return Outcome() }
        let builder = try SampleBuilder(stream: stream)
        var outcome = Outcome()
        var decoder: (format: CMFormatDescription, converter: AVAudioConverter?)?
        while let packet = demuxer.nextPacket() {
            guard packet.streamIndex == stream.index else { continue }
            for buffer in try builder.sampleBuffers(for: packet) {
                outcome.buffers += 1
                guard let format = CMSampleBufferGetFormatDescription(buffer) else { continue }
                if decoder.map({ !CMFormatDescriptionEqual($0.format, otherFormatDescription: format) }) ?? true {
                    decoder = (format, converter(for: format))
                }
                guard let pcm = decoded(buffer, format: format, converter: decoder?.converter) else {
                    outcome.failures += 1
                    continue
                }
                let duration = CMSampleBufferGetDuration(buffer)
                let decodedLength = Double(pcm.frameLength) / pcm.format.sampleRate
                if duration.isNumeric, pcm.frameLength > 0, abs(duration.seconds - decodedLength) > 0.002 { outcome.mistimed += 1 }
                add(pcm, to: &outcome)
            }
        }
        outcome.codecName = builder.codecName
        return outcome
    }

    private static func converter(for format: CMFormatDescription) -> AVAudioConverter? {
        let input = AVAudioFormat(cmAudioFormatDescription: format)
        guard input.commonFormat == .otherFormat else { return nil }
        let layout =
            input.channelLayout
            ?? AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_DiscreteInOrder | AudioChannelLayoutTag(input.channelCount))
        guard let layout else { return nil }
        let output = AVAudioFormat(standardFormatWithSampleRate: 48000, channelLayout: layout)
        return AVAudioConverter(from: input, to: output)
    }

    private static func decoded(_ buffer: CMSampleBuffer, format: CMFormatDescription, converter: AVAudioConverter?) -> AVAudioPCMBuffer? {
        let input = AVAudioFormat(cmAudioFormatDescription: format)
        guard let block = CMSampleBufferGetDataBuffer(buffer) else { return nil }
        var bytes = Data(count: CMBlockBufferGetDataLength(block))
        let copied = bytes.withUnsafeMutableBytes { raw in
            raw.baseAddress.map { CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: raw.count, destination: $0) } ?? -1
        }
        guard copied == noErr else { return nil }
        guard input.streamDescription.pointee.mFormatID != kAudioFormatLinearPCM else {
            // Already PCM, as the software decoder makes it.
            let frames = CMSampleBufferGetNumSamples(buffer)
            guard let pcm = AVAudioPCMBuffer(pcmFormat: input, frameCapacity: AVAudioFrameCount(frames)) else { return nil }
            pcm.frameLength = AVAudioFrameCount(frames)
            guard bytes.count == frames * Int(input.streamDescription.pointee.mBytesPerFrame) else { return nil }
            bytes.withUnsafeBytes { raw in
                guard let base = raw.baseAddress else { return }
                pcm.mutableAudioBufferList.pointee.mBuffers.mData?.copyMemory(from: base, byteCount: raw.count)
            }
            return pcm
        }
        guard let converter else { return nil }
        var descriptionsPointer: UnsafePointer<AudioStreamPacketDescription>?
        var count = 0
        guard
            CMSampleBufferGetAudioStreamPacketDescriptionsPtr(
                buffer, packetDescriptionsPointerOut: &descriptionsPointer, sizeOut: &count) == noErr,
            let descriptionsPointer
        else { return nil }
        let packets = count / MemoryLayout<AudioStreamPacketDescription>.size
        let compressed = AVAudioCompressedBuffer(
            format: input, packetCapacity: AVAudioPacketCount(packets), maximumPacketSize: max(bytes.count, 1))
        bytes.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return }
            compressed.data.copyMemory(from: base, byteCount: raw.count)
        }
        compressed.byteLength = UInt32(bytes.count)
        compressed.packetCount = AVAudioPacketCount(packets)
        compressed.packetDescriptions?.update(from: descriptionsPointer, count: packets)
        let perPacket = max(Int(input.streamDescription.pointee.mFramesPerPacket), 1024)
        guard
            let pcm = AVAudioPCMBuffer(
                pcmFormat: converter.outputFormat, frameCapacity: AVAudioFrameCount(perPacket * packets * 4))
        else { return nil }
        var given = false
        var error: NSError?
        let status = converter.convert(to: pcm, error: &error) { _, state in
            if given {
                state.pointee = .noDataNow
                return nil
            }
            given = true
            state.pointee = .haveData
            return compressed
        }
        guard status != .error, error == nil else { return nil }
        return pcm
    }

    private static func add(_ pcm: AVAudioPCMBuffer, to outcome: inout Outcome) {
        let channels = Int(pcm.format.channelCount)
        let frames = Int(pcm.frameLength)
        var sum = 0.0
        if let planes = pcm.floatChannelData, !pcm.format.isInterleaved {
            for channel in 0..<channels {
                for index in 0..<frames { sum += Double(planes[channel][index] * planes[channel][index]) }
            }
        } else if let samples = pcm.floatChannelData?[0] {
            for index in 0..<(frames * channels) { sum += Double(samples[index] * samples[index]) }
        }
        let rate = pcm.format.sampleRate
        if var last = outcome.pieces.last, last.sampleRate == rate, last.channels == channels {
            let total = last.frames + frames
            let energy = last.level * last.level * Double(last.frames * channels) + sum
            last.frames = total
            last.level = total > 0 ? (energy / Double(total * channels)).squareRoot() : 0
            outcome.pieces[outcome.pieces.count - 1] = last
        } else {
            let level = frames > 0 ? (sum / Double(frames * channels)).squareRoot() : 0
            outcome.pieces.append(Piece(sampleRate: rate, channels: channels, frames: frames, level: level))
        }
    }
}
