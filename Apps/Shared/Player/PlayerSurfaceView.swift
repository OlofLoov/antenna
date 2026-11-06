import AVFoundation
import AntennaCore
import SwiftUI

#if os(macOS)
    import AppKit

    /// The picture of the engine's Apple player, edge to edge with no
    /// controls. An engine without one shows the Ground color.
    struct PlayerSurfaceView: NSViewRepresentable {
        let engine: any PlaybackEngine

        func makeNSView(context: Context) -> PlayerLayerView {
            let view = PlayerLayerView()
            attach(view)
            return view
        }

        func updateNSView(_ view: PlayerLayerView, context: Context) {
            attach(view)
        }

        private func attach(_ view: PlayerLayerView) {
            AVPlayerEngine.resolve(engine)?.attach(to: view.playerLayer)
        }

        final class PlayerLayerView: NSView {
            let playerLayer = AVPlayerLayer()

            init() {
                super.init(frame: .zero)
                wantsLayer = true
                playerLayer.videoGravity = .resizeAspect
                playerLayer.backgroundColor = NSColor(Palette.ground).cgColor
                layer = playerLayer
            }

            @available(*, unavailable)
            required init?(coder: NSCoder) {
                nil
            }
        }
    }
#else
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
