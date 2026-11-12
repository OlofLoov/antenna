import AntennaCore
import SwiftUI

/// The paywall (paywall-and-entitlement capability; boards `iPhone-Paywall`,
/// `iPad-Paywall` and `TV-Paywall` with their Purchasing, Restored and
/// Unavailable states). `Touch` is the column on iPhone, iPad and Mac,
/// `Television` the Apple TV layout. Both read one `State` and fire `Actions`.
enum Paywall {
    /// What the App Store said, as the paywall arranges it.
    enum Phase: Equatable {
        /// The product rows, with their prices or a placeholder.
        case offer
        /// The App Store did not answer, or the products are not sold here.
        case unavailable(Unavailable)
        /// Restore found a purchase; "Welcome back" until Continue.
        case restored(Grant)
    }

    enum Unavailable: Equatable {
        case unreachable
        case notSold
    }

    /// A product's price slot.
    enum Price: Equatable {
        case loading
        /// The App Store did not answer on a paywall after a lapse.
        case unavailable
        case shown(String)
    }

    /// One product row or card.
    struct Product: Equatable, Identifiable {
        var kind: ProductKind
        var price: Price
        var line: PaywallCopy.Line
        /// This product's purchase is running.
        var purchasing: Bool
        /// Another purchase or a restore is running, or purchases are off.
        var enabled: Bool

        var id: ProductKind { kind }
        var name: String { PaywallCopy.text(kind == .lifetime ? .productLifetime : .productYearly) }
        var unit: String { PaywallCopy.text(kind == .lifetime ? .unitOneTime : .unitPerYear) }
        var identifier: String { "paywall.product.\(kind.rawValue)" }
    }

    struct State: Equatable {
        var phase: Phase
        var title: PaywallCopy.Line
        var lapsedNote: PaywallCopy.Line?
        var products: [Product]
        var status: PaywallStatus?
        /// Restore can start: nothing else runs.
        var canRestore: Bool
        var links: PaywallLinks
    }

    struct Actions {
        var buy: (ProductKind) -> Void
        var restore: () -> Void
        var retry: () -> Void
        var finish: () -> Void
        var redeem: () -> Void
    }

    static let body = Color(red: 0xD7 / 255, green: 0xDE / 255, blue: 0xE8 / 255)
    static let markTile = Color(red: 0x1E / 255, green: 0x3A / 255, blue: 0x5F / 255)
    /// An error line uses the live-dot color, as the design-system reference says.
    static let errorText = Color(red: 0xFF / 255, green: 0x5F / 255, blue: 0x57 / 255)
    static let mutedOnFocus = Color(red: 0x4B / 255, green: 0x55 / 255, blue: 0x63 / 255)
    static let mark = "antenna.radiowaves.left.and.right"

    /// The status line, muted or in the error color. Debug builds expose
    /// its copy key as the accessibility value for UI tests.
    struct StatusLine: View {
        let status: PaywallStatus
        let size: CGFloat

        var body: some View {
            Text(status.text)
                .font(.system(size: size))
                .foregroundStyle(status.isError ? Paywall.errorText : Palette.textMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("paywall.status")
                .modifier(CopyKey(key: status.key))
        }
    }

    /// The lapsed reason under the body.
    struct LapsedNote: View {
        let line: PaywallCopy.Line
        let size: CGFloat

        var body: some View {
            Text(line.text)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(Paywall.body)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("paywall.lapsedNote")
                .modifier(CopyKey(key: line.key))
        }
    }

    /// Sets the copy key as the accessibility value in debug builds only.
    struct CopyKey: ViewModifier {
        let key: PaywallCopy.Key

        func body(content: Content) -> some View {
            #if DEBUG
                content.accessibilityValue(key.rawValue)
            #else
                content
            #endif
        }
    }
}

/// The Terms of Use and Privacy Policy addresses, from the Info.plist keys
/// `AntennaTermsURL` and `AntennaPrivacyURL`
/// (paywall-and-entitlement/honest-paywall-wording).
struct PaywallLinks: Equatable {
    var terms: URL?
    var privacy: URL?

    static let fixture = PaywallLinks(
        terms: URL(string: "https://codecrave.se/antenna/terms"), privacy: URL(string: "https://codecrave.se/antenna/privacy"))

    /// A missing or bad value stops a debug build and reads as nil in release,
    /// where the legal line then shows the words without a link.
    static func load(from bundle: Bundle = .main) -> PaywallLinks {
        PaywallLinks(terms: url(bundle, "AntennaTermsURL"), privacy: url(bundle, "AntennaPrivacyURL"))
    }

    private static func url(_ bundle: Bundle, _ key: String) -> URL? {
        guard let text = bundle.object(forInfoDictionaryKey: key) as? String, let url = URL(string: text), url.scheme == "https" else {
            assertionFailure("Info.plist needs an https address under \(key)")
            return nil
        }
        return url
    }

    /// The legal line with "Terms of Use" and "Privacy Policy" as links.
    var legal: AttributedString {
        var text = AttributedString(PaywallCopy.text(.legal))
        for (words, url) in [("Terms of Use", terms), ("Privacy Policy", privacy)] {
            guard let url, let range = text.range(of: words) else { continue }
            text[range].link = url
            text[range].foregroundColor = Palette.accent
        }
        return text
    }

    /// The legal line on Apple TV, which has no browser: the addresses as text.
    var legalWithAddresses: String {
        let renewal = PaywallCopy.text(.legal).replacingOccurrences(of: " Terms of Use and Privacy Policy.", with: "")
        let parts = [("Terms", terms), ("Privacy", privacy)].compactMap { name, url in url.map { "\(name): \(Self.short($0))." } }
        return ([renewal] + parts).joined(separator: " ")
    }

    private static func short(_ url: URL) -> String {
        (url.host() ?? "") + url.path()
    }
}
