import CoreGraphics
import SwiftUI
import Testing

@testable import Antenna

/// The darkening behind banner and title page copy covers the whole picture
/// and changes smoothly, with no edge where a flat block used to stop, and
/// stays under the copy in a right-to-left language.
@MainActor @Suite struct HeroScrimTests {
    /// The view rendered at 1x as RGBA bytes, row by row from the top.
    private struct Pixels {
        let width: Int
        let height: Int
        let bytes: [UInt8]

        @MainActor init(_ view: some View, width: Int, height: Int, direction: LayoutDirection = .leftToRight) throws {
            let renderer = ImageRenderer(
                content: view.frame(width: CGFloat(width), height: CGFloat(height)).environment(\.layoutDirection, direction))
            renderer.scale = 1
            let image = try #require(renderer.cgImage)
            var bytes = [UInt8](repeating: 0, count: width * height * 4)
            let context = try #require(
                CGContext(
                    data: &bytes, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            self.width = width
            self.height = height
            self.bytes = bytes
        }

        /// The brightness, 0 to 255, of the pixel at `x`, `y` from the top left.
        func brightness(x: Int, y: Int) -> Int {
            let offset = (y * width + x) * 4
            return (Int(bytes[offset]) + Int(bytes[offset + 1]) + Int(bytes[offset + 2])) / 3
        }

        /// The largest change in brightness between neighbors along row `y`,
        /// leaving out `inset` columns at each end.
        func largestStep(row y: Int, inset: Int = 0) -> Int {
            (inset + 1..<width - inset).map { abs(brightness(x: $0, y: y) - brightness(x: $0 - 1, y: y)) }.max() ?? 0
        }

        /// The largest change in brightness between neighbors down column `x`,
        /// from `top` to `bottom`.
        func largestStep(column x: Int, from top: Int, to bottom: Int) -> Int {
            (top + 1..<bottom).map { abs(brightness(x: x, y: $0) - brightness(x: x, y: $0 - 1)) }.max() ?? 0
        }
    }

    @Test("design-system/the-scrim-blends-into-the-art: the scrim darkens from the leading edge with no step")
    func scrimHasNoStep() throws {
        let pixels = try Pixels(
            ZStack {
                Color.white; HeroScrim(copyEnd: 0.5)
            }, width: 1920, height: 4)
        #expect(pixels.largestStep(row: 2) <= 2)
        #expect(pixels.brightness(x: 0, y: 2) < 60, "darkest at the leading edge")
        #expect(pixels.brightness(x: 940, y: 2) < 100, "still dark where the copy ends")
        #expect(pixels.brightness(x: 1919, y: 2) > 245, "clear at the trailing edge")
    }

    @Test("design-system/the-scrim-blends-into-the-art: in Arabic the dark side is at the right")
    func scrimMirrors() throws {
        let pixels = try Pixels(
            ZStack {
                Color.white; HeroScrim(copyEnd: 0.5)
            }, width: 1920, height: 4, direction: .rightToLeft)
        #expect(pixels.brightness(x: 1919, y: 2) < 60)
        #expect(pixels.brightness(x: 0, y: 2) > 245)
    }

    @Test("design-system/the-scrim-blends-into-the-art: the iPhone band fades into the art above it")
    func footHasNoStep() throws {
        let view = ZStack(alignment: .bottom) {
            Color.white
            Color.clear.frame(height: 200).frame(maxWidth: .infinity).background(HeroFootScrim(fade: 56))
        }
        let pixels = try Pixels(view, width: 4, height: 520)
        #expect(pixels.largestStep(column: 2, from: 0, to: 520) <= 8)
        #expect(pixels.brightness(x: 2, y: 200) > 245, "clear above the fade")
        #expect(pixels.brightness(x: 2, y: 500) < 60, "dark behind the copy")
    }

    /// Row 100 of the Apple TV banner is above the copy, so only the art,
    /// with no picture loaded the placeholder color, and the scrim are there.
    @Test("design-system/the-scrim-blends-into-the-art: the Apple TV banner has no step across the picture")
    func televisionBannerHasNoStep() throws {
        for direction in [LayoutDirection.leftToRight, .rightToLeft] {
            let banner = ShelfBanner.Television { EmptyView() }
                .environment(\.shelfBanner, .preview())
                .environment(\.shelfMetrics, .tv)
            let pixels = try Pixels(banner, width: 1920, height: 640, direction: direction)
            #expect(pixels.largestStep(row: 100) <= 2, "\(direction)")
            let leading = direction == .leftToRight ? 0 : 1919
            let trailing = direction == .leftToRight ? 1919 : 0
            #expect(pixels.brightness(x: leading, y: 100) < pixels.brightness(x: trailing, y: 100), "\(direction)")
        }
    }

    #if os(iOS) || os(macOS)
        /// Row 10 of the iPad banner is above the copy. The banner's rounded
        /// corners clip both ends of the row, so the 40 columns at each end,
        /// past the 26 pt continuous corner, are left out.
        @Test("design-system/the-scrim-blends-into-the-art: the iPad banner has no step across the picture")
        func padBannerHasNoStep() throws {
            for direction in [LayoutDirection.leftToRight, .rightToLeft] {
                let banner = ShelfBanner.Pad()
                    .environment(\.shelfBanner, .preview())
                    .environment(\.shelfMetrics, .pad)
                let pixels = try Pixels(banner, width: 914, height: 330, direction: direction)
                #expect(pixels.largestStep(row: 10, inset: 40) <= 2, "\(direction)")
            }
        }

        /// Column 350 of the iPhone banner card is right of the copy and the
        /// buttons, so only the art and the band are there. Rows within the
        /// 26 pt rounded corner at the top and the foot are left out.
        @Test("design-system/the-scrim-blends-into-the-art: the iPhone banner has no line across the picture")
        func phoneBannerHasNoLine() throws {
            let banner = ShelfBanner.Phone()
                .environment(\.shelfBanner, .preview())
            let pixels = try Pixels(banner, width: 358, height: 480)
            #expect(pixels.largestStep(column: 350, from: 30, to: 450) <= 4)
        }

        /// Owner-found: the band behind the old header darkened the top of
        /// every picture. The header is now in the top bar above the card, so
        /// the top of the card is the art alone, with no picture loaded the
        /// placeholder color.
        @Test("design-system/the-scrim-blends-into-the-art: the top of the iPhone banner is not darkened")
        func phoneBannerTopIsTheArt() throws {
            let banner = ShelfBanner.Phone()
                .environment(\.shelfBanner, .preview())
            let pixels = try Pixels(banner, width: 358, height: 480)
            let art = try Pixels(TitlePage.placeholder, width: 4, height: 4).brightness(x: 2, y: 2)
            // The band under the copy fades in from about 110 pt down.
            for y in [20, 50, 80] {
                #expect(abs(pixels.brightness(x: 179, y: y) - art) <= 2, "row \(y)")
            }
        }
    #endif
}
