import XCTest

/// A screenshot of the app as pixels, for tests that check what is drawn
/// inside an element's frame: a circle cut by its container, or one view
/// drawn over another. Points are the frames' points.
struct ScreenPixels {
    let width: Int
    let height: Int
    /// Pixels per point.
    let scale: CGFloat
    private let bytes: [UInt8]

    /// One pixel's red, green and blue.
    struct Color: Equatable {
        let red: Int
        let green: Int
        let blue: Int

        /// The app's ground color, #0B0E13.
        static let ground = Color(red: 0x0B, green: 0x0E, blue: 0x13)

        /// The largest difference in any channel.
        func distance(to other: Color) -> Int {
            max(abs(red - other.red), abs(green - other.green), abs(blue - other.blue))
        }
    }

    @MainActor init(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) throws {
        let screenshot = app.screenshot()
        let image = try XCTUnwrap(screenshot.image.cgImage, file: file, line: line)
        width = image.width
        height = image.height
        scale = CGFloat(image.width) / max(1, app.frame.width)
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let context = try XCTUnwrap(
            CGContext(
                data: &bytes, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
            file: file, line: line)
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        self.bytes = bytes
    }

    /// The pixel at `point`, in points from the top left; nil off the screen.
    func color(at point: CGPoint) -> Color? {
        let x = Int(point.x * scale)
        let y = Int(point.y * scale)
        guard x >= 0, y >= 0, x < width, y < height else { return nil }
        let offset = (y * width + x) * 4
        return Color(red: Int(bytes[offset]), green: Int(bytes[offset + 1]), blue: Int(bytes[offset + 2]))
    }

    /// Every pixel in `rect`, in points, one per pixel.
    func colors(in rect: CGRect) -> [Color] {
        let pixels = CGRect(x: rect.minX * scale, y: rect.minY * scale, width: rect.width * scale, height: rect.height * scale)
            .intersection(CGRect(x: 0, y: 0, width: width, height: height))
        guard !pixels.isNull, pixels.width >= 1, pixels.height >= 1 else { return [] }
        var colors: [Color] = []
        for y in Int(pixels.minY)..<Int(pixels.maxY) {
            for x in Int(pixels.minX)..<Int(pixels.maxX) {
                let offset = (y * width + x) * 4
                colors.append(Color(red: Int(bytes[offset]), green: Int(bytes[offset + 1]), blue: Int(bytes[offset + 2])))
            }
        }
        return colors
    }

    /// The share, 0 to 1, of the pixels in `rect` within `tolerance` of `color`.
    func share(of color: Color, in rect: CGRect, tolerance: Int = 12) -> Double {
        let colors = colors(in: rect)
        guard !colors.isEmpty else { return 0 }
        return Double(colors.filter { $0.distance(to: color) <= tolerance }.count) / Double(colors.count)
    }
}
