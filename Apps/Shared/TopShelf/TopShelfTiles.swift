#if os(tvOS)
    import CoreGraphics
    import CoreText
    import Foundation
    import ImageIO
    import UniformTypeIdentifiers

    /// The 908 by 512 px tile images of the Top Shelf (boards `TV-TopShelf`,
    /// `TV-TopShelf-Empty`). The system draws focus, titles and progress
    /// bars, so a tile holds artwork only. Drawing uses Core Graphics and
    /// Core Text and is safe off the main actor.
    enum TopShelfTiles {
        /// What a tile shows.
        enum Art: @unchecked Sendable {
            /// A channel logo centered within 60% of the tile.
            case logo(CGImage)
            /// A channel's initials in place of a missing logo
            /// (design-system/channels-without-a-logo-show-initials).
            case initials(String)
            /// A poster fitted within 60% of the tile.
            case poster(CGImage)
            /// The title in text, in place of missing artwork.
            case text(String)
            /// The add-favorites tile's star.
            case empty
        }

        static let width = 908
        static let height = 512
        static let artShare = 0.6

        /// Board colors: the channel ground, the title ground, text and the star.
        private static let channelGround = rgb(0x26, 0x34, 0x4A)
        private static let titleGround = rgb(0x1E, 0x3A, 0x5F)
        private static let text = rgb(0xF2, 0xF4, 0xF8)
        private static let star = rgb(0xA7, 0xB0, 0xBF)

        /// The tile as PNG data; nil only when Core Graphics cannot make a context.
        static func png(_ art: Art) -> Data? {
            guard
                let context = CGContext(
                    data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return nil }
            let bounds = CGRect(x: 0, y: 0, width: width, height: height)
            switch art {
            case .logo(let image):
                fill(context, bounds, channelGround)
                draw(image, in: context, fitting: bounds.insetBy(share: artShare))
            case .initials(let initials):
                fill(context, bounds, channelGround)
                draw(initials, in: context, bounds: bounds, size: 200, lines: 1)
            case .poster(let image):
                fill(context, bounds, titleGround)
                draw(image, in: context, fitting: bounds.insetBy(share: artShare))
            case .text(let title):
                fill(context, bounds, titleGround)
                draw(title, in: context, bounds: bounds.insetBy(dx: 64, dy: 48), size: 60, lines: 3)
            case .empty:
                fill(context, bounds, channelGround)
                drawStar(in: context, center: CGPoint(x: bounds.midX, y: bounds.midY), size: 200)
            }
            guard let image = context.makeImage() else { return nil }
            let data = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { return nil }
            CGImageDestinationAddImage(destination, image, nil)
            return CGImageDestinationFinalize(destination) ? data as Data : nil
        }

        private static func rgb(_ red: Int, _ green: Int, _ blue: Int) -> CGColor {
            CGColor(srgbRed: CGFloat(red) / 255, green: CGFloat(green) / 255, blue: CGFloat(blue) / 255, alpha: 1)
        }

        private static func fill(_ context: CGContext, _ rect: CGRect, _ color: CGColor) {
            context.setFillColor(color)
            context.fill(rect)
        }

        /// `image` scaled to fit `box`, keeping its aspect, centered.
        private static func draw(_ image: CGImage, in context: CGContext, fitting box: CGRect) {
            guard image.width > 0, image.height > 0 else { return }
            let scale = min(box.width / CGFloat(image.width), box.height / CGFloat(image.height))
            let size = CGSize(width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
            context.interpolationQuality = .high
            context.draw(
                image, in: CGRect(x: box.midX - size.width / 2, y: box.midY - size.height / 2, width: size.width, height: size.height))
        }

        /// Bold text centered in `bounds`, at most `lines` lines.
        private static func draw(_ string: String, in context: CGContext, bounds: CGRect, size: CGFloat, lines: Int) {
            let font =
                CTFontCreateUIFontForLanguage(.emphasizedSystem, size, nil) ?? CTFontCreateWithName("Helvetica-Bold" as CFString, size, nil)
            var alignment = CTTextAlignment.center
            let style = withUnsafePointer(to: &alignment) { pointer in
                var setting = CTParagraphStyleSetting(spec: .alignment, valueSize: MemoryLayout<CTTextAlignment>.size, value: pointer)
                return CTParagraphStyleCreate(&setting, 1)
            }
            let attributes: [NSAttributedString.Key: Any] = [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): text,
                NSAttributedString.Key(kCTParagraphStyleAttributeName as String): style,
            ]
            let framesetter = CTFramesetterCreateWithAttributedString(NSAttributedString(string: string, attributes: attributes))
            // A box tall enough for `lines` lines lays out no more than that.
            let lineHeight = CTFontGetAscent(font) + CTFontGetDescent(font) + CTFontGetLeading(font)
            let limit = CGSize(width: bounds.width, height: min(bounds.height, lineHeight * CGFloat(lines) + 1))
            let fitted = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRange(location: 0, length: 0), nil, limit, nil)
            let height = min(ceil(fitted.height), limit.height)
            let box = CGRect(x: bounds.minX, y: bounds.midY - height / 2, width: bounds.width, height: height)
            let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0), CGPath(rect: box, transform: nil), nil)
            CTFrameDraw(frame, context)
        }

        /// A five-point star outline, `size` across.
        private static func drawStar(in context: CGContext, center: CGPoint, size: CGFloat) {
            let outer = size / 2
            let inner = outer * 0.4
            let path = CGMutablePath()
            for point in 0..<10 {
                let radius = point.isMultiple(of: 2) ? outer : inner
                let angle = CGFloat.pi / 2 + CGFloat(point) * .pi / 5
                let vertex = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
                if point == 0 { path.move(to: vertex) } else { path.addLine(to: vertex) }
            }
            path.closeSubpath()
            context.setStrokeColor(star)
            context.setLineWidth(12)
            context.setLineJoin(.round)
            context.addPath(path)
            context.strokePath()
        }
    }

    extension CGRect {
        /// The rect scaled by `share` about its center.
        fileprivate func insetBy(share: CGFloat) -> CGRect {
            insetBy(dx: width * (1 - share) / 2, dy: height * (1 - share) / 2)
        }
    }
#endif
