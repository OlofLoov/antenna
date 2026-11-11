#if os(tvOS)
    import AntennaCore
    import Foundation

    /// A source the sign-in step asks a login for. Holds the Keychain key,
    /// never the login itself.
    struct SignInRequest: Identifiable, Equatable {
        var id: UUID
        var name: String
        var credentialKey: String
    }

    extension ShellModel {
        /// The bar shows when raised by Menu and always on Movies, Series and Search.
        var barVisible: Bool { barRaised || tab.isContent }

        /// The picture or guide is dimmed under the raised bar.
        var dimmed: Bool { barRaised && !tab.isContent }

        /// The tabs the bar lists: Movies and Series only with an Xtream source (movies-and-series-browsing/movies-and-series-appear-when-your-provider-has-them).
        var tabs: [ShellTab] {
            ShellTab.allCases.filter { offersMovies || ($0 != .movies && $0 != .series) }
        }

        /// The navigator other screens use; `ShellView` provides it.
        var navigator: ShellNavigator { .forwarding(to: self) }

        /// The names the player's messages use for `channel`.
        func subject(for channel: Channel) -> PlayerSubject {
            PlayerSubject(
                channel: channel, source: sources.first { $0.id == channel.sourceID }?.name ?? PlayerModel.unnamedSource,
                number: channel.number)
        }

        /// Loads `channel` without telling the player or the info bar it
        /// changed, so Try again counts as no channel change.
        func load(_ channel: Channel) {
            Task {
                do {
                    try await session.load(channel, on: engine, options: languages.options(for: channel))
                } catch is CancellationError {
                    return
                } catch {
                    Self.logger.info("tune failed, the stored channel is kept")
                    if let failure = error as? PlaybackFailure, tuned == channel { player.loadFailed(failure) }
                    return
                }
                guard tuned == channel else { return }
                // A pause from the timer while the load ran stands.
                if !pausedByShell { await engine.play() }
            }
        }

        /// Tells the session tracker each engine state until the calling task ends.
        func trackSession() async {
            for await state in await engine.states() {
                session.stateChanged(state)
            }
        }

        /// Opens the sign-in step for the source with `id`
        /// (player-controls-and-playback-errors/try-again-or-recover-on-its-own).
        func signIn(to id: UUID) {
            guard let source = descriptors[id], let key = source.credentialKey else { return }
            signInRequest = SignInRequest(id: id, name: source.name, credentialKey: key)
        }

        /// Stores the login the sign-in step took, closes it and loads the
        /// channel again.
        func saveLogin(for request: SignInRequest, username: String, password: String) throws {
            try dependencies.credentials.save(.init(username: username, password: password), for: request.credentialKey)
            signInRequest = nil
            player.retry()
        }

        /// Tunes `channel` from the picker and shows Live full screen.
        func pick(_ channel: Channel) async {
            if channel != tuned { tune(channel) }
            await showLive()
        }
    }

    extension ShellTab {
        var title: String {
            switch self {
            case .live: "Live"
            case .guide: "Guide"
            case .movies: "Movies"
            case .series: "Series"
            case .search: "Search"
            }
        }

        /// The element name design-system/accessibility-identifiers-follow-the-board asks for: `shell.tab.<identifier>`.
        var identifier: String {
            switch self {
            case .live: "live"
            case .guide: "guide"
            case .movies: "movies"
            case .series: "series"
            case .search: "search"
            }
        }
    }
#endif
