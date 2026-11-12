#if DEBUG
    import AntennaCore
    import Foundation

    /// The unlock in UI tests and the unit test host, compiled into Debug builds only.
    ///
    /// Every launch with a `-ui-testing-*` or `-ui-screenshots` argument, and
    /// the unit test host, opens unlocked through a stand-in provider, so
    /// existing tests go straight into the app.
    ///
    /// `-antenna.entitlement <verdict>` sets the stand-in's verdict:
    /// `locked`, `lifetime`, `yearly`, `expired`, `revoked`, or `lapsing`
    /// (unlocked at launch, revoked right after). `-antenna.store <scenario>`
    /// scripts the App Store the paywall talks to; see `StoreScenario`.
    enum UITestingPaywall {
        static let entitlementArgument = "-antenna.entitlement"
        static let storeArgument = "-antenna.store"
        static let ended = Date(timeIntervalSince1970: 1_700_000_000)

        enum Verdict: String {
            case locked, lifetime, yearly, expired, revoked, lapsing

            var entitlement: Entitlement {
                let now = Date()
                return switch self {
                case .locked: .notEntitled(.neverPurchased)
                case .lifetime, .lapsing: .entitled(Grant(kind: .lifetime, verifiedAt: now))
                case .yearly: .entitled(Grant(kind: .yearly, expiresAt: now.addingTimeInterval(200 * 86_400), verifiedAt: now))
                case .expired: .notEntitled(.expired(on: UITestingPaywall.ended))
                case .revoked: .notEntitled(.revoked)
                }
            }
        }

        enum StoreScenario: String {
            /// Both products with prices; a purchase of either succeeds; restore finds nothing.
            case products
            /// As `products`, with a free first week on Yearly.
            case offer
            /// The App Store never answers.
            case unavailable
            /// No answer at first, the products on Try again.
            case retry
            /// Not sold in this region.
            case notSold
            /// Purchases turned off by Screen Time.
            case notAllowed
            /// A purchase waits for a parent's approval.
            case pending
            /// A purchase fails.
            case failed
            /// The user cancels the purchase sheet.
            case cancel
            /// Restore finds a Lifetime purchase shared through Family Sharing.
            case restoreShared
            /// Restore finds only a Yearly subscription that ended.
            case restoreExpired
        }

        private static func value(after argument: String, in arguments: [String]) -> String? {
            guard let index = arguments.firstIndex(of: argument), arguments.index(after: index) < arguments.endIndex else { return nil }
            return arguments[arguments.index(after: index)]
        }

        /// The stand-in unlock, or nil in a normal launch.
        @MainActor static func unlock(
            arguments: [String] = ProcessInfo.processInfo.arguments, environment: [String: String] = ProcessInfo.processInfo.environment
        ) -> Unlock? {
            let named = value(after: entitlementArgument, in: arguments)
            let testing =
                arguments.contains { $0.hasPrefix("-ui-testing") || $0 == "-ui-screenshots" }
                || environment["XCTestConfigurationFilePath"] != nil
            guard named != nil || testing else { return nil }
            guard let verdict = Verdict(rawValue: named ?? Verdict.lifetime.rawValue) else {
                fatalError("\(entitlementArgument) takes locked, lifetime, yearly, expired, revoked or lapsing")
            }
            let scenario = value(after: storeArgument, in: arguments).map { name in
                guard let scenario = StoreScenario(rawValue: name) else { fatalError("\(storeArgument) has no scenario \(name)") }
                return scenario
            }
            let (unlock, provider) = Unlock.fixed(verdict.entitlement) { store(scenario ?? .products) }
            if verdict == .lapsing {
                Task { await provider.set(.notEntitled(.revoked)) }
            }
            return unlock
        }

        @MainActor static func store(_ scenario: StoreScenario) -> ScriptedPaywallStore {
            let store = ScriptedPaywallStore()
            switch scenario {
            case .products: break
            case .offer: store.offer = IntroOffer(payment: .freeTrial, displayPrice: "$0.00", unit: .week)
            case .unavailable: store.answers = [.unreachable]
            case .retry: store.answers = [.unreachable, .products(ScriptedPaywallStore.prices)]
            case .notSold: store.answers = [.notSold]
            case .notAllowed: store.canMakePayments = false
            case .pending: store.purchaseOutcome = .pending
            case .failed: store.purchaseOutcome = .failed
            case .cancel: store.purchaseOutcome = .cancelled
            case .restoreShared: store.restoreOutcome = .found([PurchaseEvidence(kind: .lifetime, familyShared: true)])
            case .restoreExpired: store.restoreOutcome = .found([PurchaseEvidence(kind: .yearly, expiresAt: ended)])
            }
            return store
        }
    }
#endif
