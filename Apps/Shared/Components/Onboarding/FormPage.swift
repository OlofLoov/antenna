import SwiftUI

/// The Apple TV page for typing a source in (`TV-Onboard-3`): the title,
/// one line and `card` on the left, and on the right the field rows in a
/// system `Form`, the footer, the error, and the buttons lined up under the
/// fields. It paints no background: the presenter gives a cover its
/// `CoverBackdrop`, and onboarding shows the system's own. It keeps to the
/// safe area the system gives it, 60 pt top and bottom and 80 pt at the
/// sides, with room on the right for a focused row to grow
/// (design-system/forms-use-the-platform-form-style,
/// design-system/apple-tv-content-stays-in-the-safe-area).
enum FormPage {
    struct Television<Card: View, Rows: View, Buttons: View>: View {
        let title: String
        let line: String
        /// Under the rows, such as where the login is kept.
        var footer: String?
        var error: String?
        @ViewBuilder var card: Card
        /// `Section`s of `FieldRow`s.
        @ViewBuilder var rows: Rows
        /// The row of buttons under the footer: Connect first, then Cancel.
        @ViewBuilder var buttons: Buttons

        var body: some View {
            HStack(alignment: .top, spacing: Metrics.Spacing.xxxxLarge) {
                VStack(alignment: .leading, spacing: Metrics.Spacing.large) {
                    Text(title)
                        .font(.title3.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                    Text(line)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    card
                        .padding(.top, Metrics.Spacing.large)
                }
                .frame(width: 680, alignment: .leading)
                Form {
                    rows
                    if footer != nil || error != nil {
                        Section {
                        } footer: {
                            OnboardingForm.Footer(line: footer, error: error)
                                .font(.caption)
                        }
                    }
                    Section {
                        FieldRow.Indented {
                            buttons
                        }
                        .padding(.top, Metrics.Spacing.medium)
                    }
                    .listRowBackground(Color.clear)
                }
                .scrollClipDisabled()
                .padding(.trailing, Metrics.Spacing.large)
            }
            .padding(.top, Metrics.Spacing.xLarge)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}
