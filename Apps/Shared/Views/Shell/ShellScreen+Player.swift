#if os(tvOS)
    import AntennaCore
    import SwiftUI

    /// The player's layers and inputs: the spinner, the error, the info panel.
    extension ShellScreen {
        var overlayFocus: OverlayFocus? {
            if case .overlay(let target) = focus { return target }
            return nil
        }

        /// `switchProfile` after the engine stops; nil outside a profile gate.
        var stoppingFirst: SwitchProfileAction? {
            guard let switchProfile else { return nil }
            return SwitchProfileAction { [model] in
                Task {
                    await model.engine.stop()
                    switchProfile()
                }
            }
        }

        /// The spinner or the error over the picture, sized to it: the short
        /// error in the Guide's box; Live's page draws the full one with its buttons
        /// (player-controls-and-playback-errors/a-failed-stream-says-what-went-wrong).
        @ViewBuilder var pictureStatus: some View {
            if model.tuned != nil {
                if let message = model.player.message {
                    if model.tab != .live {
                        PlayerStatus.Failure(channel: nil, title: message.title, explanation: message.explanation) { EmptyView() }
                    }
                } else {
                    PlayerWaitingLayer(player: model.player)
                        .environment(\.playerStatusMetrics, model.tab == .live ? .television : .compact)
                }
            }
        }

        /// Sign in on the error, nil when the failure is not about the login
        /// or the source has no login, as a playlist has none.
        var signIn: (() -> Void)? {
            guard let failure = model.player.failure, failure == .loginNotOnDevice || failure == .notAllowed,
                let source = model.tuned?.sourceID, model.descriptors[source]?.credentialKey != nil
            else { return nil }
            return { model.signIn(to: source) }
        }

        /// Opens the info panel on Info with focus on its tab.
        func openPanel() {
            guard model.liveInFront, !model.pickerOpen else { return }
            numbers.cancel()
            zapBar.dismiss()
            model.player.openPanel()
            if model.player.panel != nil { focus = .panel(.segment(.info)) }
        }

        /// The error takes focus from the picture; once it goes, focus is
        /// back on the picture.
        func failureChanged(_ failed: Bool) {
            switch focus {
            case .picture where failed: focus = .retry
            case .retry where !failed, .signIn where !failed, .channels where !failed: focus = model.liveFocus
            default: break
            }
        }

        /// Channels on the error opens the overlay the way select on the
        /// picture does, with the highlight on the group in the group column
        /// (player-controls-and-playback-errors/go-to-another-group-from-the-error).
        func openChannels() {
            guard model.liveInFront, !model.pickerOpen else { return }
            numbers.cancel()
            zapBar.dismiss()
            _ = overlay.open(catalogue, playing: model.tuned)
            model.openPicker()
            focus = .overlay(.group(overlay.group))
        }
    }
#endif
