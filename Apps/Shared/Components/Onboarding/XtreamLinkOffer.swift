import SwiftUI

/// The offer under a playlist link that is an Xtream login, with Use Xtream
/// (`iPhone-Onboard-2-XtreamLink`, `TV-Onboard-3-XtreamLink`;
/// source-management/the-add-form-offers-xtream-for-a-panel-link).
enum XtreamLinkOffer {
    static let message = "This link is an Xtream login. Add it as Xtream to get Movies, Series and the guide."
    static let button = "Use Xtream"

    /// iPhone, and the sheet on iPad and Mac: the clipboard banner's tinted card.
    struct Phone: View {
        let useXtream: () -> Void

        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: "film.stack")
                    .foregroundStyle(Palette.accent)
                    .accessibilityHidden(true)
                Text(XtreamLinkOffer.message)
                    .font(.system(size: 15))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button(XtreamLinkOffer.button, action: useXtream)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                    .foregroundStyle(Palette.ground)
                    .background(Palette.accent, in: RoundedRectangle(cornerRadius: 8))
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("onboarding.useXtream")
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(Palette.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("onboarding.xtreamOffer")
        }
    }

    /// Apple TV: the sentence and a focusable Use Xtream button under the fields.
    struct Television: View {
        let useXtream: () -> Void

        var body: some View {
            HStack(spacing: 24) {
                Image(systemName: "film.stack")
                    .font(.system(size: 30))
                    .foregroundStyle(Palette.accent)
                    .accessibilityHidden(true)
                Text(XtreamLinkOffer.message)
                    .font(.system(size: 24))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button(XtreamLinkOffer.button, action: useXtream)
                    .accessibilityIdentifier("onboarding.useXtream")
            }
            .padding(.vertical, 18)
            .padding(.horizontal, 24)
            .background(Palette.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("onboarding.xtreamOffer")
        }
    }
}

#Preview("Xtream link offer, iPhone") {
    XtreamLinkOffer.Phone {}
        .padding(16)
        .background(Palette.ground)
        .foregroundStyle(Palette.text)
}

#if os(tvOS)
    #Preview("Xtream link offer, Apple TV", traits: .fixedLayout(width: 820, height: 200)) {
        XtreamLinkOffer.Television {}
            .padding(24)
            .background(Palette.ground)
            .foregroundStyle(Palette.text)
    }
#endif
