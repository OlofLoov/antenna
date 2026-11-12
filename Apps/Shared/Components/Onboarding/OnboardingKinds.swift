import AntennaCore
import SwiftUI

/// "What kind of source?" on Apple TV (`TV-Onboard-2`): four cards, each
/// opening its form (first-run-onboarding/add-a-stalker-portal,
/// first-run-onboarding/add-a-jellyfin-server).
enum OnboardingKinds {
    struct Television: View {
        let choose: (SourceKind) -> Void

        var body: some View {
            VStack(spacing: 56) {
                VStack(spacing: 14) {
                    Text("What kind of source?")
                        .font(.system(size: 56, weight: .heavy))
                        .accessibilityAddTraits(.isHeader)
                    Text("Your provider gave you one of these. You can add more later.")
                        .font(.system(size: 26))
                        .foregroundStyle(Palette.textMuted)
                }
                .multilineTextAlignment(.center)
                HStack(spacing: 32) {
                    Button {
                        choose(.m3u)
                    } label: {
                        Card(
                            systemImage: "list.bullet", title: "M3U playlist",
                            detail: "A link ending in .m3u or .m3u8. Add an XMLTV link for the guide if you have one.",
                            footnote: "Most common")
                    }
                    .accessibilityIdentifier("onboarding.kind.m3u")
                    Button {
                        choose(.xtream)
                    } label: {
                        Card(
                            systemImage: "person.badge.key", title: "Xtream login",
                            detail: "A server address with a username and password. Channels, guide, movies and series all come with it.",
                            footnote: "Also called Xtream Codes")
                    }
                    .accessibilityIdentifier("onboarding.kind.xtream")
                    Button {
                        choose(.stalker)
                    } label: {
                        Card(
                            systemImage: "server.rack", title: "Stalker portal",
                            detail: "A portal address and a MAC address, the way a MAG box signs in.", footnote: "Also called Ministra")
                    }
                    .accessibilityIdentifier("onboarding.kind.stalker")
                    Button {
                        choose(.jellyfin)
                    } label: {
                        Card(
                            systemImage: "play.tv", title: "Jellyfin",
                            detail: "Your own Jellyfin server's Live TV, signed in with your Jellyfin username and password.",
                            footnote: "Live TV and guide from your server")
                    }
                    .accessibilityIdentifier("onboarding.kind.jellyfin")
                }
                .buttonStyle(CardStyle())
            }
            .foregroundStyle(Palette.text)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.ground)
        }
    }

    private struct Card: View {
        let systemImage: String
        let title: String
        let detail: String
        let footnote: String
        @Environment(\.isFocused) private var isFocused

        var body: some View {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: systemImage)
                    .font(.system(size: 34))
                    .frame(width: 80, height: 80)
                    .background(
                        (isFocused ? Palette.ground.opacity(0.08) : Palette.surface(0.1)),
                        in: RoundedRectangle(cornerRadius: 20)
                    )
                    .accessibilityHidden(true)
                Text(title).font(.system(size: 34, weight: .bold))
                Text(detail)
                    .font(.system(size: 23))
                    .foregroundStyle(isFocused ? Color(white: 0.3) : OnboardingStyle.body)
                Spacer(minLength: 0)
                Text(footnote)
                    .font(.system(size: 20))
                    .foregroundStyle(isFocused ? Color(white: 0.3) : Palette.textMuted)
            }
            .foregroundStyle(isFocused ? Palette.ground : Palette.text)
            .padding(40)
            .frame(width: 400, height: 420, alignment: .topLeading)
            .background(
                isFocused ? Palette.focus : Palette.surface(0.08), in: RoundedRectangle(cornerRadius: 20)
            )
            .shadow(color: isFocused ? Palette.focusShadow : .clear, radius: 22, y: 16)
            .scaleEffect(isFocused ? 1.04 : 1)
        }
    }

    /// Draws the card itself; the card reads focus.
    private struct CardStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
        }
    }
}

#Preview("Source type, Apple TV", traits: .fixedLayout(width: 1920, height: 1080)) {
    OnboardingKinds.Television { _ in }
}
