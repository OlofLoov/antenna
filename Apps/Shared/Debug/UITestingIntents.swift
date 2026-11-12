#if DEBUG && !os(tvOS)
    import AntennaCore
    import Foundation

    /// Stands in for Siri and Shortcuts in UI tests, which cannot drive
    /// them (app-intents capability). `-ui-testing-intent <request>` hands the
    /// app at launch what an action hands it once Antenna is forward:
    /// `tune:<channel reference>`, `play:<title reference>`, `search:<text>`
    /// or `search` alone for an empty field.
    enum UITestingIntents {
        static let argument = "-ui-testing-intent"

        static func request(arguments: [String] = ProcessInfo.processInfo.arguments) -> IntentRequest? {
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
