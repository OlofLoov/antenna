#if DEBUG && !os(tvOS)
    import AntennaCore
    import Foundation
    #if os(iOS)
        import UIKit
    #endif

    /// Stands in for Siri and Shortcuts in UI tests, which cannot drive
    /// them (app-intents capability). `-ui-testing-intent <request>` hands the
    /// app at launch what an action hands it once Antenna is forward:
    /// `tune:<channel reference>`, `play:<title reference>`, `search:<text>`
    /// or `search` alone for an empty field. `-ui-testing-intent-on-return
    /// <request>` hands the request over each time the app comes back to the
    /// foreground instead, as Siri does to an app that is already running.
    enum UITestingIntents {
        static let argument = "-ui-testing-intent"
        static let onReturnArgument = "-ui-testing-intent-on-return"

        /// True once the app has been in the background; the launch itself
        /// also enters the foreground and hands nothing over.
        @MainActor private static var wentToBackground = false

        /// Opens the `-ui-testing-intent-on-return` request in `host` whenever
        /// the app comes back from the background.
        @MainActor
        static func deliverOnReturn(to host: AppIntentHost) {
            #if os(iOS)
                guard let request = request(argument: onReturnArgument) else { return }
                let center = NotificationCenter.default
                center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { _ in
                    MainActor.assumeIsolated { wentToBackground = true }
                }
                center.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { _ in
                    MainActor.assumeIsolated {
                        if wentToBackground { host.open(request) }
                    }
                }
            #endif
        }

        static func request(argument: String = argument, arguments: [String] = ProcessInfo.processInfo.arguments) -> IntentRequest? {
            guard let index = arguments.firstIndex(of: argument), arguments.index(after: index) < arguments.endIndex else { return nil }
            let value = arguments[arguments.index(after: index)]
            if value == "search" { return .search(nil) }
            if value.hasPrefix("search:") { return .search(String(value.dropFirst("search:".count))) }
            if value.hasPrefix("tune:"), let key = LastChannelKey(parsing: String(value.dropFirst("tune:".count))) { return .tune(key) }
            if value.hasPrefix("play:"), let reference = TitleReference(parsing: String(value.dropFirst("play:".count))) {
                return .play(reference)
            }
            fatalError("\(argument) takes tune:<reference>, play:<reference>, search:<text> or search")
        }
    }
#endif
