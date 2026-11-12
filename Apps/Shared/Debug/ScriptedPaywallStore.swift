#if DEBUG
    import AntennaCore
    import Foundation

    /// A paywall store with set answers, for previews, unit tests and UI
    /// tests. Nothing reaches the App Store.
    @MainActor
    final class ScriptedPaywallStore: PaywallStore {
        /// Holds a call until `open()`, so a test can look at the paywall
        /// while a load, purchase or restore runs.
        @MainActor
        final class Hold {
            private var isOpen = false
            private var waiting: [CheckedContinuation<Void, Never>] = []

            func wait() async {
                guard !isOpen else { return }
                await withCheckedContinuation { waiting.append($0) }
            }

            func open() {
                isOpen = true
                for continuation in waiting { continuation.resume() }
                waiting = []
            }
        }

        static let prices = [PaywallProduct(kind: .lifetime, displayPrice: "$29.99"), PaywallProduct(kind: .yearly, displayPrice: "$9.99")]

        var canMakePayments = true
        /// Answers in order; the last one repeats.
        var answers: [ProductsAnswer] = [.products(prices)]
        var offer: IntroOffer?
        var purchaseOutcome: PurchaseOutcome = .purchased([PurchaseEvidence(kind: .lifetime)])
        var restoreOutcome: RestoreOutcome = .found([])
        var productsHold: Hold?
        var purchaseHold: Hold?
        var restoreHold: Hold?
        private(set) var purchases: [ProductKind] = []
        private(set) var restores = 0

        func products() async -> ProductsAnswer {
            await productsHold?.wait()
            let answer = answers.first ?? .unreachable
            if answers.count > 1 { answers.removeFirst() }
            return answer
        }

        func introOffer() async -> IntroOffer? { offer }

        func purchase(_ kind: ProductKind) async -> PurchaseOutcome {
            purchases.append(kind)
            await purchaseHold?.wait()
            return purchaseOutcome
        }

        func restore() async -> RestoreOutcome {
            restores += 1
            await restoreHold?.wait()
            return restoreOutcome
        }
    }
#endif
