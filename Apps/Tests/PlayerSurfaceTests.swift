import AVFoundation
import Testing

@testable import Antenna

#if os(iOS)
    import UIKit

    /// The view every engine draws into.
    @MainActor
    struct PlayerSurfaceTests {
        @Test("player-controls-and-playback-errors/black-around-the-picture the bars around a picture are pure black")
        func barsAreBlack() {
            let view = PlayerSurfaceView.PlayerLayerView()
            #expect(view.backgroundColor == .black)
            #expect(view.layer.backgroundColor == UIColor.black.cgColor)
            #expect(view.playerLayer?.videoGravity == .resizeAspect, "the picture keeps its shape and leaves bars")
        }

        /// Picture in Picture adds a stand-in view next to the picture's
        /// view. It must land in the surface's own container, never in
        /// SwiftUI's hosting view.
        @Test func thePictureSitsInItsOwnContainer() {
            let container = PlayerSurfaceView.Container(frame: CGRect(x: 0, y: 0, width: 320, height: 180))
            #expect(container.surface.superview === container)
            #expect(container.surface.frame == container.bounds)
            container.frame.size = CGSize(width: 640, height: 360)
            container.layoutIfNeeded()
            #expect(container.surface.frame == container.bounds)
            #expect(container.backgroundColor == .black)
        }
    }
#endif
