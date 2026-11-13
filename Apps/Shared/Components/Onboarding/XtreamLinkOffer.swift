import SwiftUI

/// The offer under a playlist link that is an Xtream login, with Use Xtream
/// (`iPhone-Onboard-2-XtreamLink`, `TV-Onboard-3-XtreamLink`;
/// source-management/the-add-form-offers-xtream-for-a-panel-link). A form
/// section with Use Xtream as its button row and the reason as its footer.
enum XtreamLinkOffer {
    static let message = "This link is an Xtream login. Add it as Xtream to get Movies, Series and the guide."
    static let button = "Use Xtream"

    /// iPhone, and the sheet on iPad and Mac.
    struct Phone: View {
        let useXtream: () -> Void

        var body: some View {
            Section {
                Button(action: useXtream) {
                    Label(XtreamLinkOffer.button, systemImage: "film.stack")
                }
                .accessibilityIdentifier("onboarding.useXtream")
            } footer: {
                Text(XtreamLinkOffer.message)
                    .accessibilityIdentifier("onboarding.xtreamOffer")
            }
        }
    }

    /// Apple TV: the same section, its footer at caption size.
    struct Television: View {
        let useXtream: () -> Void

        var body: some View {
            Section {
                Button(XtreamLinkOffer.button, action: useXtream)
                    .accessibilityIdentifier("onboarding.useXtream")
            } footer: {
                Text(XtreamLinkOffer.message)
                    .font(.caption)
                    .accessibilityIdentifier("onboarding.xtreamOffer")
            }
        }
    }
}

#Preview("Xtream link offer, iPhone") {
    Form {
        XtreamLinkOffer.Phone {}
    }
}

#Preview("Xtream link offer, Apple TV", traits: .fixedLayout(width: 1000, height: 300)) {
    Form {
        XtreamLinkOffer.Television {}
    }
}
