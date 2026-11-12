import AntennaCore
import SwiftUI

extension Paywall {
    /// Apple TV (`TV-Paywall`): the wordmark top left, title and body, two
    /// product cards side by side, Restore purchase, and the legal line with
    /// the addresses as text at the bottom. No offer codes on Apple TV.
    struct Television: View {
        let state: State
        let actions: Actions

        var body: some View {
            VStack(spacing: 44) {
                switch state.phase {
                case .offer:
                    TelevisionHeading(title: state.title, message: PaywallCopy.Line(.body), note: state.lapsedNote)
                    HStack(spacing: 32) {
                        ForEach(state.products) { product in
                            Button {
                                actions.buy(product.kind)
                            } label: {
                                TelevisionCardLabel(product: product)
                            }
                            .buttonStyle(CardStyle())
                            .disabled(!product.enabled)
                            .accessibilityIdentifier(product.identifier)
                            .accessibilityValue(product.accessibilityValue)
                        }
                    }
                    if let status = state.status { StatusLine(status: status, size: 22) }
                    Button("Restore purchase", action: actions.restore)
                        .buttonStyle(OnboardingStyle.QuietTV())
                        .disabled(!state.canRestore)
                        .accessibilityIdentifier("paywall.restore")
                case .unavailable(let reason):
                    TelevisionHeading(title: state.title, message: PaywallCopy.Line(.body), note: state.lapsedNote)
                    TelevisionUnavailable(reason: reason, status: state.status, canAct: state.canRestore, actions: actions)
                case .restored(let grant):
                    TelevisionHeading(title: PaywallCopy.Line(.restoredTitle), message: PaywallCopy.Line(.restoredBody), note: nil)
                    TelevisionRestored(grant: grant)
                    Button("Continue", action: actions.finish)
                        .buttonStyle(OnboardingStyle.PrimaryTV())
                        .accessibilityIdentifier("paywall.continue")
                }
            }
            .foregroundStyle(Palette.text)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .topLeading) {
                Label("Antenna", systemImage: Paywall.mark)
                    .font(.system(size: 26, weight: .bold))
                    .padding(.leading, 64)
                    .padding(.top, 44)
                    .accessibilityHidden(true)
            }
            .overlay(alignment: .bottom) {
                if !state.phase.isRestored {
                    Text(state.links.legalWithAddresses)
                        .font(.system(size: 20))
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
                    .font(.system(size: 64, weight: .heavy))
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("paywall.title")
                    .modifier(Paywall.CopyKey(key: title.key))
                if let note { LapsedNote(line: note, size: 26) }
                Text(message.text)
                    .font(.system(size: 30))
                    .foregroundStyle(Paywall.body)
                    .accessibilityIdentifier("paywall.body")
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: 1072)
        }
    }

    /// A product card: kind, price with unit, the line, and Family Sharing at the bottom.
    private struct TelevisionCardLabel: View {
        let product: Product
        @Environment(\.isFocused) private var isFocused

        var body: some View {
            VStack(alignment: .leading, spacing: 18) {
                Text(product.name.uppercased())
                    .font(.system(size: 20, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(muted)
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    PriceText(price: product.price).font(.system(size: 56, weight: .heavy))
                    if product.kind == .yearly {
                        Text(product.unit).font(.system(size: 26)).foregroundStyle(muted)
                    }
                }
                HStack(spacing: 12) {
                    if product.purchasing { ProgressView() }
                    Text(product.purchasing ? PaywallCopy.text(.lineWaiting) : product.line.text)
                        .font(.system(size: 23))
                        .foregroundStyle(isFocused ? Paywall.mutedOnFocus : Paywall.body)
                }
                Spacer(minLength: 0)
                Label(PaywallCopy.text(.familyIncluded), systemImage: "person.2")
                    .font(.system(size: 20))
                    .foregroundStyle(muted)
            }
            .padding(40)
            .frame(width: 520, height: 400, alignment: .topLeading)
        }

        private var muted: Color { isFocused ? Paywall.mutedOnFocus : Palette.textMuted }
    }

    /// The lifted white card while focused, the 0.08 surface otherwise
    /// (design-system/focus-is-the-lifted-white-card).
    private struct CardStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            CardBody(label: configuration.label)
        }

        private struct CardBody<Label: View>: View {
            let label: Label
            @Environment(\.isFocused) private var isFocused
            @Environment(\.isEnabled) private var isEnabled

            var body: some View {
                label
                    .foregroundStyle(isFocused ? Palette.ground : Palette.text)
                    .background {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(isFocused ? Palette.focus : Palette.surface(0.08))
                            .shadow(color: isFocused ? Palette.focusShadow : .clear, radius: 22, y: 16)
                    }
                    .scaleEffect(isFocused ? 1.04 : 1)
                    .opacity(isEnabled || isFocused ? 1 : 0.4)
            }
        }
    }

    private struct TelevisionUnavailable: View {
        let reason: Unavailable
        let status: PaywallStatus?
        let canAct: Bool
        let actions: Actions

        var body: some View {
            VStack(spacing: 18) {
                Image(systemName: reason == .notSold ? "storefront" : "wifi.exclamationmark")
                    .font(.system(size: 36))
                    .frame(width: 80, height: 80)
                    .background(Palette.surface(0.1), in: RoundedRectangle(cornerRadius: 20))
                    .accessibilityHidden(true)
                Text(PaywallCopy.text(.unavailableTitle))
                    .font(.system(size: 34, weight: .bold))
                    .accessibilityIdentifier("paywall.unavailable.title")
                if let status {
                    StatusLine(status: status, size: 22)
                } else {
                    Text(PaywallCopy.text(reason == .notSold ? .statusNotInStorefront : .unavailableBody))
                        .font(.system(size: 24))
                        .foregroundStyle(Paywall.body)
                        .multilineTextAlignment(.center)
                        .modifier(Paywall.CopyKey(key: reason == .notSold ? .statusNotInStorefront : .unavailableBody))
                        .accessibilityIdentifier("paywall.unavailable.body")
                }
                HStack(spacing: 24) {
                    if reason == .unreachable {
                        Button("Try again", action: actions.retry)
                            .buttonStyle(OnboardingStyle.PrimaryTV())
                            .disabled(!canAct)
                            .accessibilityIdentifier("paywall.retry")
                    }
                    Button("Restore purchase", action: actions.restore)
                        .buttonStyle(OnboardingStyle.PrimaryTV())
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
        let grant: Grant

        var body: some View {
            HStack(spacing: 28) {
                Image(systemName: "checkmark")
                    .font(.system(size: 32, weight: .bold))
                    .frame(width: 72, height: 72)
                    .background(Palette.surface(0.1), in: RoundedRectangle(cornerRadius: 20))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(PaywallCopy.restoredKind(grant, sharedSuffix: .restoredSharedTV))
                        .font(.system(size: 29, weight: .semibold))
                        .accessibilityIdentifier("paywall.restored.kind")
                    let note = PaywallCopy.restoredNote(grant)
                    Text(note.text)
                        .font(.system(size: 23))
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
