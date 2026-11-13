import AntennaCore
import SwiftUI

/// The pieces the add-source form is built from besides its rows.
extension OnboardingForm {
    /// The clipboard offer on iPhone, iPad and Mac, a section with one
    /// button row: "Fill in from the copied link", or "No link on the
    /// clipboard" after Fill in found none (first-run-onboarding/fill-the-form-from-a-copied-link).
    struct ClipboardRow: View {
        let offer: ClipboardOffer
        let fillIn: () -> Void

        var body: some View {
            Section {
                if offer == .link {
                    Button(action: fillIn) {
                        Label("Fill in from the copied link", systemImage: "doc.on.clipboard")
                    }
                    .accessibilityIdentifier("onboarding.fillIn")
                } else {
                    Label("No link on the clipboard", systemImage: "doc.on.clipboard")
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text(
                    offer == .link ? "Antenna reads the clipboard only when you tap Fill in." : "Type the details from your provider above."
                )
                .accessibilityIdentifier("onboarding.clipboard")
            }
        }
    }

    /// The card about the keyboard an iPhone nearby offers, beside the
    /// Apple TV form. It describes the system offer and claims nothing
    /// Antenna does.
    struct TypeOnPhoneCard: View {
        var body: some View {
            HStack(alignment: .top, spacing: Metrics.Spacing.xLarge) {
                Image(systemName: "iphone")
                    .font(.title2)
                    .frame(width: 96, height: 96)
                    .background(Palette.surface(0.1), in: Metrics.Corner.medium.shape())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Metrics.Spacing.small) {
                    Text("Easier to type on iPhone")
                        .font(.callout.weight(.semibold))
                    Text(
                        "An unlocked iPhone or iPad nearby offers its keyboard for this Apple TV. Tap that notification and the fields "
                            + "fill in here as you type. Or add the source in Antenna on iPhone and it syncs over."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    Text("The offer comes from iOS and needs no setup.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(Metrics.Spacing.xLarge)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: Metrics.Corner.large.shape())
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("onboarding.keyboardCard")
        }
    }
}
