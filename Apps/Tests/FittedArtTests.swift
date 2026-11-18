import CoreGraphics
import SwiftUI
import Testing

@testable import Antenna

/// Banner and title page pictures keep their proportions: a black square in
/// the picture stays square on screen, whatever the frame's shape.
@MainActor @Suite struct FittedArtTests {
    private func render(_ image: CGImage?, width: CGFloat, height: CGFloat) throws -> CGImage {
        let renderer = ImageRenderer(
            content: FittedArt(image: image, background: .white).frame(width: width, height: height))
        renderer.scale = 1
        return try #require(renderer.cgImage)
    }

    /// The gray level of every pixel, rows from the top.
    private func grays(_ image: CGImage) throws -> [[UInt8]] {
        var bytes = [UInt8](repeating: 0, count: image.width * image.height)
        let context = try #require(
            CGContext(
                data: &bytes, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width,
                space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return (0..<image.height).map { row in Array(bytes[(row * image.width)..<((row + 1) * image.width)]) }
    }

    /// The width and height of the dark pixels inside `area`.
    private func darkBox(_ grays: [[UInt8]], in area: CGRect) -> CGSize {
        var xs: [Int] = []
        var ys: [Int] = []
        for y in Int(area.minY)..<Int(area.maxY) {
            for x in Int(area.minX)..<Int(area.maxX) where grays[y][x] < 60 {
                xs.append(x)
                ys.append(y)
            }
        }
        guard let left = xs.min(), let right = xs.max(), let top = ys.min(), let bottom = ys.max() else { return .zero }
        return CGSize(width: right - left + 1, height: bottom - top + 1)
    }

    @Test("movies-and-series-browsing/new-titles-up-front a poster sent as the backdrop shows whole and square in a wide banner")
    func posterStaysSquare() throws {
        let image = try render(PreviewArt.tallSquare, width: 600, height: 200)
        // The sharp poster: 140 tall, 93 wide, 24 from the right, 20 from the bottom.
        let box = darkBox(try grays(image), in: CGRect(x: 484, y: 42, width: 90, height: 136))
        // The square is 100 of the poster's 300, so 140 / 3 on screen.
        #expect(abs(box.width - 140.0 / 3) <= 2, "square \(box)")
        #expect(abs(box.height - 140.0 / 3) <= 2, "square \(box)")
    }

    @Test("movies-and-series-browsing/new-titles-up-front a backdrop fills the banner without stretching")
    func backdropStaysSquare() throws {
        let image = try render(PreviewArt.wideSquare, width: 600, height: 300)
        // Filling 600 by 300 scales 320 by 180 by 1.875 and cuts the sides.
        let box = darkBox(try grays(image), in: CGRect(x: 0, y: 0, width: 600, height: 300))
        #expect(abs(box.width - 90 * 1.875) <= 2, "square \(box)")
        #expect(abs(box.height - 90 * 1.875) <= 2, "square \(box)")
    }

    @Test("title-detail-and-episode-picker/what-the-title-is-about a poster fills a frame taller than wide without stretching")
    func posterFillsTallFrame() throws {
        let image = try render(PreviewArt.tallSquare, width: 300, height: 400)
        // Filling 300 by 400 scales 200 by 300 by 1.5 and cuts the sides.
        let box = darkBox(try grays(image), in: CGRect(x: 0, y: 0, width: 300, height: 400))
        #expect(abs(box.width - 150) <= 2, "square \(box)")
        #expect(abs(box.height - 150) <= 2, "square \(box)")
    }
}
