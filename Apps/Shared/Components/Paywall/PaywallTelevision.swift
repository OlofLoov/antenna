import AntennaCore
import SwiftUI

extension Paywall {
    /// Apple TV (`TV-Paywall`): the wordmark top left, title and body, two
    /// product cards side by side, Restore purchase, and the legal line with
    /// the addresses as text at the bottom. No offer codes on Apple TV.
    struct Television: View {
        @Environment(\.locale) private var locale
        let state: State
        let actions: Actions

        var body: some View {
            VStack(spacing: 44) {
                switch state.phase {
                case .offer:
                    TelevisionHeading(title: state.title, message: PaywallCopy.Line(.body, locale: locale), note: state.lapsedNote)
                    HStack(spacing: 32) {
                        ForEach(state.products) { product in
                            Button {
                                actions.buy(product.kind)
                            } label: {
                                TelevisionCardLabel(product: product)
                            }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.roundedRectangle(radius: 20))
                            .disabled(!product.enabled)
                            .accessibilityIdentifier(product.identifier)
                            .accessibilityValue(product.accessibilityValue(locale))
                        }
                    }
                    if let status = state.status { StatusLine(status: status, size: 22) }
                    Button("Restore purchase", action: actions.restore)
                        .font(.boardStyle(24))
                        .buttonStyle(.borderless)
                        .disabled(!state.canRestore)
                        .accessibilityIdentifier("paywall.restore")
                case .unavailable(let reason):
                    TelevisionHeading(title: state.title, message: PaywallCopy.Line(.body, locale: locale), note: state.lapsedNote)
                    TelevisionUnavailable(reason: reason, status: state.status, canAct: state.canRestore, actions: actions)
                case .restored(let grant):
                    TelevisionHeading(
                        title: PaywallCopy.Line(.restoredTitle, locale: locale), message: PaywallCopy.Line(.restoredBody, locale: locale),
                        note: nil)
                    TelevisionRestored(grant: grant)
                    Button("Continue", action: actions.finish)
                        .font(.boardStyle(28, weight: .bold))
                        .primaryActionStyle()
                        .accessibilityIdentifier("paywall.continue")
                }
            }
            .foregroundStyle(Palette.text)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .topLeading) {
                Label("Antenna", systemImage: Paywall.mark)
                    .font(.boardStyle(26, weight: .bold))
                    .padding(.leading, 64)
                    .padding(.top, 44)
                    .accessibilityHidden(true)
            }
            .overlay(alignment: .bottom) {
                if !state.phase.isRestored {
                    Text(state.links.legalWithAddresses(locale))
                        .font(.boardStyle(20))
                        .foregroundStyle(Palette.textMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 160)
                        .padding(.bottom, 56)
                        .accessibilityIdentifier("paywall.legal")
                }
            }
            .background(Palette.ground)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("paywall.root")
        }
    }

    private struct TelevisionHeading: View {
        let title: PaywallCopy.Line
        let message: PaywallCopy.Line
        let note: PaywallCopy.Line?

        var body: some View {
            VStack(spacing: 16) {
                Text(title.text)
                    .font(.boardStyle(64, weight: .heavy))
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("paywall.title")
                    .modifier(Paywall.CopyKey(key: title.key))
                if let note { LapsedNote(line: note, size: 26) }
                Text(message.text)
                    .font(.boardStyle(30))
                    .foregroundStyle(Paywall.body)
                    .accessibilityIdentifier("paywall.body")
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: 1072)
        }
    }

    /// A product card: kind, price with unit, the line, and Family Sharing at the bottom.
    private struct TelevisionCardLabel: View {
        @Environment(\.locale) private var locale
        let product: Product
        @Environment(\.isFocused) private var isFocused

        var body: some View {
            VStack(alignment: .leading, spacing: 18) {
                Text(product.name(locale).uppercased())
                    .font(.boardStyle(20, weight: .semibold))
                    .letterSpacing(1)
                    .foregroundStyle(muted)
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    PriceText(price: product.price).font(.boardStyle(56, weight: .heavy))
                    if product.kind == .yearly {
                        Text(product.unit(locale)).font(.boardStyle(26)).foregroundStyle(muted)
                    }
                }
                HStack(spacing: 12) {
                    if product.purchasing { ProgressView() }
                    Text(product.purchasing ? PaywallCopy.text(.lineWaiting, locale: locale) : product.line.text)
                        .font(.boardStyle(23))
                        .foregroundStyle(isFocused ? Paywall.mutedOnFocus : Paywall.body)
                }
                Spacer(minLength: 0)
                Label(PaywallCopy.text(.familyIncluded, locale: locale), systemImage: "person.2")
                    .font(.boardStyle(20))
                    .foregroundStyle(muted)
            }
            .padding(40)
            .frame(width: 520, height: 400, alignment: .topLeading)
        }

        private var muted: Color { isFocused ? Paywall.mutedOnFocus : Palette.textMuted }
    }

    private struct TelevisionUnavailable: View {

        @Environment(\.locale) private var locale
        let reason: Unavailable
        let status: PaywallStatus?
        let canAct: Bool
        let actions: Actions

        var body: some View {
            VStack(spacing: 18) {
                Image(systemName: reason == .notSold ? "storefront" : "wifi.exclamationmark")
                    .font(.boardStyle(36))
                    .frame(width: 80, height: 80)
                    .background(Palette.surface(0.1), in: RoundedRectangle(cornerRadius: 20))
                    .accessibilityHidden(true)
                Text(PaywallCopy.text(.unavailableTitle, locale: locale))
                    .font(.boardStyle(34, weight: .bold))
                    .accessibilityIdentifier("paywall.unavailable.title")
                if let status {
                    StatusLine(status: status, size: 22)
                } else {
                    Text(PaywallCopy.text(reason == .notSold ? .statusNotInStorefront : .unavailableBody, locale: locale))
                        .font(.boardStyle(24))
                        .foregroundStyle(Paywall.body)
                        .multilineTextAlignment(.center)
                        .modifier(Paywall.CopyKey(key: reason == .notSold ? .statusNotInStorefront : .unavailableBody))
                        .accessibilityIdentifier("paywall.unavailable.body")
                }
                HStack(spacing: 24) {
                    if reason == .unreachable {
                        Button("Try again", action: actions.retry)
                            .font(.boardStyle(28, weight: .bold))
                            .primaryActionStyle()
                            .disabled(!canAct)
                            .accessibilityIdentifier("paywall.retry")
                    }
                    Button("Restore purchase", action: actions.restore)
                        .font(.boardStyle(28, weight: .bold))
                        .primaryActionStyle()
                        .disabled(!canAct)
                        .accessibilityIdentifier("paywall.restore")
                }
                .padding(.top, 8)
            }
            .padding(40)
            .frame(width: 1072)
            .background(Palette.surface(0.08), in: RoundedRectangle(cornerRadius: 20))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("paywall.unavailable")
        }
    }

    private struct TelevisionRestored: View {

        @Environment(\.locale) private var locale
        let grant: Grant

        var body: some View {
            HStack(spacing: 28) {
                Image(systemName: "checkmark")
                    .font(.boardStyle(32, weight: .bold))
                    .frame(width: 72, height: 72)
                    .background(Palette.surface(0.1), in: RoundedRectangle(cornerRadius: 20))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(PaywallCopy.restoredKind(grant, sharedSuffix: .restoredSharedTV, locale: locale))
                        .font(.boardStyle(29, weight: .semibold))
                        .accessibilityIdentifier("paywall.restored.kind")
                    let note = PaywallCopy.restoredNote(grant, locale: locale)
                    Text(note.text)
                        .font(.boardStyle(23))
                        .foregroundStyle(Palette.textMuted)
                        .modifier(Paywall.CopyKey(key: note.key))
                        .accessibilityIdentifier("paywall.restored.note")
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 36)
            .padding(.horizontal, 40)
            .frame(width: 1072)
            .background(Palette.surface(0.08), in: RoundedRectangle(cornerRadius: 20))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("paywall.restored")
        }
    }
}

extension Paywall.Phase {
    /// Whether this is "Welcome back", which has no legal line.
    fileprivate var isRestored: Bool {
        if case .restored = self { return true }
        return false
    }
}
