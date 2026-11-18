import Foundation

/// How a banner or title page picture sits in its frame, chosen from the
/// decoded picture's shape rather than the field it came in, since many
/// providers send the poster as the backdrop
/// (movies-and-series-browsing/new-titles-up-front,
/// title-detail-and-episode-picker/what-the-title-is-about). Neither way
/// stretches the picture.
public enum ArtFit: Sendable, Hashable {
    /// Scaled to cover the frame at its own proportions and cut at the edges.
    case fill
    /// Shown whole at its own proportions at the frame's bottom right, over a
    /// blurred copy that fills the frame.
    case whole

    /// A frame counts as wide when it is more than this many times as wide as tall.
    public static let wideFrame = 1.2

    /// `.whole` when the frame is wide and filling it would hide more than
    /// half of the picture, `.fill` otherwise. A frame or picture with no
    /// area fills.
    public static func choose(pictureWidth: Double, pictureHeight: Double, frameWidth: Double, frameHeight: Double) -> ArtFit {
        guard pictureWidth > 0, pictureHeight > 0, frameWidth > 0, frameHeight > 0 else { return .fill }
        let frame = frameWidth / frameHeight
        guard frame > wideFrame else { return .fill }
        let picture = pictureWidth / pictureHeight
        // Filling keeps the share min(picture, frame) / max(picture, frame) of the picture.
        let kept = min(picture, frame) / max(picture, frame)
        return kept < 0.5 ? .whole : .fill
    }
}
