import AntennaCore
import SwiftUI

/// "What kind of source?" on Apple TV (`TV-Onboard-2`): five card buttons
/// inside the safe area, each opening its form, and Cancel
/// (first-run-onboarding/add-a-stalker-portal,
/// first-run-onboarding/add-a-jellyfin-server,
/// first-run-onboarding/add-a-channels-dvr-server,
/// design-system/apple-tv-content-stays-in-the-safe-area). The cards use
/// the system card style, which lifts and tilts the focused one
/// (design-system/controls-use-system-styles). It paints no background.
enum OnboardingKinds {
    /// One card: its symbol, name and one line about what the provider gives.
    struct Kind: Identifiable {
        var kind: SourceKind
        var systemImage: String
        var title: String
        var detail: String
        var id: String { kind.rawValue }
    }

    static let all = [
        Kind(
            kind: .m3u, systemImage: "list.bullet", title: "M3U playlist",
            detail: "A link ending in .m3u or .m3u8, with an optional guide link."),
        Kind(
            kind: .xtream, systemImage: "person.badge.key", title: "Xtream login",
            detail: "A server address with a username and password."),
        Kind(kind: .stalker, systemImage: "server.rack", title: "Stalker portal", detail: "A portal address and a MAC address."),
        Kind(kind: .jellyfin, systemImage: "play.tv", title: "Jellyfin", detail: "Live TV from your own Jellyfin server."),
        Kind(
            kind: .channelsDVR, systemImage: "externaldrive.connected.to.line.below", title: "Channels DVR",
            detail: "A Channels DVR server on your home network."),
    ]

    struct Television: View {
        let choose: (SourceKind) -> Void
        let cancel: () -> Void

        var body: some View {
            VStack(spacing: Metrics.Spacing.xxLarge) {
                VStack(spacing: Metrics.Spacing.medium) {
                    Text("What kind of source?")
                        .font(.title2.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                    Text("Your provider gave you one of these. You can add more later.")
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                HStack(spacing: Metrics.Spacing.xLarge) {
                    ForEach(OnboardingKinds.all) { kind in
                        Button {
                            choose(kind.kind)
                        } label: {
                            Card(kind: kind)
                        }
                        .cardButtonStyle()
                        .accessibilityIdentifier("onboarding.kind.\(kind.id)")
                    }
                }
                Button("Cancel", action: cancel)
                    .buttonStyle(.glass)
                    .accessibilityIdentifier("onboarding.back")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// The card's content. The card style draws the platter and the focus.
    private struct Card: View {
        let kind: Kind

        var body: some View {
            VStack(alignment: .leading, spacing: Metrics.Spacing.medium) {
                Image(systemName: kind.systemImage)
                    .font(.callout)
                    .frame(width: 72, height: 72)
                    .background(.quaternary, in: Metrics.Corner.medium.shape())
                    .accessibilityHidden(true)
                Text(kind.title)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(kind.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(Metrics.Spacing.xLarge)
            .frame(width: 300, height: 380, alignment: .topLeading)
        }
    }
}

extension View {
    /// The card style on Apple TV; bordered where the snapshot job renders
    /// the preview, since the card style exists only on tvOS.
    @ViewBuilder fileprivate func cardButtonStyle() -> some View {
        #if os(tvOS)
            buttonStyle(.card)
        #else
            buttonStyle(.bordered)
        #endif
    }
}

#Preview("Source type, Apple TV", traits: .fixedLayout(width: 1920, height: 1080)) {
    OnboardingKinds.Television(choose: { _ in }, cancel: {})
}
