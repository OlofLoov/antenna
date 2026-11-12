import Foundation

/// Every line the paywall shows, by key, with its en text
/// (paywall-and-entitlement/honest-paywall-wording). Tests and the view
/// match on the key; the text is what a person reads.
public enum PaywallCopy {
    public enum Key: String, Sendable, CaseIterable {
        case titleDefault = "title.default"
        case titleLapsed = "title.lapsed"
        case body
        case lineLifetime = "line.lifetime"
        case lineRenews = "line.renews"
        case lineFreeTrial = "line.freeTrial"
        case lineIntroPrice = "line.introPrice"
        case lineIntroPerPeriod = "line.introPerPeriod"
        case unitPerYear = "unit.perYear"
        case unitOneTime = "unit.oneTime"
        case priceLoading = "price.loading"
        case priceUnavailable = "price.unavailable"
        case legal
        case statusPending = "status.pending"
        case statusFailed = "status.failed"
        case statusRestoreFailed = "status.restoreFailed"
        case statusNothingFound = "status.nothingFound"
        case statusOffline = "status.offline"
        case statusNotAllowed = "status.notAllowed"
        case statusNotInStorefront = "status.notInStorefront"
        case restoredLifetime = "restored.lifetime"
        case restoredYearly = "restored.yearly"
        case lapsedExpired = "lapsed.expired"
        case lapsedRevoked = "lapsed.revoked"
        case unavailableTitle = "unavailable.title"
        case productLifetime = "product.lifetime"
        case productYearly = "product.yearly"
        case familyIncluded = "family.included"
        case lineWaiting = "line.waiting"
        case restoredTitle = "restored.title"
        case restoredBody = "restored.body"
        case restoredSharedTV = "restored.sharedTV"
        case restoredSharedTouch = "restored.sharedTouch"
        case unavailableBody = "unavailable.body"
    }

    /// The en text of `key`. Placeholders in angle brackets are filled by
    /// the formatting functions below.
    public static func text(_ key: Key) -> String {
        texts[key] ?? key.rawValue
    }

    private static let texts: [Key: String] = [
        .titleDefault: "Unlock Antenna",
        .titleLapsed: "Antenna is locked again",
        .body:
            "Antenna plays the TV sources you already have and includes no channels. One purchase unlocks every feature on iPhone, iPad, "
            + "Mac and Apple TV, for everyone in your Family Sharing group.",
        .lineLifetime: "Pay once. Yours for good.",
        .lineRenews: "Renews every year. Cancel any time.",
        .lineFreeTrial: "First <period> free, then <displayPrice> per year",
        .lineIntroPrice: "<offer displayPrice> for <period>, then <displayPrice> per year",
        .lineIntroPerPeriod: "<offer displayPrice> per <unit> for <period>, then <displayPrice> per year",
        .unitPerYear: "per year",
        .unitOneTime: "one time",
        .priceLoading: "Loading price",
        .priceUnavailable: "Price unavailable",
        .legal:
            "Yearly renews automatically until canceled in Settings. Payment is charged to your Apple Account. "
            + "Terms of Use and Privacy Policy.",
        .statusPending: "Waiting for approval. Antenna unlocks as soon as the purchase is approved.",
        .statusFailed: "The purchase did not go through. Try again.",
        .statusRestoreFailed: "Restore did not go through. Try again.",
        .statusNothingFound:
            "No purchase found for this Apple Account. If a family member bought Antenna, "
            + "check that purchase sharing is on in Family Sharing.",
        .statusOffline: "You're offline. Connect to the internet and try again.",
        .statusNotAllowed: "Purchases are turned off on this device. Check Screen Time, or ask the family organizer.",
        .statusNotInStorefront: "Antenna can't be bought in this App Store region yet.",
        .restoredLifetime: "Nothing more to pay. Your sources and favorites are where you left them.",
        .restoredYearly: "Renews on <expiresAt>. Your sources and favorites are where you left them.",
        .lapsedExpired: "Your yearly subscription ended on <date>.",
        .lapsedRevoked: "The purchase on this Apple Account was refunded or is no longer shared with you.",
        .unavailableTitle: "Can't reach the App Store",
        .productLifetime: "Lifetime",
        .productYearly: "Yearly",
        .familyIncluded: "Includes Family Sharing",
        .lineWaiting: "Waiting for the App Store…",
        .restoredTitle: "Welcome back",
        .restoredBody: "Your purchase was found for this Apple Account.",
        .restoredSharedTV: " · Shared with you through Family Sharing",
        .restoredSharedTouch: " · Family Sharing",
        .unavailableBody:
            "Check the connection and try again. If you already bought Antenna, Restore purchase finds it once the connection is back.",
    ]

    /// A line with its key, so a test can find it without reading the text.
    public struct Line: Equatable, Sendable {
        public let key: Key
        public let text: String

        public init(_ key: Key, _ text: String? = nil) {
            self.key = key
            self.text = text ?? PaywallCopy.text(key)
        }
    }

    /// The line under Yearly: the renewal sentence until eligibility for the
    /// offer is known or when there is none, else the offer with the price after it.
    public static func yearlyLine(offer: IntroOffer?, displayPrice: String) -> Line {
        guard let offer else { return Line(.lineRenews) }
        let period = offer.unit.phrase(offer.value * offer.periodCount)
        switch offer.payment {
        case .freeTrial:
            return Line(.lineFreeTrial, "First \(period) free, then \(displayPrice) per year")
        case .payUpFront:
            return Line(.lineIntroPrice, "\(offer.displayPrice) for \(period), then \(displayPrice) per year")
        case .payAsYouGo:
            let unit = offer.unit.phrase(offer.value)
            return Line(.lineIntroPerPeriod, "\(offer.displayPrice) per \(unit) for \(period), then \(displayPrice) per year")
        }
    }

    /// The note under "Welcome back".
    public static func restoredNote(_ grant: Grant, locale: Locale = .current) -> Line {
        guard grant.kind == .yearly, let end = grant.expiresAt else { return Line(.restoredLifetime) }
        return Line(.restoredYearly, "Renews on \(longDate(end, locale: locale)). Your sources and favorites are where you left them.")
    }

    /// What was found, such as "Lifetime · Family Sharing". `sharedSuffix`
    /// is `.restoredSharedTV` on Apple TV and `.restoredSharedTouch` elsewhere.
    public static func restoredKind(_ grant: Grant, sharedSuffix: Key) -> String {
        let name = text(grant.kind == .lifetime ? .productLifetime : .productYearly)
        return grant.familyShared ? name + text(sharedSuffix) : name
    }

    /// The reason line on a paywall after a lapse; nil for a user who never bought.
    public static func lapsedNote(_ lapse: Lapse, locale: Locale = .current) -> Line? {
        switch lapse {
        case .neverPurchased: nil
        case .expired(let date): Line(.lapsedExpired, "Your yearly subscription ended on \(longDate(date, locale: locale)).")
        case .revoked: Line(.lapsedRevoked)
        }
    }

    private static func longDate(_ date: Date, locale: Locale) -> String {
        var style = Date.FormatStyle(date: .long, time: .omitted)
        style.locale = locale
        return date.formatted(style)
    }
}

/// The App Store introductory offer on Yearly, as the paywall describes it.
/// The app only shows it; it keeps no trial of its own.
public struct IntroOffer: Equatable, Sendable {
    public enum Payment: Sendable {
        case freeTrial
        case payUpFront
        case payAsYouGo
    }

    public enum Unit: Sendable {
        case day, week, month, year

        /// "week" for one, "3 days" for more. The copy is English, so the
        /// unit names are too, whatever the device language.
        func phrase(_ count: Int) -> String {
            let name =
                switch self {
                case .day: "day"
                case .week: "week"
                case .month: "month"
                case .year: "year"
                }
            return count == 1 ? name : "\(count) \(name)s"
        }
    }

    public var payment: Payment
    /// The offer's own price, as the App Store gives it.
    public var displayPrice: String
    public var unit: Unit
    /// Units in one period.
    public var value: Int
    /// Periods in the offer; above one only for pay as you go.
    public var periodCount: Int

    public init(payment: Payment, displayPrice: String, unit: Unit, value: Int = 1, periodCount: Int = 1) {
        self.payment = payment
        self.displayPrice = displayPrice
        self.unit = unit
        self.value = value
        self.periodCount = periodCount
    }
}
