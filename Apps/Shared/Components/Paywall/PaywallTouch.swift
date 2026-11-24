import AntennaCore
import SwiftUI

extension Paywall {
    /// iPhone, and the same column 390 pt wide centered on iPad and Mac
    /// (`iPhone-Paywall`, `iPad-Paywall`). Nothing sits behind it
    /// (design-system/nothing-shows-before-the-paywall).
    struct Touch: View {
        @Environment(\.locale) private var locale
        let state: State
        let actions: Actions

        var body: some View {
            VStack(spacing: 2) {
                ScrollView {
                    VStack(spacing: 24) {
                        BrandMark.Letter(moment: state.phase.markPlacement.moment)
                            .frame(width: 96)
                            .accessibilityIdentifier("paywall.mark")
                        content
                    }
                    .padding(.top, 54)
                    .frame(maxWidth: .infinity)
                }
                .scrollBounceBehavior(.basedOnSize)
                footer
            }
            .foregroundStyle(Palette.text)
            .padding(.horizontal, 24)
            .padding(.bottom, 34)
            .frame(maxWidth: 438)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.ground)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("paywall.root")
        }

        @ViewBuilder private var content: some View {
            switch state.phase {
            case .offer:
                TouchHeading(title: state.title, message: PaywallCopy.Line(.body, locale: locale), note: state.lapsedNote)
                VStack(spacing: 10) {
                    ForEach(state.products) { product in
                        TouchProductRow(product: product) { actions.buy(product.kind) }
                    }
                }
                .padding(.top, 4)
                if let status = state.status { StatusLine(status: status, size: 15) }
                Label(PaywallCopy.text(.familyIncluded, locale: locale), systemImage: "person.2")
                    .font(.boardStyle(12))
                    .foregroundStyle(Palette.textMuted)
                    .accessibilityIdentifier("paywall.familyNote")
            case .unavailable(let reason):
                TouchHeading(title: state.title, message: PaywallCopy.Line(.body, locale: locale), note: state.lapsedNote)
                TouchUnavailable(reason: reason, status: state.status)
            case .restored(let grant):
                TouchHeading(
                    title: PaywallCopy.Line(.restoredTitle, locale: locale), message: PaywallCopy.Line(.restoredBody, locale: locale),
                    note: nil)
                TouchRestored(grant: grant)
            }
        }

        @ViewBuilder private var footer: some View {
            switch state.phase {
            case .offer:
                QuietButton(title: "Restore purchase", identifier: "paywall.restore", action: actions.restore)
                    .disabled(!state.canRestore)
                QuietButton(title: "Redeem a code", identifier: "paywall.redeem", action: actions.redeem)
                    .disabled(!state.canRestore)
                TouchLegal(links: state.links)
            case .unavailable(let reason):
                if reason == .unreachable {
                    PrimaryButton(title: "Try again", identifier: "paywall.retry", action: actions.retry)
                        .disabled(!state.canRestore)
                }
                QuietButton(title: "Restore purchase", identifier: "paywall.restore", action: actions.restore)
                    .disabled(!state.canRestore)
                TouchLegal(links: state.links)
            case .restored:
                PrimaryButton(title: "Continue", identifier: "paywall.continue", action: actions.finish)
            }
        }
    }

    private struct TouchHeading: View {
        let title: PaywallCopy.Line
        let message: PaywallCopy.Line
        let note: PaywallCopy.Line?

        var body: some View {
            VStack(spacing: 10) {
                Text(title.text)
                    .font(.boardStyle(34, weight: .heavy))
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("paywall.title")
                    .modifier(Paywall.CopyKey(key: title.key))
                if let note { LapsedNote(line: note, size: 15) }
                Text(message.text)
                    .font(.boardStyle(17))
                    .foregroundStyle(Paywall.body)
                    .accessibilityIdentifier("paywall.body")
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// One product: name and line on the left, price and unit on the right.
    /// While its purchase runs the line reads "Waiting for the App Store…"
    /// and a spinner takes the price's place.
    private struct TouchProductRow: View {
        @Environment(\.locale) private var locale
        let product: Product
        let buy: () -> Void

        var body: some View {
            Button(action: buy) {
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(product.name(locale)).font(.boardStyle(17, weight: .semibold))
                        Text(product.purchasing ? PaywallCopy.text(.lineWaiting, locale: locale) : product.line.text)
                            .font(.boardStyle(13))
                            .foregroundStyle(Palette.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    if product.purchasing {
                        ProgressView().tint(Palette.text)
                    } else {
                        VStack(alignment: .trailing, spacing: 2) {
                            PriceText(price: product.price)
                                .font(.boardStyle(17, weight: .bold))
                            Text(product.unit(locale)).font(.boardStyle(12)).foregroundStyle(Palette.textMuted)
                        }
                    }
                }
                .padding(.vertical, 8)
                .frame(minHeight: 60)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle(radius: 12))
            .tint(Palette.text)
            .disabled(!product.enabled)
            .opacity(product.enabled || product.purchasing ? 1 : 0.4)
            .accessibilityIdentifier(product.identifier)
            .accessibilityValue(product.accessibilityValue(locale))
        }
    }

    /// The App Store's price as given, a placeholder while it loads, or
    /// "Price unavailable".
    struct PriceText: View {
        @Environment(\.locale) private var locale
        let price: Price

        var body: some View {
            switch price {
            case .shown(let text): Text(text)
            case .loading:
                Text("$00.00").redacted(reason: .placeholder).accessibilityLabel(PaywallCopy.text(.priceLoading, locale: locale))
            case .unavailable:
                Text(PaywallCopy.text(.priceUnavailable, locale: locale)).foregroundStyle(Palette.textMuted)
            }
        }
    }

    private struct TouchUnavailable: View {

        @Environment(\.locale) private var locale
        let reason: Unavailable
        let status: PaywallStatus?

        var body: some View {
            VStack(spacing: 10) {
                Image(systemName: reason == .notSold ? "storefront" : "wifi.exclamationmark")
                    .font(.boardStyle(20))
                    .frame(width: 44, height: 44)
                    .background(Palette.surface(0.1), in: cornerShape(.medium))
                    .accessibilityHidden(true)
                Text(PaywallCopy.text(.unavailableTitle, locale: locale))
                    .font(.boardStyle(17, weight: .semibold))
                    .accessibilityIdentifier("paywall.unavailable.title")
                if let status {
                    StatusLine(status: status, size: 15)
                } else {
                    Text(PaywallCopy.text(reason == .notSold ? .statusNotInStorefront : .unavailableBody, locale: locale))
                        .font(.boardStyle(15))
                        .foregroundStyle(Palette.textMuted)
                        .multilineTextAlignment(.center)
                        .modifier(Paywall.CopyKey(key: reason == .notSold ? .statusNotInStorefront : .unavailableBody))
                        .accessibilityIdentifier("paywall.unavailable.body")
                }
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(Palette.surface(0.06), in: cornerShape(.medium))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("paywall.unavailable")
        }
    }

    private struct TouchRestored: View {

        @Environment(\.locale) private var locale
        let grant: Grant

        var body: some View {
            HStack(spacing: 14) {
                Image(systemName: "checkmark")
                    .font(.boardStyle(18, weight: .bold))
                    .frame(width: 40, height: 40)
                    .background(Palette.surface(0.1), in: cornerShape(.medium))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(PaywallCopy.restoredKind(grant, sharedSuffix: .restoredSharedTouch, locale: locale))
                        .font(.boardStyle(17, weight: .semibold))
                        .accessibilityIdentifier("paywall.restored.kind")
                    let note = PaywallCopy.restoredNote(grant, locale: locale)
                    Text(note.text)
                        .font(.boardStyle(13))
                        .foregroundStyle(Palette.textMuted)
                        .modifier(Paywall.CopyKey(key: note.key))
                        .accessibilityIdentifier("paywall.restored.note")
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(Palette.surface(0.06), in: cornerShape(.medium))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("paywall.restored")
        }
    }

    private struct TouchLegal: View {

        @Environment(\.locale) private var locale
        let links: PaywallLinks

        var body: some View {
            Text(links.legal(locale))
                .font(.boardStyle(12))
                .foregroundStyle(Palette.textMuted)
                .multilineTextAlignment(.center)
                .padding(.top, 6)
                .accessibilityIdentifier("paywall.legal")
        }
    }

    private struct PrimaryButton: View {
        let title: LocalizedStringResource
        let identifier: String
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                Text(title)
                    .font(.boardStyle(17, weight: .bold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .primaryActionStyle()
            .accessibilityIdentifier(identifier)
        }
    }

    private struct QuietButton: View {
        let title: LocalizedStringResource
        let identifier: String
        let action: () -> Void

        var body: some View {
            Button(title, action: action)
                .font(.boardStyle(15))
                .frame(maxWidth: .infinity, minHeight: 44)
                .buttonStyle(.borderless)
                .accessibilityIdentifier(identifier)
        }
    }
}

extension Paywall.Product {
    /// The price, and in debug builds the line's copy key, for VoiceOver and UI tests.
    func accessibilityValue(_ locale: Locale) -> String {
        let price: String =
            switch self.price {
            case .shown(let text): "\(text) \(unit(locale))"
            case .loading: PaywallCopy.text(.priceLoading, locale: locale)
            case .unavailable: PaywallCopy.text(.priceUnavailable, locale: locale)
            }
        #if DEBUG
            return "\(price), \(purchasing ? PaywallCopy.Key.lineWaiting.rawValue : line.key.rawValue)"
        #else
            return "\(price), \(purchasing ? PaywallCopy.text(.lineWaiting, locale: locale) : line.text)"
        #endif
    }
}
