#if os(tvOS)
    import AVFoundation
    import AntennaCore
    import SwiftUI
    import UIKit

    /// The picture of a `SystemPlaybackEngine`, edge to edge with no
    /// controls. Any other engine shows the Ground colour.
    struct VideoSurface: UIViewRepresentable {
        let engine: any PlaybackEngine

        func makeUIView(context: Context) -> PlayerLayerView {
            let view = PlayerLayerView()
            view.backgroundColor = UIColor(Palette.ground)
            view.playerLayer?.videoGravity = .resizeAspect
            view.playerLayer?.player = (engine as? SystemPlaybackEngine)?.player
            return view
        }

        func updateUIView(_ view: PlayerLayerView, context: Context) {
            let player = (engine as? SystemPlaybackEngine)?.player
            if view.playerLayer?.player !== player { view.playerLayer?.player = player }
        }

        final class PlayerLayerView: UIView {
            override static var layerClass: AnyClass { AVPlayerLayer.self }
            var playerLayer: AVPlayerLayer? { layer as? AVPlayerLayer }
        }
    }
#endif
