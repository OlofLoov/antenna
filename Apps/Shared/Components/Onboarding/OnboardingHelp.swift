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

    /// The sheet on iPhone, iPad and Mac, with Done at the top right.
    struct Phone: View {
        let done: () -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(OnboardingHelp.title)
                        .font(.system(size: 17, weight: .semibold))
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Button("Done", action: done)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Palette.accent)
                        .frame(minWidth: 44, minHeight: 44)
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("onboarding.helpDone")
                }
                .padding(.bottom, 12)
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        Text(
                            OnboardingHelp.intro + OnboardingHelp.noServers
                        )
                        .font(.system(size: 17))
                        .foregroundStyle(OnboardingStyle.body)
                        Kind(heading: OnboardingHelp.m3uHeading, text: OnboardingHelp.m3uText, headingSize: 17, textSize: 15)
                        Kind(
                            heading: OnboardingHelp.xtreamHeading,
                            text: OnboardingHelp.xtreamText + " The login is saved in your iCloud Keychain.", headingSize: 17, textSize: 15)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .foregroundStyle(Palette.text)
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Palette.ground)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("onboarding.helpSheet")
        }
    }

    /// Apple TV, full screen with Done focused.
    struct Television: View {
        let done: () -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: 36) {
                VStack(alignment: .leading, spacing: 16) {
                    Text(OnboardingHelp.title)
                        .font(.system(size: 52, weight: .heavy))
                        .accessibilityAddTraits(.isHeader)
                    Text(OnboardingHelp.intro)
                        .font(.system(size: 28))
                        .foregroundStyle(OnboardingStyle.body)
                }
                Kind(heading: OnboardingHelp.m3uHeading, text: OnboardingHelp.m3uText, headingSize: 30, textSize: 24)
                Kind(
                    heading: OnboardingHelp.xtreamHeading,
                    text: OnboardingHelp.xtreamText + " The login is saved in the Keychain on this Apple TV.",
                    headingSize: 30, textSize: 24)
                Button("Done", action: done)
                    .buttonStyle(OnboardingStyle.PrimaryTV())
                    .accessibilityIdentifier("onboarding.helpDone")
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
            }
            .foregroundStyle(Palette.text)
            .frame(maxWidth: 1100)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.ground)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("onboarding.helpSheet")
        }
    }

    /// A heading over its explanation.
    private struct Kind: View {
        let heading: String
        let text: String
        let headingSize: CGFloat
        let textSize: CGFloat

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text(heading).font(.system(size: headingSize, weight: .bold))
                Text(text).font(.system(size: textSize)).foregroundStyle(OnboardingStyle.body)
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
