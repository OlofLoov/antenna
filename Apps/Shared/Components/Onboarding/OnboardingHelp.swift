import SwiftUI

/// "What is a source?" from the welcome screen (`iPhone-Onboard-Help`,
/// `TV-Onboard-Help`). Done closes it.
enum OnboardingHelp {
    static let title = "What is a source?"
    static let m3uHeading = "M3U playlist"
    static let m3uText =
        "A link ending in .m3u or .m3u8. It lists every channel with its stream address. "
        + "A second link, in XMLTV format, carries the programme guide and is optional."
    static let xtreamHeading = "Xtream login"
    static let xtreamText =
        "A server address with a username and password, sometimes called Xtream Codes. "
        + "The server answers with channels, guide, movies and series, so there is nothing else to add."
    static let intro = "Antenna includes no channels. A source is the playlist or login a TV provider gives you."
    static let noServers = " Antenna has no servers of its own; everything you add stays between you and your provider."

    /// The sheet on iPhone, iPad and Mac, with the title in the bar and
    /// Done as its confirming action.
    struct Phone: View {
        let done: () -> Void

        var body: some View {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: Metrics.Spacing.large) {
                        Text(OnboardingHelp.intro + OnboardingHelp.noServers)
                            .foregroundStyle(.secondary)
                        Kind(heading: OnboardingHelp.m3uHeading, text: OnboardingHelp.m3uText)
                        Kind(
                            heading: OnboardingHelp.xtreamHeading,
                            text: OnboardingHelp.xtreamText + " The login is saved in your iCloud Keychain.")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Metrics.Spacing.large)
                    .padding(.vertical, Metrics.Spacing.medium)
                }
                .navigationTitle(OnboardingHelp.title)
                #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done", action: done)
                            .accessibilityIdentifier("onboarding.helpDone")
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("onboarding.helpSheet")
        }
    }

    /// Apple TV, full screen with Done focused.
    struct Television: View {
        let done: () -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: Metrics.Spacing.xLarge) {
                VStack(alignment: .leading, spacing: Metrics.Spacing.medium) {
                    Text(OnboardingHelp.title)
                        .font(.title2.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                    Text(OnboardingHelp.intro)
                        .foregroundStyle(.secondary)
                }
                Kind(heading: OnboardingHelp.m3uHeading, text: OnboardingHelp.m3uText)
                Kind(
                    heading: OnboardingHelp.xtreamHeading,
                    text: OnboardingHelp.xtreamText + " The login is saved in the Keychain on this Apple TV.")
                Button("Done", action: done)
                    .primaryActionStyle()
                    .accessibilityIdentifier("onboarding.helpDone")
                    .frame(maxWidth: .infinity)
                    .padding(.top, Metrics.Spacing.small)
            }
            .frame(maxWidth: 1100)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("onboarding.helpSheet")
        }
    }

    /// A heading over its explanation: headline over body in secondary.
    private struct Kind: View {
        let heading: String
        let text: String

        var body: some View {
            VStack(alignment: .leading, spacing: Metrics.Spacing.xSmall) {
                Text(heading).font(.headline)
                Text(text)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
        }
    }
}

#Preview("What is a source?, iPhone") {
    OnboardingHelp.Phone {}
}

#Preview("What is a source?, Apple TV", traits: .fixedLayout(width: 1920, height: 1080)) {
    OnboardingHelp.Television {}
}
