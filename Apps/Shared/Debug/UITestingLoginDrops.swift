#if DEBUG
    import AntennaCore
    import Foundation
    import SwiftData

    /// UI test hooks for sending logins to an Apple TV.
    /// `-ui-testing-login-drops <mode>` swaps CloudKit for one in-memory
    /// drop store shared by the whole run, and on the Apple TV stands in for
    /// the iPhone once a code shows: `deliver` sends `anna` and `secret` for
    /// every source the code asks for, `unreadable` sends a box no key opens,
    /// and `silent` sends nothing. `-ui-testing-signin-sources <n>` seeds the
    /// onboarding store with one Xtream source at `xtream.test`, or two with
    /// the second at `refuse.test`, which the scripted server cannot reach,
    /// all without logins, so onboarding opens on "Sign in on this Apple TV".
    /// A third source, `Cabin` at `xtream.test`, comes with 3.
    ///
    /// On iPhone, iPad and Mac the same arguments script "Sign in your Apple
    /// TV": `Home provider`'s login is in an in-memory Keychain, and the mode
    /// says what iCloud does with Send. `pickup` has a stand-in TV take the
    /// delivery a second after it lands, `silent` leaves it, `offline`,
    /// `quota` and `used` fail the save, and `signedOut` reports no iCloud
    /// account. `UITESTING_PICKUP_WAIT_SECONDS` replaces the one-minute wait.
    /// `UITESTING_SETUP_HINT_SECONDS` replaces the two-minute hint and
    /// `UITESTING_LOGIN_WAIT_SECONDS` the setup card's one-minute wait.
    enum UITestingLoginDrops {
        static let argument = "-ui-testing-login-drops"
        static let sourcesArgument = "-ui-testing-signin-sources"
        static let waitVariable = "UITESTING_LOGIN_WAIT_SECONDS"
        static let pickupVariable = "UITESTING_PICKUP_WAIT_SECONDS"

        /// The mode after the argument, or nil without it.
        static func mode(arguments: [String] = ProcessInfo.processInfo.arguments) -> String? {
            value(after: argument, in: arguments)
        }

        private static func value(after argument: String, in arguments: [String]) -> String? {
            guard let index = arguments.firstIndex(of: argument), arguments.index(after: index) < arguments.endIndex else { return nil }
            return arguments[arguments.index(after: index)]
        }

        /// The run's store, or nil outside these tests.
        @MainActor static let store: InMemoryLoginDrops? = mode().map { mode in
            switch mode {
            case "offline": InMemoryLoginDrops(failure: .offline)
            case "quota": InMemoryLoginDrops(failure: .quotaExceeded)
            case "used": InMemoryLoginDrops(failure: .alreadyUsed)
            default: InMemoryLoginDrops()
            }
        }

        /// The run's Keychain on iPhone, iPad and Mac, holding `Home provider`'s login.
        static let credentials: UITestingOnboarding.Credentials = {
            let credentials = UITestingOnboarding.Credentials()
            try? credentials.save(.init(username: "anna", password: "secret"), for: homeID.uuidString)
            return credentials
        }()

        static let homeID = UUID(uuidString: "00000000-0000-0000-0000-0000000000A1") ?? UUID()
        static let flatID = UUID(uuidString: "00000000-0000-0000-0000-0000000000A2") ?? UUID()
        static let cabinID = UUID(uuidString: "00000000-0000-0000-0000-0000000000A3") ?? UUID()

        /// Adds the sources to sign in to `container`, when asked for.
        static func seed(_ container: ModelContainer) {
            guard let count = value(after: sourcesArgument, in: ProcessInfo.processInfo.arguments).flatMap(Int.init) else { return }
            let sources = [
                SourceDescriptor(id: homeID, name: "Home provider", kind: .xtream, url: URL(fileURLWithPath: "/")),
                SourceDescriptor(id: flatID, name: "Holiday flat", kind: .xtream, url: URL(fileURLWithPath: "/")),
                SourceDescriptor(id: cabinID, name: "Cabin", kind: .xtream, url: URL(fileURLWithPath: "/")),
            ]
            let links = ["http://xtream.test", "http://refuse.test", "http://xtream.test/cabin"]
            let context = ModelContext(container)
            for (order, var source) in sources.prefix(count).enumerated() {
                source.url = URL(string: links[order]) ?? source.url
                context.insert(SourceRecord(descriptor: source, sortOrder: order))
            }
            try? context.save()
        }

        /// The TV's card with the scripted store, or nil outside UI tests.
        /// Other UI tests get a card that reports no iCloud account, so an
        /// unsigned build never reaches CloudKit.
        @MainActor static func receiverDependencies(
            arguments: [String] = ProcessInfo.processInfo.arguments
        ) -> LoginReceiverModel.Dependencies? {
            guard arguments.contains(where: { $0.hasPrefix("-ui-testing") }) else { return nil }
            let signedIn = store != nil && UITestingOnboarding.scenario() != .signedOut
            var dependencies = LoginReceiverModel.Dependencies(
                identity: FixedICloudIdentity(signedIn: signedIn), drops: store ?? InMemoryLoginDrops(), activity: NoSetupActivity())
            dependencies.pollInterval = .milliseconds(500)
            if let seconds = ProcessInfo.processInfo.environment[UITestingSetup.hintVariable].flatMap(TimeInterval.init) {
                dependencies.hintDelay = seconds
            }
            return dependencies
        }

        /// Stands in for the iPhone: once `receiver` shows a code, sends
        /// what the mode says, once. Nil outside these tests.
        @MainActor static func sendFromPhone(to receiver: LoginReceiverModel) -> Task<Void, Never>? {
            guard store != nil, mode() != "silent" else { return nil }
            return Task {
                while receiver.link == nil {
                    guard (try? await Task.sleep(for: .milliseconds(200))) != nil else { return }
                }
                guard (try? await Task.sleep(for: .seconds(1))) != nil, let link = receiver.link else { return }
                await deliver(for: link.sources, to: link)
            }
        }

        /// "Sign in your Apple TV" with the scripted Keychain, server and store, or nil outside these tests.
        @MainActor static func sendDependencies() -> SendLoginsModel.Dependencies? {
            guard let delivery = deliveryDependencies() else { return nil }
            let session = UITestingOnboarding.session() ?? .shared
            return .init(connector: SourceConnector(session: session, credentials: credentials), delivery: delivery)
        }

        /// Send with the scripted store, or nil outside UI tests. Other UI
        /// tests get one that reports no iCloud account, so an unsigned
        /// build never reaches CloudKit.
        @MainActor static func deliveryDependencies(
            arguments: [String] = ProcessInfo.processInfo.arguments
        ) -> LoginDelivery.Dependencies? {
            guard arguments.contains(where: { $0.hasPrefix("-ui-testing") }) else { return nil }
            guard let store, let mode = mode() else {
                return .init(identity: FixedICloudIdentity(signedIn: false), drops: InMemoryLoginDrops())
            }
            var dependencies = LoginDelivery.Dependencies(identity: FixedICloudIdentity(signedIn: mode != "signedOut"), drops: store)
            dependencies.pollInterval = .milliseconds(500)
            if let seconds = ProcessInfo.processInfo.environment[pickupVariable].flatMap(TimeInterval.init) {
                dependencies.pickupWait = seconds
            }
            if mode == "pickup" {
                Task {
                    while (try? await Task.sleep(for: .seconds(1))) != nil {
                        await store.pickUpWaiting()
                    }
                }
            }
            return dependencies
        }

        /// Seals and saves the mode's logins for `sources` under `link`.
        @MainActor static func deliver(for sources: [UUID], to link: SetupLink) async {
            guard let store, let key = link.key else { return }
            let sealed: SealedLogin?
            switch mode() {
            case "deliver":
                let payload = LoginPayload(logins: sources.map { .init(source: $0, username: "anna", password: "secret") })
                sealed = try? LoginSeal.seal(payload, to: key, token: link.token)
            case "unreadable":
                sealed = SealedLogin(enc: Data(repeating: 9, count: 32), box: Data(repeating: 9, count: 64))
            default:
                sealed = nil
            }
            guard let sealed else { return }
            try? await store.save(sealed, token: link.token)
        }
    }
#endif
