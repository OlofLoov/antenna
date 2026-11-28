import AntennaCore
import CoreGraphics
import Foundation
import ImageIO

/// A decoded poster. Immutable once made, so it can cross actors.
final class Poster: @unchecked Sendable {
    let image: CGImage

    /// Decodes `data` at full size, or with `fit` scaled down to cover that
    /// frame. A picture already that small or smaller decodes as it is.
    init?(data: Data, fitting fit: PosterFit? = nil) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        if let fit, let side = Self.pixels(of: source).flatMap({ fit.longestSide(pictureWidth: $0.width, pictureHeight: $0.height) }) {
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: side,
                kCGImageSourceShouldCacheImmediately: true,
            ]
            guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
            self.image = image
            return
        }
        guard let image = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
        else { return nil }
        self.image = image
    }

    /// The picture's size in pixels as stored, read from its header.
    private static func pixels(of source: CGImageSource) -> (width: Int, height: Int)? {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? Int, let height = properties[kCGImagePropertyPixelHeight] as? Int
        else { return nil }
        return (width, height)
    }

    init(image: CGImage) {
        self.image = image
    }

    /// The decoded size in bytes, what it costs the memory limit.
    var cost: Int { image.bytesPerRow * image.height }
}
