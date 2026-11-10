import AntennaTestSupport
import CoreMedia
import CoreVideo
import Foundation
import Testing

@testable import AntennaDemux

/// The GPU deinterlacer: no combing on moving edges, full detail where the
/// picture is still, two pictures per frame.
@Suite struct DeinterlacerTests {
    static let width = 320
    static let height = 240

    @Test("playback-engine/interlaced-broadcasts-are-deinterlaced moving edges show no combing")
    func movingEdgesDoNotComb() throws {
        let deinterlacer = try Deinterlacer()
        // The bar sits 40 pixels further right in the bottom field: the
        // fields were caught at different moments.
        let before = try Self.frame { x, y in Self.bar(x, from: y.isMultiple(of: 2) ? 60 : 100) }
        let moving = try Self.frame { x, y in Self.bar(x, from: y.isMultiple(of: 2) ? 100 : 140) }
        _ = try deinterlacer.pictures(of: before, at: .zero, duration: Self.frameTime, topFirst: true)
        let pictures = try deinterlacer.pictures(of: moving, at: Self.frameTime, duration: Self.frameTime, topFirst: true)
        let woven = Self.combing(moving)
        let first = Self.combing(pictures[0].pixels)
        #expect(woven > 20)
        #expect(first < woven / 10)
    }

    @Test("playback-engine/interlaced-broadcasts-are-deinterlaced still pictures keep both fields' detail")
    func stillKeepsDetail() throws {
        let deinterlacer = try Deinterlacer()
        // Fine stripes one line high: interpolating would lose them.
        let still = try Self.frame { _, y in y.isMultiple(of: 2) ? 200 : 40 }
        _ = try deinterlacer.pictures(of: still, at: .zero, duration: Self.frameTime, topFirst: true)
        let pictures = try deinterlacer.pictures(of: still, at: Self.frameTime, duration: Self.frameTime, topFirst: true)
        #expect(Self.luma(pictures[0].pixels) == Self.luma(still))
        #expect(Self.luma(pictures[1].pixels) == Self.luma(still))
    }

    @Test("playback-engine/interlaced-broadcasts-are-deinterlaced each frame gives two pictures at the field rate")
    func twoPicturesPerFrame() throws {
        let deinterlacer = try Deinterlacer()
        let frame = try Self.frame { x, _ in UInt8(x % 256) }
        let pictures = try deinterlacer.pictures(of: frame, at: CMTime(value: 10, timescale: 25), duration: Self.frameTime, topFirst: true)
        #expect(pictures.count == 2)
        #expect(pictures.map(\.time) == [CMTime(value: 10, timescale: 25), CMTime(value: 21, timescale: 50)])
        #expect(pictures.allSatisfy { $0.duration == CMTime(value: 1, timescale: 50) })
    }

    @Test("playback-engine/interlaced-broadcasts-are-deinterlaced a 1080i broadcast is shown without combing")
    func broadcastDoesNotComb() throws {
        let units = try firstKeyframeUnits("interlaced-1080i.ts")
        let sps = try #require(units.first { SampleBuilder.h264Type($0) == 7 })
        let pps = try #require(units.first { SampleBuilder.h264Type($0) == 8 })
        let format = try SampleBuilder.h264Format(sps: sps, pps: pps)
        let packet = DemuxedPacket(
            streamIndex: 0, data: Data([0, 0, 0, 1]) + units.reduce(Data()) { $0 + Data([0, 0, 0, 1]) + $1 },
            presentationTime: .zero, decodeTime: .zero, duration: Self.frameTime, isKeyframe: true)
        let payload = units.filter { ![7, 8, 9].contains(SampleBuilder.h264Type($0) ?? 0) }
        let sample = try SampleBuilder.videoBuffer(SampleBuilder.lengthPrefixed(payload), format: format, packet: packet)
        let decoder = try VideoDecoder(format: format)
        var decoded = decoder.decode(sample)
        decoded += decoder.flush()
        let frame = try #require(decoded.first)
        let deinterlacer = try Deinterlacer()
        let pictures = try deinterlacer.pictures(of: frame.pixels, at: frame.time, duration: Self.frameTime, topFirst: true)
        #expect(CVPixelBufferGetWidth(pictures[0].pixels) == 1920 && CVPixelBufferGetHeight(pictures[0].pixels) == 1080)
        #expect(Self.combing(pictures[0].pixels) < Self.combing(frame.pixels) / 2)
    }

    // MARK: Pictures

    static let frameTime = CMTime(value: 1, timescale: 25)

    static func bar(_ x: Int, from start: Int) -> UInt8 {
        (start..<(start + 40)).contains(x) ? 235 : 16
    }

    /// An NV12 frame whose luma is `value(x, y)` and chroma neutral.
    static func frame(_ value: (Int, Int) -> UInt8) throws -> CVPixelBuffer {
        let attributes: [CFString: Any] = [
            kCVPixelBufferMetalCompatibilityKey: true, kCVPixelBufferIOSurfacePropertiesKey: [String: Any](),
        ]
        var pixels: CVPixelBuffer?
        CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, attributes as CFDictionary, &pixels)
        let frame = try #require(pixels)
        CVPixelBufferLockBaseAddress(frame, [])
        defer { CVPixelBufferUnlockBaseAddress(frame, []) }
        let luma = try #require(CVPixelBufferGetBaseAddressOfPlane(frame, 0)?.assumingMemoryBound(to: UInt8.self))
        let chroma = try #require(CVPixelBufferGetBaseAddressOfPlane(frame, 1)?.assumingMemoryBound(to: UInt8.self))
        let lumaStride = CVPixelBufferGetBytesPerRowOfPlane(frame, 0)
        let chromaStride = CVPixelBufferGetBytesPerRowOfPlane(frame, 1)
        for y in 0..<height {
            for x in 0..<width { luma[y * lumaStride + x] = value(x, y) }
        }
        for y in 0..<(height / 2) {
            for x in 0..<width { chroma[y * chromaStride + x] = 128 }
        }
        return frame
    }

    /// The luma plane, row by row, without padding.
    static func luma(_ pixels: CVPixelBuffer) -> [UInt8] {
        CVPixelBufferLockBaseAddress(pixels, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixels, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddressOfPlane(pixels, 0)?.assumingMemoryBound(to: UInt8.self) else { return [] }
        let stride = CVPixelBufferGetBytesPerRowOfPlane(pixels, 0)
        let width = CVPixelBufferGetWidthOfPlane(pixels, 0)
        return (0..<CVPixelBufferGetHeightOfPlane(pixels, 0)).flatMap { row in
            Array(UnsafeBufferPointer(start: base + row * stride, count: width))
        }
    }

    /// How much the picture combs: the mean of |2·L(y) - L(y-1) - L(y+1)|
    /// over its luma. Woven fields of a moving picture score high.
    static func combing(_ pixels: CVPixelBuffer) -> Double {
        let width = CVPixelBufferGetWidthOfPlane(pixels, 0)
        let height = CVPixelBufferGetHeightOfPlane(pixels, 0)
        let luma = Self.luma(pixels)
        var total = 0
        var count = 0
        for y in 1..<(height - 1) {
            for x in Swift.stride(from: 0, to: width, by: 4) {
                let middle = Int(luma[y * width + x])
                total += abs(2 * middle - Int(luma[(y - 1) * width + x]) - Int(luma[(y + 1) * width + x]))
                count += 1
            }
        }
        return Double(total) / Double(max(count, 1))
    }
}
