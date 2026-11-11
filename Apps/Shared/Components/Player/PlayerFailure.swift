import SwiftUI

extension PlayerStatus {
    /// Sizes of the error in the iPhone, iPad and Mac player.
    struct FailureMetrics: Equatable, Sendable {
        var icon: CGFloat
        var gap: CGFloat
        var bodyWidth: CGFloat

        /// `iPhone-Player-Error`: a 32 pt icon.
        static let compact = FailureMetrics(icon: 32, gap: 8, bodyWidth: 342)
        /// `iPad-Player-Error`: a 40 pt icon and a 420 pt body.
        static let regular = FailureMetrics(icon: 40, gap: 10, bodyWidth: 420)
    }

    /// The error in place of the picture on iPhone, iPad and Mac
    /// (player-controls-and-playback-errors/a-failed-stream-says-what-went-wrong):
    /// the icon, the title, the explanation naming the source, and the
    /// buttons under them on the ground color. `channel` names the channel
    /// above the title when nothing else on screen does.
    struct Failure<Actions: View>: View {
        let channel: String?
        let title: String
        let explanation: String
        @ViewBuilder var actions: Actions
        @Environment(\.playerFailureMetrics) private var metrics

        var body: some View {
            ViewThatFits(in: .vertical) {
                content
                ScrollView { content.padding(.vertical, 12) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.ground)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("player.error")
            .task(id: title + explanation) { Announce.post(title, explanation) }
        }

        private var content: some View {
            VStack(spacing: metrics.gap) {
                Icon(size: metrics.icon)
                if let channel {
                    Text(channel)
                        .font(.footnote)
                        .foregroundStyle(Palette.textMuted)
                        .accessibilityIdentifier("player.error.channel")
                }
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Palette.text)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("player.error.title")
                Text(explanation)
                    .font(.subheadline)
                    .foregroundStyle(Palette.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: metrics.bodyWidth)
                    .accessibilityIdentifier("player.error.body")
                HStack(spacing: 12) { actions }
                    .padding(.top, 4)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
        }
    }

    /// Try again, 44 pt on the 0.12 surface, radius 10.
    struct RetryButton: View {
        let retry: () -> Void

        var body: some View {
            Button(action: retry) {
                Text("Try again")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.text)
                    .padding(.horizontal, 20)
                    .frame(minHeight: 44)
                    .background(Palette.surface(0.12), in: RoundedRectangle(cornerRadius: 10))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("player.retry")
        }
    }

    /// The error in place of the full-screen picture on Apple TV
    /// (`TV-Player-Error`): the icon, the 38 pt title, the explanation, the
    /// source and time of the attempt, the buttons, and how to change channel.
    struct TelevisionFailure<Actions: View>: View {
        let title: String
        let explanation: String
        /// "Source: Acme TV · Attempted at 21:34".
        let detail: String
        let hint: String
        @ViewBuilder var actions: Actions

        var body: some View {
            VStack(spacing: 28) {
                Icon(size: 72)
                Text(title)
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(Palette.text)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("player.error.title")
                Text(explanation)
                    .font(.system(size: 26))
                    .lineSpacing(8)
                    .foregroundStyle(PlayerStatus.televisionBody)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 1100)
                    .accessibilityIdentifier("player.error.body")
                Text(detail)
                    .font(.system(size: 22))
                    .foregroundStyle(Palette.textMuted)
                    .accessibilityIdentifier("player.error.detail")
                HStack(spacing: 16) { actions }
                    .padding(.top, 12)
                Text(hint)
                    .font(.system(size: 22))
                    .foregroundStyle(Palette.textMuted)
                    .padding(.top, 8)
                    .accessibilityIdentifier("player.error.hint")
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 320)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.ground)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("player.error")
            .task(id: title + explanation) { Announce.post(title, explanation) }
        }
    }

    /// The Apple TV error's explanation color, between the text and muted tokens.
    static let televisionBody = Color(red: 0xD7 / 255, green: 0xDE / 255, blue: 0xE8 / 255)

    /// A 64 pt Apple TV button, 26 pt semibold, radius 14: the Focus token
    /// while focused, the 0.12 surface otherwise.
    struct TelevisionButton: View {
        let title: String
        let action: () -> Void

        var body: some View {
            Button(title, action: action)
                .buttonStyle(TelevisionButtonStyle())
        }
    }

    private struct TelevisionButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            TelevisionButtonLabel(label: configuration.label)
        }
    }

    private struct TelevisionButtonLabel<Label: View>: View {
        let label: Label
        @Environment(\.isFocused) private var isFocused

        var body: some View {
            label
                .font(.system(size: 26, weight: .semibold))
                .padding(.horizontal, 40)
                .frame(minHeight: 64)
                .foregroundStyle(isFocused ? Palette.ground : Palette.text)
                .background(isFocused ? Palette.focus : Palette.surface(0.12), in: RoundedRectangle(cornerRadius: 14))
                .shadow(color: isFocused ? Palette.focusShadow : .clear, radius: 16, y: 12)
        }
    }

    /// The circled exclamation mark in the muted color.
    struct Icon: View {
        let size: CGFloat

        var body: some View {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: size * 0.8, weight: .light))
                .foregroundStyle(Palette.textMuted)
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        }
    }

    /// Reads the title and explanation once when the error appears.
    private enum Announce {
        @MainActor static func post(_ title: String, _ explanation: String) {
            AccessibilityNotification.Announcement("\(title). \(explanation)").post()
        }
    }
}

extension EnvironmentValues {
    /// The error sizes; the iPad and Mac columns set `.regular`.
    @Entry var playerFailureMetrics = PlayerStatus.FailureMetrics.compact
}

#Preview("Error, iPhone", traits: .fixedLayout(width: 390, height: 219)) {
    PlayerStatus.Failure(
        channel: nil, title: "You're offline",
        explanation: "Connect to the internet and try again. Playback resumes on its own when the connection returns."
    ) {
        PlayerStatus.RetryButton {}
    }
}

#Preview("Error, iPad", traits: .fixedLayout(width: 640, height: 360)) {
    PlayerStatus.Failure(
        channel: nil, title: "Sign-in refused",
        explanation:
            "Acme TV rejected the login. Check the username and password in Settings, or ask the provider whether the account has expired."
    ) {
        PlayerStatus.RetryButton {}
    }
    .environment(\.playerFailureMetrics, .regular)
}

#Preview("Error, full screen with the channel", traits: .fixedLayout(width: 844, height: 390)) {
    PlayerStatus.Failure(
        channel: "104 Sport One", title: "Stream not found",
        explanation: "Acme TV returned 404 for this channel. The channel may have moved or been removed by the provider."
    ) {
        PlayerStatus.RetryButton {}
    }
}

#Preview("Error, Apple TV", traits: .fixedLayout(width: 1920, height: 1080)) {
    PlayerStatus.TelevisionFailure(
        title: "Stream not found",
        explanation: "Acme TV returned 404 for this channel. The channel may have moved or been removed by the provider.",
        detail: "Source: Acme TV · Attempted at 21:34", hint: "Swipe up or down for another channel. Menu opens the tab bar."
    ) {
        PlayerStatus.TelevisionButton(title: "Try again") {}
    }
}

#Preview("Error, Apple TV, sign in needed", traits: .fixedLayout(width: 1920, height: 1080)) {
    PlayerStatus.TelevisionFailure(
        title: "Sign in needed", explanation: "Sign in to Acme TV on this Apple TV to play its channels.",
        detail: "Source: Acme TV · Attempted at 21:34", hint: "Swipe up or down for another channel. Menu opens the tab bar."
    ) {
        PlayerStatus.TelevisionButton(title: "Try again") {}
        PlayerStatus.TelevisionButton(title: "Sign in") {}
    }
}
