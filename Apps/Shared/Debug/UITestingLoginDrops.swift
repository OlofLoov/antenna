#if DEBUG
    import Foundation

    /// UI test hooks for sending logins to an Apple TV.
    /// `-ui-testing-login-drops <mode>` swaps CloudKit for one in-memory
    /// drop store shared by the whole run.
    enum UITestingLoginDrops {
        static let argument = "-ui-testing-login-drops"

        /// The mode after the argument, or nil without it.
        static func mode(arguments: [String] = ProcessInfo.processInfo.arguments) -> String? {
            guard let index = arguments.firstIndex(of: argument), arguments.index(after: index) < arguments.endIndex else { return nil }
            return arguments[arguments.index(after: index)]
        }

        /// The run's store, or nil outside these tests.
        @MainActor static let store: InMemoryLoginDrops? = mode() == nil ? nil : InMemoryLoginDrops()
    }
#endif
