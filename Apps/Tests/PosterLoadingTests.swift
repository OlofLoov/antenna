import CoreGraphics
import SwiftUI
import Testing

@testable import Antenna

#if os(iOS)
    /// What a poster card draws once it is laid out, before any load
    /// finishes: the poster when it is in memory, else the quiet placeholder.
    @MainActor @Suite struct PosterLoadingTests {
        /// A red poster, and a loader whose loads never finish in the test.
        private static let red = PreviewArt.solid(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))

        private func loader(keeps: Bool) -> ShelfView.PosterLoader {
            let poster = keeps ? Self.red.map(Poster.init(image:)) : nil
            return ShelfView.PosterLoader(
                load: { _, _ in
                    try? await Task.sleep(for: .seconds(60))
                    return nil
                },
                kept: { _, _ in poster })
        }

        /// Shows one 120 by 180 poster card on the ground in a window, lays
        /// it out once and draws it, and returns the pixel at its center.
        private func firstFrame(keeps: Bool) throws -> [UInt8] {
            let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
            let window = UIWindow(windowScene: scene)
            defer { window.isHidden = true }
            window.rootViewController = UIHostingController(
                rootView: ShelfView.PosterArt(name: "Quiet Engines", url: PreviewArt.address)
                    .frame(width: 120, height: 180)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(Palette.ground)
                    .environment(\.posterLoader, loader(keeps: keeps))
                    .ignoresSafeArea())
            window.makeKeyAndVisible()
            window.layoutIfNeeded()
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            let image = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            let picture = try #require(image.cgImage)
            var bytes = [UInt8](repeating: 0, count: 4)
            let context = try #require(
                CGContext(
                    data: &bytes, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(picture, in: CGRect(x: -60, y: 90 - picture.height + 1, width: picture.width, height: picture.height))
            return Array(bytes[0..<3])
        }

        @Test("movies-and-series-browsing/rows-in-a-predictable-order a poster already in memory draws without waiting for a load")
        func keptPosterDrawsAtOnce() throws {
            let pixel = try firstFrame(keeps: true)
            #expect(pixel[0] > 240 && pixel[1] < 20 && pixel[2] < 20, "the red poster, not the placeholder; got \(pixel)")
        }

        @Test("movies-and-series-browsing/rows-in-a-predictable-order a poster not in memory shows the quiet placeholder")
        func missingPosterShowsThePlaceholder() throws {
            let pixel = try firstFrame(keeps: false)
            // Surface 0.06 over the ground is about 26, 28, 33: darker than the #26344A name tile.
            #expect(pixel.allSatisfy { $0 < 40 }, "the placeholder over the ground; got \(pixel)")
            #expect(pixel[0] < 100, "not the red poster")
        }
    }
#endif
