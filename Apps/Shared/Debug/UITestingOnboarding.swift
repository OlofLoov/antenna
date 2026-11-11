#if DEBUG
    import Foundation
    import SwiftData

    /// `-ui-testing-onboarding signedIn` or `signedOut` starts the app on an
    /// empty in-memory store, so it opens on onboarding, with iCloud reported
    /// as signed in or out. Nothing reaches iCloud or the Keychain.
    enum UITestingOnboarding {
        static let argument = "-ui-testing-onboarding"

        enum Scenario: String {
            case signedIn
            case signedOut
        }

        static func scenario(arguments: [String] = ProcessInfo.processInfo.arguments) -> Scenario? {
            guard let index = arguments.firstIndex(of: argument) else { return nil }
            let next = arguments.index(after: index)
            guard next < arguments.endIndex, let scenario = Scenario(rawValue: arguments[next]) else {
                fatalError("\(argument) takes signedIn or signedOut")
            }
            return scenario
        }

        /// The empty store, or nil when the app was not launched for these tests.
        static func container() -> ModelContainer? {
            guard scenario() != nil else { return nil }
            let schema = Schema(AntennaSchema.models)
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            do {
                return try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("Could not create the onboarding UI testing store: \(error)")
            }
        }

        /// The scripted iCloud state, or nil outside these tests.
        static func signedInToICloud() -> Bool? {
            scenario().map { $0 == .signedIn }
        }
    }
#endif
