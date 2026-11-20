@preconcurrency import AVFoundation
import AntennaCore
import AntennaTestSupport
import CoreMedia
import Foundation
import Testing

@testable import AntennaDemux

/// Film sound that the software decoder makes (TrueHD, DTS) or Apple decodes
/// (AC-3) reaches the audio renderer as one unbroken run of buffers, on the
/// right speakers, however Matroska rounds its times.
@Suite(.serialized, .timeLimit(.minutes(2))) struct DemuxSoundTimingTests {
    private static func fixture(_ name: String) throws -> URL {
        try FixtureServer.fixtures().appending(path: name)
    }

    @Test(
        "playback-engine/film-sound-plays-without-clicks each sound buffer starts where the one before it ends",
        arguments: ["truehd-5.1.mkv", "dts-and-ac3.mkv", "vorbis-and-ac3.mkv", "surround-ac3.ts", "channel.ts"])
    func buffersFollowOn(file: String) async throws {
        let outcome = try await PictureCheck.run(try Self.fixture(file))
        #expect(outcome.sound.count > 10)
        let joins = zip(outcome.sound, outcome.sound.dropFirst()).map { earlier, later in
            CMTimeSubtract(later.time, CMTimeAdd(earlier.time, earlier.duration)).seconds
        }
        // Matroska times to the millisecond; a join off by more than one
        // sample at 48 kHz is a gap or an overlap the renderer plays as a click.
        let broken = joins.filter { abs($0) > 1.0 / 48000 }
        #expect(broken.isEmpty, "\(broken.count) of \(joins.count) joins off, first \(broken.prefix(3))")
    }

    @Test("playback-engine/film-sound-plays-without-clicks sound stays within 10 ms of the container's times")
    func soundKeepsItsTime() throws {
        let (stream, packets) = try Self.soundPackets("truehd-5.1.mkv")
        let builder = try SampleBuilder(stream: stream)
        var largest = 0.0
        for packet in packets {
            for buffer in try builder.sampleBuffers(for: packet) where packet.presentationTime.isNumeric {
                // The buffer holds the frames of earlier packets too; its end
                // is checked against this packet's end.
                let end = CMTimeAdd(CMSampleBufferGetPresentationTimeStamp(buffer), CMSampleBufferGetDuration(buffer))
                let expected = CMTimeAdd(packet.presentationTime, CMTime(value: 40, timescale: 48000))
                largest = max(largest, abs(CMTimeSubtract(end, expected).seconds))
            }
        }
        #expect(largest <= SampleBuilder.soundJitter.seconds + 0.001)
    }

    @Test("playback-engine/film-sound-plays-without-clicks TrueHD started between major syncs keeps its time")
    func trueHDFromTheMiddle() throws {
        let (stream, packets) = try Self.soundPackets("truehd-5.1.mkv")
        let middle = packets.count / 2
        let start = try #require(packets[middle...].firstIndex { !$0.isKeyframe })
        let sync = try #require(packets[start...].first { $0.isKeyframe })
        let builder = try SampleBuilder(stream: stream)
        let buffers = try packets[start...].flatMap { try builder.sampleBuffers(for: $0) }
        let first = try #require(buffers.first)
        // No sound comes out until a major sync, and it starts at its time.
        #expect(abs(CMTimeSubtract(CMSampleBufferGetPresentationTimeStamp(first), sync.presentationTime).seconds) < 0.001)
    }

    @Test(
        "playback-engine/film-sound-plays-without-clicks 5.1, 6.1 and 7.1 sound has its side and back speakers in place",
        arguments: [
            Speakers(
                mask: 0x63F,
                labels: [Label.left, Label.right, Label.center, Label.lfe, Label.rearLeft, Label.rearRight, Label.left5, Label.right5]),
            Speakers(mask: 0x70F, labels: [Label.left, Label.right, Label.center, Label.lfe, Label.back, Label.left5, Label.right5]),
            Speakers(
                mask: 0,
                labels: [Label.left, Label.right, Label.center, Label.lfe, Label.rearLeft, Label.rearRight, Label.left5, Label.right5]),
            Speakers(mask: 0x607, labels: [Label.left, Label.right, Label.center, Label.left5, Label.right5]),
            Speakers(mask: 0x3F, labels: [Label.left, Label.right, Label.center, Label.lfe, Label.left5, Label.right5]),
            Speakers(mask: 0x60F, labels: [Label.left, Label.right, Label.center, Label.lfe, Label.left5, Label.right5]),
        ])
    func speakers(_ speakers: Speakers) throws {
        let format = try SoftwareDecoder.pcmFormat(rate: 48000, channels: speakers.labels.count, mask: speakers.mask)
        #expect(Self.labels(format) == speakers.labels)
    }

    struct Speakers: Sendable, CustomTestStringConvertible {
        let mask: UInt64
        let labels: [AudioChannelLabel]
        var testDescription: String { "mask \(String(mask, radix: 16))" }
    }

    /// Short names for the speaker labels the cases use.
    enum Label {
        static let left = kAudioChannelLabel_Left
        static let right = kAudioChannelLabel_Right
        static let center = kAudioChannelLabel_Center
        static let lfe = kAudioChannelLabel_LFEScreen
        static let left5 = kAudioChannelLabel_LeftSurround
        static let right5 = kAudioChannelLabel_RightSurround
        static let rearLeft = kAudioChannelLabel_RearSurroundLeft
        static let rearRight = kAudioChannelLabel_RearSurroundRight
        static let back = kAudioChannelLabel_CenterSurround
    }

    @Test func theRingKeepsTheLastTenSeconds() {
        var ring = SoundRing(length: CMTime(value: 10, timescale: 1))
        for index in 0..<36_000 {
            ring.add(Self.packet(index))
        }
        let kept = ring.kept
        #expect(kept.count == 12_001)
        #expect(kept.first?.presentationTime == CMTime(value: 36_000 - 12_001, timescale: 1200))
        #expect(kept.last?.presentationTime == CMTime(value: 35_999, timescale: 1200))
    }

    @Test("playback-engine/audio-and-subtitle-languages the ring keeps the MPEG-TS frames that come with no time")
    func theRingKeepsFramesWithNoTime() {
        var ring = SoundRing(length: CMTime(value: 10, timescale: 1))
        ring.add(Self.packet(-1, timed: false))
        for index in 0..<24_000 {
            ring.add(Self.packet(index, timed: index.isMultiple(of: 16)))
        }
        let kept = ring.kept
        // The newest timed packet is 23,984; the ring keeps ten seconds back
        // from it and the untimed packets after each timed one.
        #expect(kept.first?.presentationTime == CMTime(value: 23_984 - 12_000, timescale: 1200))
        #expect(kept.count == 24_000 - 11_984)
        let around = ring.kept(around: CMTime(value: 20_010, timescale: 1200))
        #expect(around.first?.presentationTime == CMTime(value: 20_000, timescale: 1200))
        #expect(around.count == 4000)
    }

    @Test func theRingCostsTheSamePerPacketHoweverFullItIs() {
        guard ProcessInfo.processInfo.environment["ANTENNA_BENCHMARKS"] == "1" else { return }
        var ring = SoundRing(length: CMTime(value: 10, timescale: 1))
        let started = ContinuousClock.now
        // 30 seconds of TrueHD: 1,200 packets a second.
        for index in 0..<36_000 { ring.add(Self.packet(index)) }
        #expect(ContinuousClock.now - started < .milliseconds(100))
    }

    private static func packet(_ index: Int, timed: Bool = true) -> DemuxedPacket {
        DemuxedPacket(
            streamIndex: 1, data: Data(count: 300),
            presentationTime: timed ? CMTime(value: CMTimeValue(index), timescale: 1200) : .invalid,
            decodeTime: .invalid, duration: .invalid, isKeyframe: false)
    }

    private static func soundPackets(_ file: String) throws -> (DemuxedStream, [DemuxedPacket]) {
        let bytes = MemoryBytes(try Data(contentsOf: try fixture(file)))
        let demuxer = try Demuxer(read: { bytes.read(into: $0, count: $1) })
        let stream = try #require(demuxer.streams.first { $0.kind == .audio })
        var packets: [DemuxedPacket] = []
        while let packet = demuxer.nextPacket() {
            if packet.streamIndex == stream.index { packets.append(packet) }
        }
        return (stream, packets)
    }

    /// The speaker of each channel, in order, as Core Audio reads the format's layout.
    private static func labels(_ format: CMAudioFormatDescription) -> [AudioChannelLabel] {
        guard let layout = AVAudioFormat(cmAudioFormatDescription: format).channelLayout else { return [] }
        var source = layout.layout.pointee
        let channels = Int(layout.channelCount)
        let size = MemoryLayout<AudioChannelLayout>.size + channels * MemoryLayout<AudioChannelDescription>.size
        let raw = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: 8)
        defer { raw.deallocate() }
        var length = UInt32(size)
        let status: OSStatus
        switch source.mChannelLayoutTag {
        case kAudioChannelLayoutTag_UseChannelBitmap:
            status = AudioFormatGetProperty(
                kAudioFormatProperty_ChannelLayoutForBitmap, UInt32(MemoryLayout<UInt32>.size), &source.mChannelBitmap, &length, raw)
        default:
            status = AudioFormatGetProperty(
                kAudioFormatProperty_ChannelLayoutForTag, UInt32(MemoryLayout<AudioChannelLayoutTag>.size), &source.mChannelLayoutTag,
                &length, raw)
        }
        guard status == noErr else { return [] }
        let full = raw.assumingMemoryBound(to: AudioChannelLayout.self)
        let count = Int(full.pointee.mNumberChannelDescriptions)
        let offset = MemoryLayout<AudioChannelLayout>.offset(of: \.mChannelDescriptions) ?? 12
        let first = (raw + offset).assumingMemoryBound(to: AudioChannelDescription.self)
        return UnsafeBufferPointer(start: first, count: count).map(\.mChannelLabel)
    }
}
