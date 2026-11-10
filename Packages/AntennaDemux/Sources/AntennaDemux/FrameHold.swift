import CoreImage
import CoreVideo
import Foundation
import QuartzCore

/// The last picture of a channel, drawn above both playback paths while the
/// next channel opens (playback-engine/starting-a-channel-replaces-the-old-one-cleanly).
/// Apple's player shows nothing between two items, so it copies its last
/// picture here. The demuxing engine's layer already sits above Apple's
/// player, so it stays up instead and hides when the hold ends. The engine
/// that shows the next first frame clears the hold.
@MainActor
public final class FrameHold {
    /// Screens put this above the engines' layers.
    public let layer = CALayer()
    private let context = CIContext()
    private var releases: [@MainActor () -> Void] = []

    public init() {
        layer.contentsGravity = .resizeAspect
        layer.isHidden = true
        layer.actions = ["contents": NSNull(), "hidden": NSNull()]
    }

    /// True while a picture is held.
    public var isHolding: Bool { (!layer.isHidden && layer.contents != nil) || !releases.isEmpty }

    /// Holds a picture another layer shows: `release` takes it away when the
    /// hold ends.
    public func keep(until release: @escaping @MainActor () -> Void) {
        releases.append(release)
    }

    /// Holds `pixels` on screen. Nil keeps what is held.
    public func hold(_ pixels: CVPixelBuffer?) {
        guard let pixels else { return }
        let image = CIImage(cvPixelBuffer: pixels)
        guard let picture = context.createCGImage(image, from: image.extent) else { return }
        layer.contents = picture
        layer.isHidden = false
    }

    /// Removes the held picture.
    public func clear() {
        let pending = releases
        releases = []
        pending.forEach { $0() }
        guard layer.contents != nil || !layer.isHidden else { return }
        layer.isHidden = true
        layer.contents = nil
    }
}
