import AntennaCore
import AntennaTestSupport
import CoreMedia
import Foundation
import Synchronization
import Testing

@testable import AntennaDemux

/// The Annex B video path of `SampleBuilder` runs for every frame of a raw
/// broadcast channel, on each multi-view tile at once. These tests pin what
/// it returns, and under `ANTENNA_BENCHMARKS=1 swift test` what it costs.
@Suite struct SampleBuilderSpeedTests {
    @Test(
        arguments: [
            [0, 0, 1, 9, 0xF0, 0, 0, 0, 1, 0x67, 1, 2, 0, 0, 1, 0x68, 3, 0, 0, 1, 0x65, 4, 5, 6],
            [0, 0, 1, 0, 0, 1, 0x41, 0, 0, 0, 0, 1, 0x41, 0, 0],
            [7, 7, 0, 0, 1, 0x41, 2, 0, 1, 0, 0, 2, 0, 0, 1],
            [0, 0, 1],
            [1, 1, 1, 0, 0],
            [],
        ] as [[UInt8]])
    func splitsUnitsAsBefore(bytes: [UInt8]) {
        #expect(SampleBuilder.nalUnits(annexB: Data(bytes)) == Self.referenceUnits(bytes))
    }

    @Test func splitsEveryFixturePacketAsBefore() throws {
        for file in ["channel.ts", "hdr10.ts", "interlaced-1080i.ts", "resize.ts"] {
            let (streams, packets) = try Self.packets(file)
            let video = try #require(streams.first { $0.kind == .video })
            for packet in packets where packet.streamIndex == video.index {
                #expect(SampleBuilder.nalUnits(annexB: packet.data) == Self.referenceUnits([UInt8](packet.data)))
            }
        }
    }

    @Test func aKeyframeRepeatingItsParameterSetsKeepsTheFormat() throws {
        let (streams, packets) = try Self.packets("channel.ts")
        let video = try #require(streams.first { $0.kind == .video })
        let keyframes = packets.filter { $0.streamIndex == video.index && $0.isKeyframe }
        try #require(keyframes.count >= 2)
        let builder = try SampleBuilder(stream: video)
        _ = try builder.sampleBuffers(for: keyframes[0])
        let first = try #require(builder.formatDescription)
        let buffer = try #require(try builder.sampleBuffers(for: keyframes[1]).first)
        #expect(builder.formatDescription === first)
        #expect(CMSampleBufferGetFormatDescription(buffer) === first)
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["ANTENNA_BENCHMARKS"] == "1"))
    func buildsASecondOfBroadcastVideoQuickly() throws {
        let (streams, packets) = try Self.packets("channel.ts")
        let video = try #require(streams.first { $0.kind == .video })
        let keyframe = try #require(packets.first { $0.streamIndex == video.index && $0.isKeyframe })
        let second = Self.broadcastSecond(
            of: video, sets: SampleBuilder.nalUnits(annexB: keyframe.data).filter { [7, 8].contains(SampleBuilder.h264Type($0)) })
        var fastest = Duration.seconds(Int64.max)
        for _ in 0..<5 {
            let builder = try SampleBuilder(stream: video)
            let started = clock_gettime_nsec_np(CLOCK_THREAD_CPUTIME_ID)
            for packet in second { _ = try builder.sampleBuffers(for: packet) }
            fastest = min(fastest, .nanoseconds(Int64(clock_gettime_nsec_np(CLOCK_THREAD_CPUTIME_ID) - started)))
        }
        print("SampleBuilder: one second of 50 fps broadcast video in \(fastest)")
        #expect(fastest < .milliseconds(15))
    }

    /// One second of 50 fps H.264 at broadcast sizes with the fixture's
    /// parameter sets: a 150 KB keyframe, then 49 frames of 40 KB.
    static func broadcastSecond(of video: DemuxedStream, sets: [Data]) -> [DemuxedPacket] {
        func unit(_ header: UInt8, _ size: Int) -> Data {
            Data([0, 0, 0, 1, header]) + Data((0..<size).map { UInt8($0 % 251 + 1) })
        }
        return (0..<50).map { frame in
            var data = Data()
            if frame == 0 {
                for set in sets { data += Data([0, 0, 0, 1]) + set }
                data += unit(0x65, 150_000)
            } else {
                data += unit(0x41, 40_000)
            }
            let time = CMTime(value: CMTimeValue(frame), timescale: 50)
            return DemuxedPacket(
                streamIndex: video.index, data: data, presentationTime: time, decodeTime: time,
                duration: CMTime(value: 1, timescale: 50), isKeyframe: frame == 0)
        }
    }

    /// The byte-by-byte split `nalUnits` replaced.
    static func referenceUnits(_ bytes: [UInt8]) -> [Data] {
        var starts: [(code: Int, payload: Int)] = []
        var index = 0
        while index + 3 <= bytes.count {
            if bytes[index] == 0, bytes[index + 1] == 0, bytes[index + 2] == 1 {
                starts.append((index > 0 && bytes[index - 1] == 0 ? index - 1 : index, index + 3))
                index += 3
            } else {
                index += 1
            }
        }
        return starts.enumerated().compactMap { offset, start in
            let end = offset + 1 < starts.count ? starts[offset + 1].code : bytes.count
            return end > start.payload ? Data(bytes[start.payload..<end]) : nil
        }
    }

    /// The streams and packets of a fixture, demuxed from memory.
    static func packets(_ file: String) throws -> (streams: [DemuxedStream], packets: [DemuxedPacket]) {
        let data = try Data(contentsOf: FixtureServer.fixtures().appending(path: file))
        let position = Mutex(0)
        let demuxer = try Demuxer(read: { pointer, count in
            position.withLock { offset in
                let taken = min(count, data.count - offset)
                guard taken > 0 else { return 0 }
                data.copyBytes(to: pointer, from: offset..<(offset + taken))
                offset += taken
                return taken
            }
        })
        var packets: [DemuxedPacket] = []
        while let packet = demuxer.nextPacket() { packets.append(packet) }
        return (demuxer.streams, packets)
    }
}
