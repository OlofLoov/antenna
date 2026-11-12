#if DEBUG
    import AntennaCore
    import Foundation
    import SwiftData

    /// UI test hooks for setting up an Apple TV from an iPhone. With
    /// `-ui-testing-onboarding`, the QR card follows the scripted iCloud
    /// state and offers no Handoff. `UITESTING_SETUP_HINT_SECONDS` replaces
    /// the two-minute hint delay. `-ui-testing-setup-send <kind>` stands in
    /// for the iPhone: once the QR card shows, a source of that kind
    /// (`m3u`, `xtream`, `stalker`, or any other text for a kind this build
    /// does not know) is saved to the store, as iCloud would.
    ///
    /// On iPhone, iPad and Mac, `-ui-testing-setup-link <url>` opens the
    /// link at launch as if scanned. `-ui-testing-setup-delivery` scripts
    /// the upload after Connect: `confirm` confirms it after one second,
    /// `silent` never does, and `signedOut` reports no iCloud account.
    /// `UITESTING_SETUP_SEND_TIMEOUT_SECONDS` replaces the 30-second wait.
    enum UITestingSetup {
        static let sendArgument = "-ui-testing-setup-send"
        static let linkArgument = "-ui-testing-setup-link"
        static let deliveryArgument = "-ui-testing-setup-delivery"
        static let timeoutVariable = "UITESTING_SETUP_SEND_TIMEOUT_SECONDS"
        static let hintVariable = "UITESTING_SETUP_HINT_SECONDS"

        /// The scripted card, or nil outside onboarding UI tests.
        @MainActor static func pairingDependencies() -> SetupPairingModel.Dependencies? {
            guard let scenario = UITestingOnboarding.scenario() else { return nil }
            var dependencies = SetupPairingModel.Dependencies(
                identity: FixedICloudIdentity(signedIn: scenario != .signedOut), activity: NoSetupActivity(),
                drops: UITestingLoginDrops.store ?? InMemoryLoginDrops())
            dependencies.pollInterval = .milliseconds(500)
            if let seconds = ProcessInfo.processInfo.environment[UITestingLoginDrops.waitVariable].flatMap(TimeInterval.init) {
                dependencies.loginWait = seconds
            }
            if let seconds = ProcessInfo.processInfo.environment[hintVariable].flatMap(TimeInterval.init) {
                dependencies.hintDelay = seconds
            }
            return dependencies
        }

        /// The link to open at launch, or nil without the argument.
        static func linkAtLaunch(arguments: [String] = ProcessInfo.processInfo.arguments) -> URL? {
            value(after: linkArgument, in: arguments).flatMap(URL.init(string:))
        }

        /// The scripted upload, or nil without the argument.
        @MainActor static func deliveryDependencies(
            arguments: [String] = ProcessInfo.processInfo.arguments
        ) -> SetupDelivery.Dependencies? {
            guard let mode = value(after: deliveryArgument, in: arguments) else { return nil }
            let exports = ScriptedExports()
            var dependencies = SetupDelivery.Dependencies(identity: FixedICloudIdentity(signedIn: mode != "signedOut"), exports: exports)
            if let seconds = ProcessInfo.processInfo.environment[timeoutVariable].flatMap(Double.init) {
                dependencies.timeout = .milliseconds(Int(seconds * 1000))
            }
            if mode == "confirm" {
                Task {
                    try? await Task.sleep(for: .seconds(1))
                    exports.export(DateInterval(start: .now, duration: 0.1))
                }
            }
            return dependencies
        }

        private static func value(after argument: String, in arguments: [String]) -> String? {
            guard let index = arguments.firstIndex(of: argument), arguments.index(after: index) < arguments.endIndex else { return nil }
            return arguments[arguments.index(after: index)]
        }

        /// The kind to send, or nil without the argument.
        static func sentKind(arguments: [String] = ProcessInfo.processInfo.arguments) -> String? {
            value(after: sendArgument, in: arguments)
        }

        /// Saves the scripted source once `pairing` shows its code; nil
        /// without the argument.
        @MainActor static func sendFromPhone(into context: ModelContext, after pairing: SetupPairingModel) -> Task<Void, Never>? {
            guard let kind = sentKind() else { return nil }
            return Task {
                while pairing.link == nil {
                    guard (try? await Task.sleep(for: .milliseconds(200))) != nil else { return }
                }
                guard (try? await Task.sleep(for: .seconds(1))) != nil, let link = pairing.link else { return }
                let record = SourceRecord(descriptor: descriptor(kind))
                record.kindRaw = kind
                context.insert(record)
                try? context.save()
                // With -ui-testing-login-drops, the login follows the source.
                await UITestingLoginDrops.deliver(for: [record.id], to: link)
            }
        }

        private static func link(_ text: String) -> URL {
            URL(string: text) ?? URL(fileURLWithPath: "/")
        }

        private static func descriptor(_ kind: String) -> SourceDescriptor {
            switch SourceKind(rawValue: kind) {
            case .xtream: SourceDescriptor(id: UUID(), name: "Home provider", kind: .xtream, url: link("http://xtream.test"))
            case .stalker: SourceDescriptor(id: UUID(), name: "Hallway portal", kind: .stalker, url: link("http://portal.test/c/"))
            default: SourceDescriptor(id: UUID(), name: "Home playlist", kind: .m3u, url: link("http://onboarding.test/tv.m3u"))
            }
        }
    }
#endif
