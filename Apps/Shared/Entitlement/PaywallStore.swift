import AntennaCore
import Foundation
import StoreKit

/// A product as the paywall shows it. `displayPrice` is the App Store's
/// string for the user's region, shown as given.
struct PaywallProduct: Equatable, Sendable {
    var kind: ProductKind
    var displayPrice: String
}

/// What the App Store said about the products.
enum ProductsAnswer: Equatable, Sendable {
    case products([PaywallProduct])
    /// Antenna is not sold in this region.
    case notSold
    /// No answer; the App Store could not be reached.
    case unreachable
}

/// How a purchase ended.
enum PurchaseOutcome: Equatable, Sendable {
    /// Confirmed; the evidence unlocks the app.
    case purchased([PurchaseEvidence])
    case cancelled
    /// Waiting for a parent's approval (Ask to Buy).
    case pending
    case failed
    case offline
    case notAllowed
}

/// How a restore ended.
enum RestoreOutcome: Equatable, Sendable {
    /// The records the App Store holds for this Apple Account, possibly none.
    case found([PurchaseEvidence])
    case cancelled
    case failed
    case offline
}

/// The App Store as the paywall uses it. `StoreKitPaywallStore` in the app,
/// a scripted store in previews and tests.
@MainActor
protocol PaywallStore {
    /// False when Screen Time or a profile turns purchases off.
    var canMakePayments: Bool { get }
    func products() async -> ProductsAnswer
    /// Yearly's introductory offer when this Apple Account can take it, else nil.
    func introOffer() async -> IntroOffer?
    func purchase(_ kind: ProductKind) async -> PurchaseOutcome
    /// Asks the App Store for this account's purchases. May ask the user to sign in.
    func restore() async -> RestoreOutcome
}

/// The paywall over StoreKit 2.
@MainActor
final class StoreKitPaywallStore: PaywallStore {
    private var loaded: [ProductKind: Product] = [:]

    var canMakePayments: Bool { AppStore.canMakePayments }

    func products() async -> ProductsAnswer {
        do {
            let products = try await Product.products(for: ProductKind.allCases.map(\.productID))
            for product in products {
                if let kind = ProductKind(productID: product.id) { loaded[kind] = product }
            }
            let shown = ProductKind.allCases.compactMap { kind in
                loaded[kind].map { PaywallProduct(kind: kind, displayPrice: $0.displayPrice) }
            }
            return shown.isEmpty ? .notSold : .products(shown)
        } catch {
            return .unreachable
        }
    }

    func introOffer() async -> IntroOffer? {
        guard let subscription = loaded[.yearly]?.subscription, let offer = subscription.introductoryOffer,
            await subscription.isEligibleForIntroOffer
        else { return nil }
        return IntroOffer(offer)
    }

    func purchase(_ kind: ProductKind) async -> PurchaseOutcome {
        guard let product = loaded[kind] else { return .failed }
        do {
            switch try await product.purchase() {
            case .success(.verified(let transaction)):
                await transaction.finish()
                return .purchased([await PurchaseEvidence(transaction)])
            case .success(.unverified):
                // Never finished and never counted.
                return .failed
            case .userCancelled: return .cancelled
            case .pending: return .pending
            @unknown default: return .failed
            }
        } catch let error as StoreKitError {
            switch error {
            case .networkError: return .offline
            case .userCancelled: return .cancelled
            default: return .failed
            }
        } catch Product.PurchaseError.purchaseNotAllowed {
            return .notAllowed
        } catch {
            return .failed
        }
    }

    func restore() async -> RestoreOutcome {
        do {
            try await AppStore.sync()
        } catch StoreKitError.userCancelled {
            return .cancelled
        } catch StoreKitError.networkError {
            return .offline
        } catch {
            return .failed
        }
        return .found(await StoreKitEvidence.current())
    }
}

extension IntroOffer {
    /// The App Store's introductory offer in the paywall's terms.
    init?(_ offer: Product.SubscriptionOffer) {
        let payment: Payment
        switch offer.paymentMode {
        case .freeTrial: payment = .freeTrial
        case .payUpFront: payment = .payUpFront
        case .payAsYouGo: payment = .payAsYouGo
        default: return nil
        }
        let unit: Unit
        switch offer.period.unit {
        case .day: unit = .day
        case .week: unit = .week
        case .month: unit = .month
        case .year: unit = .year
        @unknown default: return nil
        }
        self.init(payment: payment, displayPrice: offer.displayPrice, unit: unit, value: offer.period.value, periodCount: offer.periodCount)
    }
}
