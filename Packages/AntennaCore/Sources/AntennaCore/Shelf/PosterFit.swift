import Foundation

/// The pixels a poster is decoded at for the frame that shows it, so a
/// 2000-pixel poster in a 212-point card is not kept at full size
/// (movies-and-series-browsing/browsing-stays-responsive).
///
/// Every art frame fills its box, so the picture is decoded large enough
/// to cover the box on both sides, with room for the Apple TV focus lift,
/// and never larger than it is.
public struct PosterFit: Sendable, Hashable {
    /// Extra room over the frame, for a focused card that grows on Apple TV.
    public static let headroom = 1.25
    /// Frames are rounded up to this many pixels, so frames of nearly the
    /// same size share a decoded picture.
    public static let step = 64

    /// The frame in pixels, rounded up to `step`, headroom included.
    public let width: Int
    public let height: Int

    /// The frame of `width` by `height` points on a screen of `scale`
    /// pixels per point; nil for an empty frame, which loads nothing yet.
    public init?(width: Double, height: Double, scale: Double) {
        guard width > 0, height > 0, scale > 0 else { return nil }
        self.width = Self.rounded(width * scale * Self.headroom)
        self.height = Self.rounded(height * scale * Self.headroom)
    }

    /// The longest side, in pixels, to decode a picture of
    /// `pictureWidth` by `pictureHeight` at so it covers the frame; nil
    /// when that is the picture's own size or more, so it decodes as it is.
    public func longestSide(pictureWidth: Int, pictureHeight: Int) -> Int? {
        guard pictureWidth > 0, pictureHeight > 0 else { return nil }
        let cover = max(Double(width) / Double(pictureWidth), Double(height) / Double(pictureHeight))
        guard cover < 1 else { return nil }
        let side = Int((Double(max(pictureWidth, pictureHeight)) * cover - 1e-9).rounded(.up))
        return side < max(pictureWidth, pictureHeight) ? side : nil
    }

    /// A name for the frame, for cache keys.
    public var key: String { "\(width)x\(height)" }

    private static func rounded(_ pixels: Double) -> Int {
        let whole = Int(pixels.rounded(.up))
        return (whole + step - 1) / step * step
    }
}
