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
    }
#endif
