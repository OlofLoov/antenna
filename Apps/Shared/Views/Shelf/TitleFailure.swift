import AntennaCore
import SwiftUI

/// The error in place of a movie or episode that cannot play, with Try
/// again and a way back to the page
/// (player-controls-and-playback-errors/a-movie-or-episode-that-cannot-play-says-why).
/// Menu on Apple TV and Escape on a Mac go back too.
struct TitleFailure: View {
    let failure: FailureMessage
    let title: String
    let retry: () -> Void
    let close: () -> Void
    #if os(tvOS)
        @FocusState private var retryFocused: Bool
    #endif

    var body: some View {
        #if os(tvOS)
            PlayerStatus.TelevisionFailure(
                title: failure.title, explanation: failure.explanation, detail: title, hint: "Press Menu to go back"
            ) {
                Button("Try again", action: retry)
                    .focused($retryFocused)
                    .accessibilityIdentifier("player.retry")
                Button("Back", action: close)
                    .accessibilityIdentifier("player.error.back")
            }
            .onExitCommand(perform: close)
            .task { retryFocused = true }
            .ignoresSafeArea()
        #else
            PlayerStatus.Failure(channel: title, title: failure.title, explanation: failure.explanation) {
                Button("Try again", action: retry)
                    .accessibilityIdentifier("player.retry")
                Button("Back", action: close)
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("player.error.back")
            }
            .ignoresSafeArea()
        #endif
    }
}
