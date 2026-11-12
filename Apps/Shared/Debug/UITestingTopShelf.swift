#if DEBUG && os(tvOS)
    import Foundation

    /// Top Shelf links in the shell's UI tests. `-antenna.openURL <url>`
    /// delivers a link as selecting a tile would. Alone it arrives at launch;
    /// with `-ui-testing-open-url-running` it arrives once a channel plays.
    extension UITestingShell {
        static let openURLArgument = "-antenna.openURL"
        static let openURLRunningArgument = "-ui-testing-open-url-running"

        static func openURL(arguments: [String] = ProcessInfo.processInfo.arguments) -> URL? {
            guard let index = arguments.firstIndex(of: openURLArgument), index + 1 < arguments.count else { return nil }
            return URL(string: arguments[index + 1])
        }

        /// With `-ui-testing-open-url-running`, waits for the launch tune and
        /// then hands the link to `inbox`, as a tile selected while Antenna runs.
        @MainActor
        static func openURLWhenRunning(into inbox: TopShelfInbox?, model: ShellModel) {
            let arguments = ProcessInfo.processInfo.arguments
            guard arguments.contains(openURLRunningArgument), let url = openURL(arguments: arguments), let inbox else { return }
            Task {
                while model.tuned == nil { try? await Task.sleep(for: .milliseconds(100)) }
                inbox.receive(url)
            }
        }
    }
#endif
