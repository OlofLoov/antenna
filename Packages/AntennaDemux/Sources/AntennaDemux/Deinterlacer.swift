import CoreMedia
import CoreVideo
import Foundation
import Metal

/// Turns interlaced NV12 frames into progressive pictures at the field
/// rate on the GPU: each frame gives two pictures, one per field
/// (playback-engine/interlaced-broadcasts-are-deinterlaced).
///
/// Motion-adaptive, in the manner of yadif: each picture keeps one field's
/// lines and fills in the others. Where the other field matches the
/// previous frame the picture is still, and the other field's line is used
/// as it is, so still detail keeps full resolution. Where it moved, the
/// line is interpolated from the kept field above and below it, so moving
/// edges show no combing. Between the two the result is blended.
/// One thread at a time.
final class Deinterlacer: @unchecked Sendable {
    enum DeinterlaceError: Error, Equatable {
        case noGPU
        case cannotCompile(String)
        case failed
    }

    private let device: any MTLDevice
    private let queue: any MTLCommandQueue
    private let pipeline: any MTLComputePipelineState
    private var textures: CVMetalTextureCache?
    private var previous: CVPixelBuffer?
    /// Below this difference (out of 1) between frames a pixel counts as still.
    static let stillThreshold: Float = 6.0 / 255

    init() throws {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
            throw DeinterlaceError.noGPU
        }
        do {
            let library = try device.makeLibrary(source: Self.shader, options: nil)
            guard let function = library.makeFunction(name: "deinterlace") else { throw DeinterlaceError.cannotCompile("no function") }
            pipeline = try device.makeComputePipelineState(function: function)
        } catch let error as DeinterlaceError {
            throw error
        } catch {
            throw DeinterlaceError.cannotCompile(error.localizedDescription)
        }
        self.device = device
        self.queue = queue
        CVMetalTextureCacheCreate(nil, nil, device, nil, &textures)
    }

    /// The two progressive pictures of an interlaced `frame` shown at `time`
    /// for `duration`: the first field at `time`, the second half a frame
    /// later. `topFirst` says which field comes first.
    func pictures(of frame: CVPixelBuffer, at time: CMTime, duration: CMTime, topFirst: Bool) throws -> [DecodedPicture] {
        let earlier = previous ?? frame
        let still = previous == nil ? 0 : Self.stillThreshold
        previous = frame
        let half = CMTimeMultiplyByRatio(duration.isValid ? duration : CMTime(value: 1, timescale: 25), multiplier: 1, divisor: 2)
        var out: [DecodedPicture] = []
        for (keepTop, start) in zip(topFirst ? [true, false] : [false, true], [time, CMTimeAdd(time, half)]) {
            let picture = try render(frame, previous: earlier, keepTop: keepTop, still: still)
            out.append(DecodedPicture(pixels: picture, time: start, duration: half))
        }
        return out
    }

    /// Forgets the previous frame, as after a channel change.
    func reset() {
        previous = nil
    }

    private func render(_ frame: CVPixelBuffer, previous: CVPixelBuffer, keepTop: Bool, still: Float) throws -> CVPixelBuffer {
        let width = CVPixelBufferGetWidth(frame)
        let height = CVPixelBufferGetHeight(frame)
        let attributes: [CFString: Any] = [
            kCVPixelBufferMetalCompatibilityKey: true, kCVPixelBufferIOSurfacePropertiesKey: [String: Any](),
        ]
        var output: CVPixelBuffer?
        guard
            CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, attributes as CFDictionary, &output)
                == kCVReturnSuccess, let output, let buffer = queue.makeCommandBuffer()
        else { throw DeinterlaceError.failed }
        for (plane, format) in [(0, MTLPixelFormat.r8Unorm), (1, .rg8Unorm)] {
            guard let current = texture(frame, plane: plane, format: format),
                let earlier = texture(previous, plane: plane, format: format),
                let target = texture(output, plane: plane, format: format),
                let encoder = buffer.makeComputeCommandEncoder()
            else { throw DeinterlaceError.failed }
            encoder.setComputePipelineState(pipeline)
            encoder.setTexture(current, index: 0)
            encoder.setTexture(earlier, index: 1)
            encoder.setTexture(target, index: 2)
            var keep: UInt32 = keepTop ? 0 : 1
            var threshold = still
            encoder.setBytes(&keep, length: MemoryLayout<UInt32>.size, index: 0)
            encoder.setBytes(&threshold, length: MemoryLayout<Float>.size, index: 1)
            let size = MTLSize(width: target.width, height: target.height, depth: 1)
            let group = MTLSize(width: 16, height: 16, depth: 1)
            encoder.dispatchThreads(size, threadsPerThreadgroup: group)
            encoder.endEncoding()
        }
        buffer.commit()
        buffer.waitUntilCompleted()
        guard buffer.status == .completed else { throw DeinterlaceError.failed }
        return output
    }

    private func texture(_ pixels: CVPixelBuffer, plane: Int, format: MTLPixelFormat) -> (any MTLTexture)? {
        guard let textures else { return nil }
        var texture: CVMetalTexture?
        let width = CVPixelBufferGetWidthOfPlane(pixels, plane)
        let height = CVPixelBufferGetHeightOfPlane(pixels, plane)
        CVMetalTextureCacheCreateTextureFromImage(nil, textures, pixels, nil, format, width, height, plane, &texture)
        return texture.flatMap(CVMetalTextureGetTexture)
    }

    /// One thread per output pixel. Lines of the kept parity are copied;
    /// the others are filled in by how much the picture moved there.
    static let shader = """
        #include <metal_stdlib>
        using namespace metal;

        kernel void deinterlace(texture2d<float, access::read> current [[texture(0)]],
                                texture2d<float, access::read> previous [[texture(1)]],
                                texture2d<float, access::write> output [[texture(2)]],
                                constant uint &keep [[buffer(0)]],
                                constant float &still [[buffer(1)]],
                                uint2 at [[thread_position_in_grid]]) {
            uint width = output.get_width();
            uint height = output.get_height();
            if (at.x >= width || at.y >= height) return;
            if ((at.y & 1u) == keep) {
                output.write(current.read(at), at);
                return;
            }
            uint up = at.y == 0 ? 1 : at.y - 1;
            uint down = at.y + 1 >= height ? at.y - 1 : at.y + 1;
            float4 above = current.read(uint2(at.x, up));
            float4 below = current.read(uint2(at.x, down));
            float4 spatial = (above + below) * 0.5;
            float4 other = current.read(at);
            float4 change = max(abs(other - previous.read(at)),
                                max(abs(above - previous.read(uint2(at.x, up))),
                                    abs(below - previous.read(uint2(at.x, down)))));
            float motion = max(max(change.x, change.y), max(change.z, change.w));
            if (still <= 0.0 || motion >= still * 4.0) {
                output.write(spatial, at);
                return;
            }
            float4 low = min(above, below) - still;
            float4 high = max(above, below) + still;
            float4 temporal = motion < still ? other : clamp(other, low, high);
            float blend = clamp((motion - still) / (still * 3.0), 0.0, 1.0);
            output.write(mix(temporal, spatial, blend), at);
        }
        """
}
