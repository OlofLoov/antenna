#if DEBUG && os(iOS)
    import ObjectiveC
    import QuartzCore
    import UIKit

    @MainActor
    enum N2AnimationProbe {
        nonisolated(unsafe) static var open: [ObjectIdentifier: (count: Int, text: String)] = [:]
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

        private static func stack() -> String {
            Thread.callStackSymbols.dropFirst(3).prefix(16)
                .map { $0.split(separator: " ").dropFirst(3).prefix(2).joined(separator: " ") }
                .joined(separator: " < ")
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
                let text = animation.map(describe) ?? "nil start \(type(of: state)) " + stack()
                open[key] = ((open[key]?.count ?? 0) + 1, text)
                originalStart(state, startSel, animation)
            }
            let newStop: @convention(block) (AnyObject, CAAnimation?, Bool) -> Void = { state, animation, finished in
                stopped += 1
                let key = animation.map { ObjectIdentifier($0) } ?? ObjectIdentifier(state)
                if let entry = open[key] {
                    open[key] = entry.count > 1 ? (entry.count - 1, entry.text) : nil
                }
                originalStop(state, stopSel, animation, finished)
            }
            method_setImplementation(startMethod, imp_implementationWithBlock(newStart))
            method_setImplementation(stopMethod, imp_implementationWithBlock(newStop))
            NSLog("N2ANIM hooked")
        }

        private static func report() {
            guard !open.isEmpty || started != stopped else { return }
            let list = open.values.map { "\($0.count)x \($0.text)" }.sorted().prefix(30).joined(separator: "\n")
            NSLog("N2ANIM open=\(open.count) started=\(started) stopped=\(stopped)\n\(list)")
        }
    }
#endif
