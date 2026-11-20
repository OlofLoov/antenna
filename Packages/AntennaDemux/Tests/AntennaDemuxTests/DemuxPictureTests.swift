import AntennaCore
import AntennaTestSupport
import CoreMedia
import Foundation
import Testing

@testable import AntennaDemux

/// Pictures the FFmpeg path queues decode to the same pictures as a clean
/// decode of the whole stream: nothing green or broken reaches the video
/// renderer. Each picture is decoded with VideoToolbox, as the renderer does.
@Suite(.serialized, .timeLimit(.minutes(2))) struct DemuxPictureTests {
    private static func fixture(_ name: String) throws -> URL {
        try FixtureServer.fixtures().appending(path: name)
    }

    @Test(
        "playback-engine/undecodable-pictures-are-not-shown a film started between open-GOP keyframes shows only whole pictures",
        arguments: [("open-gop-hevc.mkv", 1.2, 0.96), ("open-gop-hevc.mkv", 2.0, 1.92), ("open-gop-h264.mkv", 1.2, 0.96)])
    func startsAtAnOpenGOPKeyframe(file: String, at seconds: Double, keyframe: Double) async throws {
        let url = try Self.fixture(file)
        let reference = try await PictureCheck.run(url)
        #expect(reference.pictures.count == 75)
        let started = try await PictureCheck.run(url, startAt: CMTime(seconds: seconds, preferredTimescale: 90000))
        let first = try #require(started.pictures.first)
        #expect(abs(first.time.seconds - keyframe) < 0.001, "the first picture is the keyframe")
        let damaged = PictureCheck.damaged(started, against: reference)
        #expect(damaged.isEmpty, "damaged at \(damaged.map(\.seconds))")
        #expect(started.pictures.count == reference.pictures.filter { $0.time >= first.time }.count)
    }

    @Test("playback-engine/undecodable-pictures-are-not-shown a channel that lost packets goes on from the next keyframe")
    func lostPackets() async throws {
        let reference = try await PictureCheck.run(try Self.fixture("channel.ts"))
        let damaged = try await PictureCheck.run(try Self.fixture("damaged.ts"))
        let broken = PictureCheck.damaged(damaged, against: reference)
        #expect(broken.isEmpty, "damaged at \(broken.map(\.seconds))")
        // The damaged picture and those after it up to the next keyframe
        // are left out; the rest play.
        #expect(damaged.pictures.count < reference.pictures.count)
        #expect(damaged.pictures.count > reference.pictures.count - 25)
        #expect(damaged.pictures.last?.time == reference.pictures.last?.time)
    }

    @Test(
        "playback-engine/undecodable-pictures-are-not-shown after the video renderer is flushed, pictures start at a keyframe",
        arguments: [0.3, 0.55, 0.75])
    func restartsAtAKeyframe(fraction: Double) async throws {
        let url = try Self.fixture("channel.ts")
        let reference = try await PictureCheck.run(url)
        let data = try Data(contentsOf: url)
        let bytes = GatedBytes(data, gate: Int(Double(data.count) * fraction) / 188 * 188)
        var timebase: CMTimebase?
        CMTimebaseCreateWithSourceClock(allocator: nil, sourceClock: CMClockGetHostTimeClock(), timebaseOut: &timebase)
        let clock = try #require(timebase)
        let video = KeepingRenderer(timebase: clock)
        let run = DemuxRun(
            bytes: bytes, videoFeed: SampleFeed(renderer: video, label: "test.video", limit: 1000),
            audioFeed: SampleFeed(renderer: KeepingRenderer(timebase: clock), label: "test.audio", limit: 1000))
        let ended = Flag()
        run.start(ready: { _ in }, ended: { _ in ended.set() })
        #expect(await eventually { bytes.waiting })
        try await Task.sleep(for: .milliseconds(200))
        let before = video.buffers.count
        run.restartPictures()
        bytes.open()
        #expect(await eventually { ended.value })
        try await Task.sleep(for: .milliseconds(200))
        run.cancel()
        let after = Array(video.buffers.dropFirst(before))
        let first = try #require(after.first)
        #expect(!Self.isNotSync(first), "the first picture after the flush is a keyframe")
        let damaged = PictureCheck.damaged(PictureCheck.decode(after), against: reference)
        #expect(damaged.isEmpty)
    }

    private static func isNotSync(_ buffer: CMSampleBuffer) -> Bool {
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(buffer, createIfNecessary: false) as? [[CFString: Any]]
        else { return false }
        return (attachments.first?[kCMSampleAttachmentKey_NotSync] as? Bool) == true
    }

    @Test("playback-engine/undecodable-pictures-are-not-shown a Dolby Vision enhancement layer in MPEG-TS is left out")
    func enhancementLayerInAnnexB() throws {
        let (stream, base) = try Self.videoPackets("hdr10.ts")
        let (_, extra) = try Self.videoPackets("hevc-640x360.ts")
        let mixed = zip(base, extra).map { base, extra in
            var data = base.data
            for unit in SampleBuilder.nalUnits(annexB: extra.data) {
                data.append(contentsOf: [0, 0, 0, 1] + Self.enhancementLayer(unit))
            }
            data.append(contentsOf: [0, 0, 1] + Self.metadataUnit)
            return Self.packet(base, data: data)
        }
        try Self.expectClean(stream: stream, mixed, reference: base)
    }

    @Test("playback-engine/undecodable-pictures-are-not-shown a Dolby Vision enhancement layer in Matroska or MP4 is left out")
    func enhancementLayerInHVCC() throws {
        let (clean, base) = try Self.videoPackets("hdr10.mp4")
        let (_, extra) = try Self.videoPackets("hevc-640x360.ts")
        // The record lists the enhancement layer's parameter sets first, as a
        // remux of a dual-layer film may.
        let sets = try #require(extra.first).data
        let stream = DemuxedStream(
            index: clean.index, kind: .video, codec: clean.codec,
            extradata: Self.hvcC(clean.extradata, leadingWith: SampleBuilder.nalUnits(annexB: sets).map(Self.enhancementLayer)),
            width: clean.width, height: clean.height, sampleRate: 0, channels: 0, interlaced: false, language: nil,
            frameRate: clean.frameRate, isDefault: true)
        let mixed = zip(base, extra).map { base, extra in
            let units = SampleBuilder.nalUnits(annexB: extra.data).map(Self.enhancementLayer) + [Data(Self.metadataUnit)]
            return Self.packet(base, data: base.data + SampleBuilder.lengthPrefixed(units))
        }
        try Self.expectClean(stream: stream, mixed, reference: base, referenceStream: clean)
    }

    private static func expectClean(
        stream: DemuxedStream, _ packets: [DemuxedPacket], reference: [DemuxedPacket], referenceStream: DemuxedStream? = nil
    ) throws {
        let clean = PictureCheck.decode(try buffers(referenceStream ?? stream, Array(reference.prefix(packets.count))))
        let mixed = PictureCheck.decode(try buffers(stream, packets))
        #expect(mixed.pictures.count == clean.pictures.count)
        #expect(clean.pictures.count > 40)
        #expect(PictureCheck.damaged(mixed, against: clean).isEmpty)
    }

    /// A Dolby Vision RPU unit: type 62, layer 0.
    private static let metadataUnit: [UInt8] = [62 << 1, 1, 0x11, 0x22, 0x33, 0x44]

    /// `unit` moved to layer 1, as an enhancement layer's units are.
    private static func enhancementLayer(_ unit: Data) -> Data {
        var bytes = [UInt8](unit)
        bytes[1] = (bytes[1] & 0x07) | (1 << 3)
        return Data(bytes)
    }

    /// An hvcC record whose arrays list `units` (VPS, SPS, PPS) before the
    /// record's own.
    private static func hvcC(_ record: Data, leadingWith units: [Data]) -> Data {
        let bytes = [UInt8](record)
        var out = Array(bytes.prefix(23))
        var index = 23
        for _ in 0..<Int(bytes[22]) {
            let header = bytes[index]
            let type = Int(header & 0x3F)
            let count = Int(bytes[index + 1]) << 8 | Int(bytes[index + 2])
            var entries: [[UInt8]] = units.filter { SampleBuilder.hevcType($0) == type }.map { [UInt8]($0) }
            index += 3
            for _ in 0..<count {
                let length = Int(bytes[index]) << 8 | Int(bytes[index + 1])
                entries.append(Array(bytes[(index + 2)..<(index + 2 + length)]))
                index += 2 + length
            }
            out += [header, UInt8(entries.count >> 8), UInt8(entries.count & 0xFF)]
            for entry in entries { out += [UInt8(entry.count >> 8), UInt8(entry.count & 0xFF)] + entry }
        }
        return Data(out)
    }

    private static func packet(_ base: DemuxedPacket, data: Data) -> DemuxedPacket {
        DemuxedPacket(
            streamIndex: base.streamIndex, data: data, presentationTime: base.presentationTime, decodeTime: base.decodeTime,
            duration: base.duration, isKeyframe: base.isKeyframe)
    }

    private static func buffers(_ stream: DemuxedStream, _ packets: [DemuxedPacket]) throws -> [CMSampleBuffer] {
        let builder = try SampleBuilder(stream: stream)
        return try packets.compactMap { try builder.sampleBuffer(for: $0) }
    }

    private static func videoPackets(_ file: String) throws -> (DemuxedStream, [DemuxedPacket]) {
        let bytes = MemoryBytes(try Data(contentsOf: try fixture(file)))
        let demuxer = try Demuxer(read: { bytes.read(into: $0, count: $1) })
        let stream = try #require(demuxer.streams.first { $0.kind == .video })
        var packets: [DemuxedPacket] = []
        while let packet = demuxer.nextPacket() {
            if packet.streamIndex == stream.index { packets.append(packet) }
        }
        return (stream, packets)
    }
}
