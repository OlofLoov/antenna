import AntennaCore
import SwiftUI

extension Paywall {
    /// iPhone, and the same column 390 pt wide centered on iPad and Mac
    /// (`iPhone-Paywall`, `iPad-Paywall`). Nothing sits behind it
    /// (design-system/nothing-shows-before-the-paywall).
    struct Touch: View {
        let state: State
        let actions: Actions

        var body: some View {
            VStack(spacing: 2) {
                ScrollView {
                    VStack(spacing: 24) {
                        TouchMark()
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
                TouchHeading(title: state.title, message: PaywallCopy.Line(.body), note: state.lapsedNote)
                VStack(spacing: 10) {
                    ForEach(state.products) { product in
                        TouchProductRow(product: product) { actions.buy(product.kind) }
                    }
                }
                .padding(.top, 4)
                if let status = state.status { StatusLine(status: status, size: 15) }
                Label(PaywallCopy.text(.familyIncluded), systemImage: "person.2")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.textMuted)
                    .accessibilityIdentifier("paywall.familyNote")
            case .unavailable(let reason):
                TouchHeading(title: state.title, message: PaywallCopy.Line(.body), note: state.lapsedNote)
                TouchUnavailable(reason: reason, status: state.status)
            case .restored(let grant):
                TouchHeading(title: PaywallCopy.Line(.restoredTitle), message: PaywallCopy.Line(.restoredBody), note: nil)
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

    private struct TouchMark: View {
        var body: some View {
            Image(systemName: Paywall.mark)
                .font(.system(size: 40))
                .frame(width: 88, height: 88)
                .background(Paywall.markTile, in: RoundedRectangle(cornerRadius: 22))
                .accessibilityHidden(true)
        }
    }

    private struct TouchHeading: View {
        let title: PaywallCopy.Line
        let message: PaywallCopy.Line
        let note: PaywallCopy.Line?

        var body: some View {
            VStack(spacing: 10) {
                Text(title.text)
                    .font(.system(size: 34, weight: .heavy))
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("paywall.title")
                    .modifier(Paywall.CopyKey(key: title.key))
                if let note { LapsedNote(line: note, size: 15) }
                Text(message.text)
                    .font(.system(size: 17))
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
        let product: Product
        let buy: () -> Void

        var body: some View {
            Button(action: buy) {
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(product.name).font(.system(size: 17, weight: .semibold))
                        Text(product.purchasing ? PaywallCopy.text(.lineWaiting) : product.line.text)
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    if product.purchasing {
                        ProgressView().tint(Palette.text)
                    } else {
                        VStack(alignment: .trailing, spacing: 2) {
                            PriceText(price: product.price)
                                .font(.system(size: 17, weight: .bold))
                            Text(product.unit).font(.system(size: 12)).foregroundStyle(Palette.textMuted)
                        }
                    }
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .frame(minHeight: 72)
                .background(Palette.surface(0.06), in: RoundedRectangle(cornerRadius: 14))
                .contentShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .disabled(!product.enabled)
            .opacity(product.enabled || product.purchasing ? 1 : 0.4)
            .accessibilityIdentifier(product.identifier)
            .accessibilityValue(product.accessibilityValue)
        }
    }

    /// The App Store's price as given, a placeholder while it loads, or
    /// "Price unavailable".
    struct PriceText: View {
        let price: Price

        var body: some View {
            switch price {
            case .shown(let text): Text(text)
            case .loading:
                Text("$00.00").redacted(reason: .placeholder).accessibilityLabel(PaywallCopy.text(.priceLoading))
            case .unavailable:
                Text(PaywallCopy.text(.priceUnavailable)).foregroundStyle(Palette.textMuted)
            }
        }
    }

    private struct TouchUnavailable: View {
        let reason: Unavailable
        let status: PaywallStatus?

        var body: some View {
            VStack(spacing: 10) {
                Image(systemName: reason == .notSold ? "storefront" : "wifi.exclamationmark")
                    .font(.system(size: 20))
                    .frame(width: 44, height: 44)
                    .background(Palette.surface(0.1), in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityHidden(true)
                Text(PaywallCopy.text(.unavailableTitle))
                    .font(.system(size: 17, weight: .semibold))
                    .accessibilityIdentifier("paywall.unavailable.title")
                if let status {
                    StatusLine(status: status, size: 15)
                } else {
                    Text(PaywallCopy.text(reason == .notSold ? .statusNotInStorefront : .unavailableBody))
                        .font(.system(size: 15))
                        .foregroundStyle(Palette.textMuted)
                        .multilineTextAlignment(.center)
                        .modifier(Paywall.CopyKey(key: reason == .notSold ? .statusNotInStorefront : .unavailableBody))
                        .accessibilityIdentifier("paywall.unavailable.body")
                }
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(Palette.surface(0.06), in: RoundedRectangle(cornerRadius: 14))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("paywall.unavailable")
        }
    }

    private struct TouchRestored: View {
        let grant: Grant

        var body: some View {
            HStack(spacing: 14) {
                Image(systemName: "checkmark")
                    .font(.system(size: 18, weight: .bold))
                    .frame(width: 40, height: 40)
                    .background(Palette.surface(0.1), in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(PaywallCopy.restoredKind(grant, sharedSuffix: .restoredSharedTouch))
                        .font(.system(size: 17, weight: .semibold))
                        .accessibilityIdentifier("paywall.restored.kind")
                    let note = PaywallCopy.restoredNote(grant)
                    Text(note.text)
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.textMuted)
                        .modifier(Paywall.CopyKey(key: note.key))
                        .accessibilityIdentifier("paywall.restored.note")
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(Palette.surface(0.06), in: RoundedRectangle(cornerRadius: 14))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("paywall.restored")
        }
    }

    private struct TouchLegal: View {
        let links: PaywallLinks

        var body: some View {
            Text(links.legal)
                .font(.system(size: 12))
                .foregroundStyle(Palette.textMuted)
                .multilineTextAlignment(.center)
                .padding(.top, 6)
                .accessibilityIdentifier("paywall.legal")
        }
    }

    private struct PrimaryButton: View {
        let title: String
        let identifier: String
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .foregroundStyle(Palette.ground)
                    .background(Palette.text, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(identifier)
        }
    }

    private struct QuietButton: View {
        let title: String
        let identifier: String
        let action: () -> Void

        var body: some View {
            Button(title, action: action)
                .font(.system(size: 15))
                .foregroundStyle(Palette.textMuted)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
                .buttonStyle(.plain)
                .accessibilityIdentifier(identifier)
        }
    }
}

extension Paywall.Product {
    /// The price, and in debug builds the line's copy key, for VoiceOver and UI tests.
    var accessibilityValue: String {
        let price: String =
            switch self.price {
            case .shown(let text): "\(text) \(unit)"
            case .loading: PaywallCopy.text(.priceLoading)
            case .unavailable: PaywallCopy.text(.priceUnavailable)
            }
        #if DEBUG
            return "\(price), \(purchasing ? PaywallCopy.Key.lineWaiting.rawValue : line.key.rawValue)"
        #else
            return "\(price), \(purchasing ? PaywallCopy.text(.lineWaiting) : line.text)"
        #endif
    }
}
