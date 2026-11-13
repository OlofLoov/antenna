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
        /// Thrown by a loader for a source whose login is not on this device.
        enum LoadFailure: Error { case waitingForLogin }

        /// The bar shows when raised by Menu and always on Movies, Series and Search.
        var barVisible: Bool { barRaised || tab.isContent }

        /// The picture or guide is dimmed under the raised bar.
        var dimmed: Bool { barRaised && !tab.isContent }

        /// The tabs the bar lists: Movies and Series each only when a source
        /// offers it (m3u-playlists/movies-and-series-show-by-what-the-sources-offer).
        var tabs: [ShellTab] {
            let offer = titleOffer
            return ShellTab.allCases.filter { tab in
                switch tab {
                case .movies: offer.movies
                case .series: offer.series
                default: true
                }
            }
        }

        /// The navigator other screens use; `ShellView` provides it.
        var navigator: ShellNavigator { .forwarding(to: self) }

        /// The names the player's messages use for `channel`.
        func subject(for channel: Channel) -> PlayerSubject {
            PlayerSubject(
                channel: channel, source: sources.first { $0.id == channel.sourceID }?.name ?? PlayerModel.unnamedSource,
                number: channel.channelNumber)
        }

        /// Loads `channel` without telling the player or the info bar it
        /// changed, so Try again counts as no channel change.
        func load(_ channel: Channel) {
            Task {
                do {
                    try await session.load(channel, on: engine, options: languages.options(for: channel).recordingLive())
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

        /// A source was deleted, here or on another device
        /// (session-restore-and-recently-watched/deleting-a-source-clears-its-channels):
        /// its channel is no longer the one to tune at launch, and its
        /// channel playing now stops counting as watched.
        func sourceDeleted(_ id: UUID) {
            session.remove(source: id)
            dependencies.seen.remove(id)
            if stored?.sourceID == id { stored = nil }
            recents.removeAll { $0.sourceID == id }
        }

        /// Reads the stored recents, then tells the session tracker each
        /// engine state until the calling task ends.
        func trackSession() async {
            recents = session.store.recents.entries
            session.recorded = { [weak self] list in self?.recents = list.entries }
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
        /// The tab Movies at launch and Browse movies open: Movies, or Series
        /// when only series are offered.
        static func titles(_ offer: TitleOffer) -> ShellTab {
            !offer.movies && offer.series ? .series : .movies
        }

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

    extension ShellModel.Dependencies {
        /// The engine, loader, Keychain check and clock the app runs on.
        /// The last channel and language picks are `profile`'s on this Apple TV.
        /// With `refresher`, sources load through it one at a time and report their status.
        @MainActor static func live(loader: SourceLoader, guide: AppGuideStore?, profile: UUID, refresher: SourceRefresher? = nil) -> Self {
            var dependencies = Self(
                engine: RoutedEngine.app(),
                load: { source in
                    if let refresher { return try await refresher.load(source) }
                    return try await loader.load(source)
                },
                hasLogin: { refresher?.hasLogin($0) ?? loader.hasLogin($0) },
                recents: RecentsStore(profile: profile),
                sleep: { try await Task.sleep(for: $0) },
                guide: guide,
                languages: ChannelLanguageStore(profile: profile))
            dependencies.waitsForICloud = { loader.waitsForICloud($0) }
            dependencies.seen = .app
            dependencies.storedTitles = { refresher?.status(of: $0).titleCounts ?? LastLoadStore().readTitles($0) }
            return dependencies
        }
    }
#endif
