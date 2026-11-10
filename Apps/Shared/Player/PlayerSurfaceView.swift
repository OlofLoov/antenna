import AVFoundation
import AntennaCore
import AntennaDemux
import SwiftUI

#if os(macOS)
    import AppKit

    /// The engine's picture, edge to edge with no controls: Apple's player,
    /// with the demuxing engine's layer above it while that engine plays.
    /// An engine with neither shows the Ground color.
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
            view.host(DemuxEngine.resolve(engine)?.videoLayer)
        }

        final class PlayerLayerView: NSView {
            let playerLayer = AVPlayerLayer()
            private weak var demuxLayer: CALayer?

            init() {
                super.init(frame: .zero)
                wantsLayer = true
                playerLayer.videoGravity = .resizeAspect
                playerLayer.backgroundColor = NSColor(Palette.ground).cgColor
                layer = playerLayer
            }

            func host(_ sublayer: CALayer?) {
                guard let sublayer, sublayer !== demuxLayer else { return }
                demuxLayer?.removeFromSuperlayer()
                playerLayer.addSublayer(sublayer)
                sublayer.frame = bounds
                demuxLayer = sublayer
            }

            override func layout() {
                super.layout()
                demuxLayer?.frame = bounds
            }

            @available(*, unavailable)
            required init?(coder: NSCoder) {
                nil
            }
        }
    }
#else
    import UIKit

    /// The engine's picture, edge to edge with no controls: Apple's player,
    /// with the demuxing engine's layer above it while that engine plays.
    /// An engine with neither shows the Ground color.
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
            view.host(DemuxEngine.resolve(engine)?.videoLayer)
        }

        final class PlayerLayerView: UIView {
            override static var layerClass: AnyClass { AVPlayerLayer.self }
            var playerLayer: AVPlayerLayer? { layer as? AVPlayerLayer }
            private weak var demuxLayer: CALayer?

            func host(_ sublayer: CALayer?) {
                guard let sublayer, sublayer !== demuxLayer else { return }
                demuxLayer?.removeFromSuperlayer()
                layer.addSublayer(sublayer)
                sublayer.frame = bounds
                demuxLayer = sublayer
            }

            override func layoutSubviews() {
                super.layoutSubviews()
                demuxLayer?.frame = bounds
            }
        }
    }
#endif
