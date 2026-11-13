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
            let demuxer = DemuxEngine.resolve(engine)
            view.host(demuxer?.videoLayer, hold: demuxer?.hold.layer)
            demuxer?.enablePictureInPicture()
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

            private weak var holdLayer: CALayer?

            /// Puts the demuxing engine's picture above Apple's player and
            /// the held picture above both.
            func host(_ sublayer: CALayer?, hold: CALayer?) {
                if let sublayer, sublayer !== demuxLayer {
                    demuxLayer?.removeFromSuperlayer()
                    playerLayer.addSublayer(sublayer)
                    sublayer.frame = bounds
                    demuxLayer = sublayer
                }
                if let hold, hold !== holdLayer {
                    holdLayer?.removeFromSuperlayer()
                    playerLayer.addSublayer(hold)
                    hold.frame = bounds
                    holdLayer = hold
                }
                if let holdLayer { holdLayer.zPosition = 1 }
            }

            override func layout() {
                super.layout()
                demuxLayer?.frame = bounds
                holdLayer?.frame = bounds
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
            let demuxer = DemuxEngine.resolve(engine)
            view.host(demuxer?.videoLayer, hold: demuxer?.hold.layer)
            demuxer?.enablePictureInPicture()
            #if os(tvOS)
                // The TV's mode follows the stream once the picture is in a window.
                view.onWindow = { window in demuxer?.display.displayManager = window?.avDisplayManager }
                demuxer?.display.displayManager = view.window?.avDisplayManager
            #endif
        }

        final class PlayerLayerView: UIView {
            override static var layerClass: AnyClass { AVPlayerLayer.self }
            var playerLayer: AVPlayerLayer? { layer as? AVPlayerLayer }
            private weak var demuxLayer: CALayer?
            /// Called when the view joins or leaves a window.
            var onWindow: ((UIWindow?) -> Void)?

            override func didMoveToWindow() {
                super.didMoveToWindow()
                onWindow?(window)
            }

            private weak var holdLayer: CALayer?

            /// Puts the demuxing engine's picture above Apple's player and
            /// the held picture above both.
            func host(_ sublayer: CALayer?, hold: CALayer?) {
                if let sublayer, sublayer !== demuxLayer {
                    demuxLayer?.removeFromSuperlayer()
                    layer.addSublayer(sublayer)
                    sublayer.frame = bounds
                    demuxLayer = sublayer
                }
                if let hold, hold !== holdLayer {
                    holdLayer?.removeFromSuperlayer()
                    layer.addSublayer(hold)
                    hold.frame = bounds
                    holdLayer = hold
                }
                if let holdLayer { holdLayer.zPosition = 1 }
            }

            override func layoutSubviews() {
                super.layoutSubviews()
                demuxLayer?.frame = bounds
                holdLayer?.frame = bounds
            }
        }
    }
#endif
