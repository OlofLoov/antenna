import CoreGraphics
import SwiftUI
import Testing

@testable import Antenna

/// Artwork that fills its frame draws nothing outside it, whatever the
/// picture's shape. The banner, the title page, posters and cards use it.
@MainActor @Suite struct FilledArtTests {
    /// A 300 by 100 frame between two white bands of 100, rendered at 1x.
    private func render(_ image: CGImage?) throws -> CGImage {
        let view = VStack(spacing: 0) {
            Color.white.frame(height: 100)
            FilledArt(image: image, background: .black)
                .frame(width: 300, height: 100)
            Color.white.frame(height: 100)
        }
        .frame(width: 300)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        return try #require(renderer.cgImage)
    }

    /// The red, green and blue of the pixel at `x`, `y` from the top.
    private func pixel(_ image: CGImage, x: Int, y: Int) throws -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 4)
        let context = try #require(
            CGContext(
                data: &bytes, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: -x, y: y - image.height + 1, width: image.width, height: image.height))
        return Array(bytes[0..<3])
    }

    @Test("movies-and-series-browsing/new-titles-up-front: a tall poster stays inside a wide banner")
    func tallPosterStaysInside() throws {
        let image = try render(PreviewArt.tallPoster)
        #expect(image.height == 300)
        #expect(try pixel(image, x: 150, y: 20) == [255, 255, 255])
        #expect(try pixel(image, x: 150, y: 280) == [255, 255, 255])
        #expect(try pixel(image, x: 150, y: 150) != [255, 255, 255])
    }

    @Test("movies-and-series-browsing/new-titles-up-front: a wide backdrop fills the frame and stays inside it")
    func wideBackdropFills() throws {
        let image = try render(PreviewArt.backdrop)
        #expect(image.height == 300)
        #expect(try pixel(image, x: 150, y: 99) == [255, 255, 255])
        #expect(try pixel(image, x: 2, y: 102) != [0, 0, 0])
        #expect(try pixel(image, x: 297, y: 197) != [0, 0, 0])
        #expect(try pixel(image, x: 150, y: 201) == [255, 255, 255])
    }
}
