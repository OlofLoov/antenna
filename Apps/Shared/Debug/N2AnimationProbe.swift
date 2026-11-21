#if DEBUG && os(iOS)
    import QuartzCore
    import UIKit

    @MainActor
    enum N2AnimationProbe {
        static func start() {
            guard ProcessInfo.processInfo.arguments.contains("-ui-testing-live") else { return }
            Task { @MainActor in
                while true {
                    try? await Task.sleep(for: .seconds(4))
                    report()
                }
            }
        }

        private static func report() {
            var lines: [String] = []
            for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
                for window in scene.windows {
                    walk(window.layer, depth: 0, window: window, into: &lines)
                }
            }
            if !lines.isEmpty { NSLog("N2ANIM \(lines.count) layers\n\(lines.prefix(40).joined(separator: "\n"))") }
        }

        private static func walk(_ layer: CALayer, depth: Int, window: UIWindow, into lines: inout [String]) {
            if let keys = layer.animationKeys(), !keys.isEmpty {
                let details = keys.map { key -> String in
                    guard let animation = layer.animation(forKey: key) else { return key }
                    let timing = "dur=\(animation.duration) rep=\(animation.repeatCount) speed=\(animation.speed)"
                    return "\(key)[\(type(of: animation)) \(timing) begin=\(animation.beginTime)]"
                }
                let owner = layer.delegate.map { String(describing: type(of: $0)) } ?? String(describing: type(of: layer))
                let state = "hidden=\(layer.isHidden) op=\(layer.opacity) speed=\(layer.speed)"
                lines.append("d\(depth) \(owner) win=\(type(of: window)) \(state) \(layer.frame) \(details)")
            }
            for sub in layer.sublayers ?? [] { walk(sub, depth: depth + 1, window: window, into: &lines) }
        }
    }
#endif
