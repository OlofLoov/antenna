import AntennaCore
import Foundation
import Testing

/// The paywall's wording: no provider, channel count or content, and the offer lines.
@Suite struct PaywallCopyTests {
    @Test("paywall-and-entitlement/honest-paywall-wording no line names a provider, a channel count or content")
    func honest() throws {
        let channelCount = try Regex("[0-9][0-9,.]*\\s+channels").ignoresCase()
        for key in PaywallCopy.Key.allCases {
            let text = PaywallCopy.text(key, locale: .english)
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
        #expect(PaywallCopy.text(.body, locale: .english).contains("includes no channels"))
        #expect(PaywallCopy.text(.legal, locale: .english).contains("Terms of Use"))
        #expect(PaywallCopy.text(.legal, locale: .english).contains("Privacy Policy"))
        #expect(PaywallCopy.text(.legal, locale: .english).contains("renews automatically until canceled"))
    }

    @Test("paywall-and-entitlement/prices-come-from-the-app-store Yearly describes its offer with the App Store's prices")
    func yearlyLine() {
        #expect(
            PaywallCopy.yearlyLine(offer: nil, displayPrice: "$9.99", locale: .english) == PaywallCopy.Line(.lineRenews, locale: .english))
        let week = PaywallCopy.yearlyLine(
            offer: IntroOffer(payment: .freeTrial, displayPrice: "$0.00", unit: .week), displayPrice: "$9.99", locale: .english)
        #expect(week.key == .lineFreeTrial)
        #expect(week.text == "First week free, then $9.99 per year")
        let days = PaywallCopy.yearlyLine(
            offer: IntroOffer(payment: .freeTrial, displayPrice: "$0.00", unit: .day, value: 3), displayPrice: "9,99 €", locale: .english)
        #expect(days.text.hasPrefix("First 3 days free"))
        #expect(days.text.hasSuffix("9,99 € per year"), "the price exactly as given")
        let monthly = PaywallCopy.yearlyLine(
            offer: IntroOffer(payment: .payAsYouGo, displayPrice: "$0.99", unit: .month, periodCount: 3), displayPrice: "$9.99",
            locale: .english)
        #expect(monthly.key == .lineIntroPerPeriod)
        #expect(monthly.text.hasPrefix("$0.99 per month for the first 3 months"))
        let upFront = PaywallCopy.yearlyLine(
            offer: IntroOffer(payment: .payUpFront, displayPrice: "$1.99", unit: .month, value: 6), displayPrice: "$9.99", locale: .english)
        #expect(upFront.text == "$1.99 for the first 6 months, then $9.99 per year")
    }

    @Test("paywall-and-entitlement/restore-your-purchase the restored note names what was found")
    func restored() {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let lifetime = Grant(kind: .lifetime, familyShared: true, verifiedAt: date)
        #expect(PaywallCopy.restoredNote(lifetime, locale: .english).key == .restoredLifetime)
        #expect(PaywallCopy.restoredKind(lifetime, sharedSuffix: .restoredSharedTouch, locale: .english) == "Lifetime · Family Sharing")
        #expect(
            PaywallCopy.restoredKind(lifetime, sharedSuffix: .restoredSharedTV, locale: .english)
                == "Lifetime · Shared with you through Family Sharing")
        let yearly = Grant(kind: .yearly, expiresAt: date, verifiedAt: date)
        #expect(PaywallCopy.restoredKind(yearly, sharedSuffix: .restoredSharedTouch, locale: .english) == "Yearly")
        let note = PaywallCopy.restoredNote(yearly, locale: .english, timeZone: .gmt)
        #expect(note.key == .restoredYearly)
        #expect(note.text.hasPrefix("Renews on January 15, 2027."))
        // The locale's calendar, not the Mac's: a Mac set to Saudi Arabic reads Hijri.
        let japanese = PaywallCopy.restoredNote(yearly, locale: Locale(identifier: "en_US@calendar=japanese"), timeZone: .gmt)
        #expect(japanese.text.contains("Reiwa") && !japanese.text.contains("2027"))
    }

    @Test("paywall-and-entitlement/when-access-ends-the-app-locks-and-keeps-your-data the lapsed note gives the reason and date")
    func lapsed() {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(PaywallCopy.lapsedNote(.neverPurchased, locale: .english) == nil)
        let expired = PaywallCopy.lapsedNote(.expired(on: date), locale: .english, timeZone: .gmt)
        #expect(expired == PaywallCopy.Line(.lapsedExpired, "Your yearly subscription ended on January 15, 2027.", locale: .english))
        #expect(PaywallCopy.lapsedNote(.revoked, locale: .english)?.key == .lapsedRevoked)
    }
}
