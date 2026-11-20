import AVFoundation
import AntennaCore
import AntennaDemux
import SwiftUI

#if os(macOS)
    import AppKit

    /// The engine's picture, edge to edge with no controls: Apple's player,
    /// with the demuxing engine's layer above it while that engine plays.
    /// Black shows around a picture that does not fill the view, and in
    /// place of an engine with neither.
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
            #if DEBUG
                // The store screenshots show a looping clip in place of the scripted engines' black picture.
                if let picture = UITestingStoreShots.picture { return picture.attach(to: view.playerLayer) }
            #endif
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
                playerLayer.backgroundColor = NSColor.black.cgColor
                layer = playerLayer
            }

            private weak var holdLayer: CALayer?

            /// Puts the demuxing engine's picture above Apple's player and
            /// the held picture above both.
            func host(_ sublayer: CALayer?, hold: CALayer?) {
                if let sublayer, sublayer !== demuxLayer {
                    demuxLayer?.leave(playerLayer)
                    playerLayer.addSublayer(sublayer)
                    sublayer.frame = bounds
                    demuxLayer = sublayer
                }
                if let hold, hold !== holdLayer {
                    holdLayer?.leave(playerLayer)
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
    /// Black shows around a picture that does not fill the view, and in
    /// place of an engine with neither.
    struct PlayerSurfaceView: UIViewRepresentable {
        let engine: any PlaybackEngine

        func makeUIView(context: Context) -> PlayerLayerView {
            let view = PlayerLayerView()
            attach(view)
            return view
        }

        func updateUIView(_ view: PlayerLayerView, context: Context) {
            attach(view)
        }

        private func attach(_ view: PlayerLayerView) {
            guard let layer = view.playerLayer else { return }
            #if DEBUG
                // The store screenshots show a looping clip in place of the scripted engines' black picture.
                if let picture = UITestingStoreShots.picture { return picture.attach(to: layer) }
            #endif
            AVPlayerEngine.resolve(engine)?.attach(to: layer)
            let demuxer = DemuxEngine.resolve(engine)
            var picture: CALayer? = demuxer?.videoLayer
            #if DEBUG && os(tvOS)
                // The shell's UI tests check where the scripted engine's picture is.
                picture = picture ?? UITestingShell.picture(of: engine)
            #endif
            view.host(picture, hold: demuxer?.hold.layer)
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

            override init(frame: CGRect) {
                super.init(frame: frame)
                backgroundColor = .black
                playerLayer?.videoGravity = .resizeAspect
            }

            @available(*, unavailable)
            required init?(coder: NSCoder) {
                nil
            }

            override func didMoveToWindow() {
                super.didMoveToWindow()
                onWindow?(window)
            }

            private weak var holdLayer: CALayer?

            /// Puts the demuxing engine's picture above Apple's player and
            /// the held picture above both.
            func host(_ sublayer: CALayer?, hold: CALayer?) {
                if let sublayer, sublayer !== demuxLayer {
                    demuxLayer?.leave(layer)
                    layer.addSublayer(sublayer)
                    sublayer.frame = bounds
                    demuxLayer = sublayer
                }
                if let hold, hold !== holdLayer {
                    holdLayer?.leave(layer)
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

extension CALayer {
    /// Takes this layer out of `host`, and leaves it where it is when
    /// another surface has taken it since. A picture layer sits in one view
    /// at a time. When multi-view ends, the kept tile's player moves to the
    /// full-screen picture and the tile's view, still on screen while the
    /// grid closes, switches to the tile's new empty player; it must not
    /// pull the picture out of the full-screen view (multi-view/leave-multi-view).
    fileprivate func leave(_ host: CALayer) {
        guard superlayer === host else { return }
        removeFromSuperlayer()
    }
}
