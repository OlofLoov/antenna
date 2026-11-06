#if os(tvOS)
    import AVFoundation
    import AntennaCore
    import SwiftUI
    import UIKit

    /// The picture of the engine's Apple player, edge to edge with no
    /// controls. An engine without one shows the Ground color.
    struct PlayerSurfaceView: UIViewRepresentable {
        let engine: any PlaybackEngine

        func makeUIView(context: Context) -> PlayerLayerView {
            let view = PlayerLayerView()
            view.backgroundColor = UIColor(Palette.ground)
            view.playerLayer?.videoGravity = .resizeAspect
            attach(view)
            return view
        }

        func updateUIView(_ view: PlayerLayerView, context: Context) {
            attach(view)
        }

        private func attach(_ view: PlayerLayerView) {
            guard let layer = view.playerLayer else { return }
            AVPlayerEngine.resolve(engine)?.attach(to: layer)
        }

        final class PlayerLayerView: UIView {
            override static var layerClass: AnyClass { AVPlayerLayer.self }
            var playerLayer: AVPlayerLayer? { layer as? AVPlayerLayer }
        }
    }
#endif
