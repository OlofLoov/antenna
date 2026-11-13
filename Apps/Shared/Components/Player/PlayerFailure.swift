import AntennaCore
import SwiftUI

/// Read here because `PlayerStatus.Metrics` hides the app-wide `Metrics` inside the extension.
private let televisionSafeArea = Metrics.televisionSafeArea

extension PlayerStatus {
    /// The error in place of the picture on iPhone, iPad and Mac, and in the
    /// Guide's small picture on Apple TV
    /// (player-controls-and-playback-errors/a-failed-stream-says-what-went-wrong),
    /// on the shared `StatusView` layout: the symbol, the title, the
    /// explanation naming the source, and the buttons. `channel` names the
    /// channel under the title when nothing else on screen does. A picture
    /// too short for it scrolls.
    struct Failure<Actions: View>: View {
        let channel: String?
        let title: String
        let explanation: String
        @ViewBuilder var actions: Actions

        var body: some View {
            ViewThatFits(in: .vertical) {
                status
                ScrollView { status }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.ground)
            .task(id: title + explanation) { Announce.post(title, explanation) }
        }

        private var status: some View {
            StatusView(symbol: PlayerStatus.symbol, verbatimTitle: title, identifier: "player.error") {
                if let channel {
                    Text(channel)
                        .accessibilityIdentifier("player.error.channel")
                }
                Text(explanation)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("player.error.body")
            } actions: {
                actions
            }
        }
    }

    /// The error in place of the full-screen picture on Apple TV
    /// (`TV-Player-Error`), on the shared `StatusView` layout: the symbol,
    /// the title, the explanation, the source and time of the attempt, the
    /// buttons, and how to change channel.
    struct TelevisionFailure<Actions: View>: View {
        let title: String
        let explanation: String
        /// "Source: Acme TV · Attempted at 21:34".
        let detail: String
        let hint: LocalizedStringResource
        @ViewBuilder var actions: Actions

        var body: some View {
            StatusView(symbol: PlayerStatus.symbol, verbatimTitle: title, identifier: "player.error") {
                Text(explanation)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("player.error.body")
                Text(detail)
                    .accessibilityIdentifier("player.error.detail")
                Text(hint)
                    .accessibilityIdentifier("player.error.hint")
            } actions: {
                actions
            }
            .safeAreaPadding(televisionSafeArea)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.ground)
            .task(id: title + explanation) { Announce.post(title, explanation) }
        }
    }

    /// The circled exclamation mark every player error shows.
    static let symbol = "exclamationmark.circle"

    /// The Apple TV explanation color in the info panel, between the text
    /// and muted tokens.
    static let televisionBody = Color(red: 0xD7 / 255, green: 0xDE / 255, blue: 0xE8 / 255)

    /// Reads the title and explanation once when the error appears.
    private enum Announce {
        @MainActor static func post(_ title: String, _ explanation: String) {
            AccessibilityNotification.Announcement("\(title). \(explanation)").post()
        }
    }
}

#Preview("Error, iPhone", traits: .fixedLayout(width: 390, height: 219)) {
    PlayerStatus.Failure(
        channel: nil, title: "You're offline",
        explanation: "Connect to the internet and try again. Playback resumes on its own when the connection returns."
    ) {
        Button("Try again") {}
    }
}

#Preview("Error, iPad", traits: .fixedLayout(width: 640, height: 360)) {
    PlayerStatus.Failure(
        channel: nil, title: "Sign-in refused",
        explanation:
            "Acme TV rejected the login. Check the username and password in Settings, or ask the provider whether the account has expired."
    ) {
        Button("Try again") {}
    }
}

#Preview("Error, full screen with the channel", traits: .fixedLayout(width: 844, height: 390)) {
    PlayerStatus.Failure(
        channel: "104 Sport One", title: "Stream not found",
        explanation: "Acme TV returned 404 for this channel. The channel may have moved or been removed by the provider."
    ) {
        Button("Try again") {}
    }
}

#Preview("Error, Apple TV", traits: .fixedLayout(width: 1920, height: 1080)) {
    PlayerStatus.TelevisionFailure(
        title: "Stream not found",
        explanation: "Acme TV returned 404 for this channel. The channel may have moved or been removed by the provider.",
        detail: "Source: Acme TV · Attempted at 21:34", hint: "Swipe up or down for another channel. Menu opens the tab bar."
    ) {
        Button("Try again") {}
    }
}

#Preview("Error, Apple TV, sign in needed", traits: .fixedLayout(width: 1920, height: 1080)) {
    PlayerStatus.TelevisionFailure(
        title: "Sign in needed", explanation: "Sign in to Acme TV on this Apple TV to play its channels.",
        detail: "Source: Acme TV · Attempted at 21:34", hint: "Swipe up or down for another channel. Menu opens the tab bar."
    ) {
        Button("Try again") {}
        Button("Sign in") {}
    }
}

#Preview("Error, Apple TV, German", traits: .fixedLayout(width: 1920, height: 1080)) {
    let german = PreviewLanguage.german.locale
    let message = FailureMessage(.notFound, source: "Acme TV", device: .appleTV, locale: german)
    PlayerStatus.TelevisionFailure(
        title: message.title, explanation: message.explanation,
        detail: PlayerStatusText.attempted(source: "Acme TV", at: "21:34", locale: german),
        hint: .verbatim(PlayerStatusText.changeChannelHint(german))
    ) {
        Button(PlayerStatusText.tryAgain(german)) {}
        Button(PlayerStatusText.signIn(german)) {}
    }
    .previewLanguage(.german)
}
