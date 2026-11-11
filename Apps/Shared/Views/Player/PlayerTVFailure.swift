#if os(tvOS)
    import AntennaCore
    import SwiftUI

    /// The error in place of the full-screen picture on Apple TV
    /// (player-controls-and-playback-errors/a-failed-stream-says-what-went-wrong):
    /// Try again takes focus, Sign in sits next to it for a login that is
    /// missing or refused, and the hint says how to change channel.
    struct PlayerTVFailure: View {
        let player: PlayerModel
        let message: FailureMessage
        let focus: FocusState<ShellFocus?>.Binding
        /// Nil when the failure has nothing to do with the login.
        let signIn: (() -> Void)?

        var body: some View {
            PlayerStatus.TelevisionFailure(
                title: message.title, explanation: message.explanation, detail: detail, hint: PlayerStatusText.changeChannelHint
            ) {
                PlayerStatus.TelevisionButton(title: PlayerStatusText.tryAgain) { player.retry() }
                    // Holding select on the error is Try again too.
                    .simultaneousGesture(LongPressGesture(minimumDuration: 0.5).onEnded { _ in player.retry() })
                    .focused(focus, equals: .retry)
                    .accessibilityIdentifier("player.retry")
                if let signIn {
                    PlayerStatus.TelevisionButton(title: PlayerStatusText.signIn, action: signIn)
                        .focused(focus, equals: .signIn)
                        .accessibilityIdentifier("player.signIn")
                }
            }
        }

        /// "Source: Acme TV · Attempted at 21:34".
        private var detail: String {
            let time = (player.failedAt ?? .now).formatted(date: .omitted, time: .shortened)
            return PlayerStatusText.attempted(source: player.subject?.source ?? PlayerModel.unnamedSource, at: time)
        }
    }

    /// Asks for the username and password of one source and stores them
    /// in the Keychain under its key, then goes back to the channel.
    /// Stands in for the onboarding sign-in step on Apple TV until change
    /// add-first-run-onboarding builds it.
    struct SignInView: View {
        let request: SignInRequest
        let save: (_ username: String, _ password: String) throws -> Void
        @Environment(\.dismiss) private var dismiss
        @State private var username = ""
        @State private var password = ""
        @State private var failed = false

        var body: some View {
            NavigationStack {
                Form {
                    Section {
                        TextField("Username", text: $username)
                            .textContentType(.username)
                            .accessibilityIdentifier("signIn.username")
                        SecureField("Password", text: $password)
                            .textContentType(.password)
                            .accessibilityIdentifier("signIn.password")
                    } footer: {
                        if failed {
                            Text("The login could not be saved on this Apple TV. Try again.")
                                .accessibilityIdentifier("signIn.error")
                        }
                    }
                    Button("Sign in") {
                        do {
                            try save(username, password)
                        } catch {
                            failed = true
                        }
                    }
                    .disabled(username.isEmpty || password.isEmpty)
                    .accessibilityIdentifier("signIn.submit")
                    Button("Cancel", role: .cancel) { dismiss() }
                        .accessibilityIdentifier("signIn.cancel")
                }
                .navigationTitle("Sign in to \(request.name)")
            }
            .accessibilityIdentifier("signIn")
        }
    }
#endif
