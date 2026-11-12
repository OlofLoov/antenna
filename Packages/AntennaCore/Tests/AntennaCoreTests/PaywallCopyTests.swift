import AntennaCore
import Foundation
import Testing

/// The paywall's wording: no provider, channel count or content, and the offer lines.
@Suite struct PaywallCopyTests {
    @Test("paywall-and-entitlement/honest-paywall-wording no line names a provider, a channel count or content")
    func honest() throws {
        let channelCount = try Regex("[0-9][0-9,.]*\\s+channels").ignoresCase()
        for key in PaywallCopy.Key.allCases {
            let text = PaywallCopy.text(key)
            let lower = text.lowercased()
            #expect(text != key.rawValue, "\(key.rawValue) has its text")
            #expect(!lower.contains("iptv"), "\(key.rawValue)")
            #expect(!lower.contains("provider"), "\(key.rawValue)")
            #expect(text.firstMatch(of: channelCount) == nil, "\(key.rawValue)")
            #expect(!lower.contains("playlist"), "\(key.rawValue)")
            if key != .lineFreeTrial { #expect(!lower.contains("free"), "\(key.rawValue)") }
            for vendor in ["xtream", "stalker", "tivimate", "netflix", "sky", "espn", "bein", "dazn"] {
                #expect(!lower.contains(vendor), "\(key.rawValue) names \(vendor)")
            }
        }
        #expect(PaywallCopy.text(.body).contains("includes no channels"))
        #expect(PaywallCopy.text(.legal).contains("Terms of Use"))
        #expect(PaywallCopy.text(.legal).contains("Privacy Policy"))
        #expect(PaywallCopy.text(.legal).contains("renews automatically until canceled"))
    }

    @Test("paywall-and-entitlement/prices-come-from-the-app-store Yearly describes its offer with the App Store's prices")
    func yearlyLine() {
        #expect(PaywallCopy.yearlyLine(offer: nil, displayPrice: "$9.99") == PaywallCopy.Line(.lineRenews))
        let week = PaywallCopy.yearlyLine(offer: IntroOffer(payment: .freeTrial, displayPrice: "$0.00", unit: .week), displayPrice: "$9.99")
        #expect(week.key == .lineFreeTrial)
        #expect(week.text == "First week free, then $9.99 per year")
        let days = PaywallCopy.yearlyLine(
            offer: IntroOffer(payment: .freeTrial, displayPrice: "$0.00", unit: .day, value: 3), displayPrice: "9,99 €")
        #expect(days.text.hasPrefix("First 3 days free"))
        #expect(days.text.hasSuffix("9,99 € per year"), "the price exactly as given")
        let monthly = PaywallCopy.yearlyLine(
            offer: IntroOffer(payment: .payAsYouGo, displayPrice: "$0.99", unit: .month, periodCount: 3), displayPrice: "$9.99")
        #expect(monthly.key == .lineIntroPerPeriod)
        #expect(monthly.text.hasPrefix("$0.99 per month for 3 months"))
        let upFront = PaywallCopy.yearlyLine(
            offer: IntroOffer(payment: .payUpFront, displayPrice: "$1.99", unit: .month, value: 6), displayPrice: "$9.99")
        #expect(upFront.text == "$1.99 for 6 months, then $9.99 per year")
    }

    @Test("paywall-and-entitlement/restore-your-purchase the restored note names what was found")
    func restored() {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let lifetime = Grant(kind: .lifetime, familyShared: true, verifiedAt: date)
        #expect(PaywallCopy.restoredNote(lifetime).key == .restoredLifetime)
        #expect(PaywallCopy.restoredKind(lifetime, sharedSuffix: .restoredSharedTouch) == "Lifetime · Family Sharing")
        #expect(PaywallCopy.restoredKind(lifetime, sharedSuffix: .restoredSharedTV) == "Lifetime · Shared with you through Family Sharing")
        let yearly = Grant(kind: .yearly, expiresAt: date, verifiedAt: date)
        #expect(PaywallCopy.restoredKind(yearly, sharedSuffix: .restoredSharedTouch) == "Yearly")
        let note = PaywallCopy.restoredNote(yearly, locale: Locale(identifier: "en_US"))
        #expect(note.key == .restoredYearly)
        #expect(note.text.hasPrefix("Renews on January 15, 2027."))
    }

    @Test("paywall-and-entitlement/when-access-ends-the-app-locks-and-keeps-your-data the lapsed note gives the reason and date")
    func lapsed() {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(PaywallCopy.lapsedNote(.neverPurchased) == nil)
        let expired = PaywallCopy.lapsedNote(.expired(on: date), locale: Locale(identifier: "en_US"))
        #expect(expired == PaywallCopy.Line(.lapsedExpired, "Your yearly subscription ended on January 15, 2027."))
        #expect(PaywallCopy.lapsedNote(.revoked)?.key == .lapsedRevoked)
    }
}
