#if DEBUG && os(iOS)
    import ObjectiveC
    import QuartzCore
    import UIKit

    @MainActor
    enum N2AnimationProbe {
        nonisolated(unsafe) static var open: [ObjectIdentifier: String] = [:]
        nonisolated(unsafe) static var started = 0
        nonisolated(unsafe) static var stopped = 0

        static func start() {
            guard ProcessInfo.processInfo.arguments.contains("-ui-testing-live") else { return }
            hook()
            Task { @MainActor in
                while true {
                    try? await Task.sleep(for: .seconds(4))
                    report()
                }
            }
        }

        private static func describe(_ animation: CAAnimation) -> String {
            var text = "\(type(of: animation))"
            if let property = animation as? CAPropertyAnimation { text += " key=\(property.keyPath ?? "-")" }
            if let basic = animation as? CABasicAnimation {
                text += " from=\(String(describing: basic.fromValue)) to=\(String(describing: basic.toValue))"
            }
            text += " dur=\(animation.duration)"
            return text
        }

        private static func hook() {
            guard let cls = NSClassFromString("UIViewAnimationState") else { return NSLog("N2ANIM no class") }
            let startSel = NSSelectorFromString("animationDidStart:")
            let stopSel = NSSelectorFromString("animationDidStop:finished:")
            guard let startMethod = class_getInstanceMethod(cls, startSel),
                let stopMethod = class_getInstanceMethod(cls, stopSel)
            else { return NSLog("N2ANIM no methods") }
            typealias StartFn = @convention(c) (AnyObject, Selector, CAAnimation?) -> Void
            typealias StopFn = @convention(c) (AnyObject, Selector, CAAnimation?, Bool) -> Void
            let originalStart = unsafeBitCast(method_getImplementation(startMethod), to: StartFn.self)
            let originalStop = unsafeBitCast(method_getImplementation(stopMethod), to: StopFn.self)
            let newStart: @convention(block) (AnyObject, CAAnimation?) -> Void = { state, animation in
                started += 1
                let key = animation.map { ObjectIdentifier($0) } ?? ObjectIdentifier(state)
                open[key] = (animation.map(describe) ?? "nil animation") + " state=\(ObjectIdentifier(state))"
                originalStart(state, startSel, animation)
            }
            let newStop: @convention(block) (AnyObject, CAAnimation?, Bool) -> Void = { state, animation, finished in
                stopped += 1
                open[animation.map { ObjectIdentifier($0) } ?? ObjectIdentifier(state)] = nil
                originalStop(state, stopSel, animation, finished)
            }
            method_setImplementation(startMethod, imp_implementationWithBlock(newStart))
            method_setImplementation(stopMethod, imp_implementationWithBlock(newStop))
            NSLog("N2ANIM hooked")
        }

        private static func report() {
            guard !open.isEmpty else { return }
            let list = open.values.sorted().prefix(30).joined(separator: "\n")
            NSLog("N2ANIM open=\(open.count) started=\(started) stopped=\(stopped)\n\(list)")
        }
    }
#endif
