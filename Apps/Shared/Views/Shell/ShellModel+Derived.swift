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

        /// True while channels may still arrive: before the sources are
        /// read, while one loads, and while the channels that loaded are not
        /// in the catalogue yet. The Guide says "Loading channels" then
        /// instead of an empty group
        /// (tvos-shell/no-empty-state-before-the-channels-are-listed).
        var channelsPending: Bool {
            guard launched else { return true }
            if sources.contains(where: { $0.state == .loading }) { return true }
            return !listed && sources.contains { $0.state.isLoadedWithChannels }
        }

        /// Where focus goes on Live: the picture once tuned, Try again while
        /// the error shows, else the loading or empty screen.
        var liveFocus: ShellFocus {
            guard tuned != nil else { return .liveScreen }
            return player.failure == nil ? .picture : .retry
        }

        /// The picture or the guide dims while the highlight is in the tab bar over them.
        var dimmed: Bool { barFocused && tab.showsPicture }

        /// Live full screen with the highlight on the page, not in the tab bar.
        var liveInFront: Bool { tab == .live && !barFocused }

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
        /// changed, so Try again counts as no channel change. With
        /// `remember` false, as for the Guide's small picture following the
        /// highlight, the channel is neither stored as the last one nor counted as watched.
        func load(_ channel: Channel, remember: Bool = true) {
            Task {
                do {
                    let options = languages.options(for: channel).recordingLive()
                    if remember {
                        try await session.load(channel, on: engine, options: options)
                    } else {
                        try await engine.load(try await StreamResolver.address(for: channel), options: options)
                    }
                } catch is CancellationError {
                    return
                } catch {
                    Self.logger.info("tune failed, the stored channel is kept")
                    if let failure = error as? PlaybackFailure, tuned?.isSame(as: channel) == true { player.loadFailed(failure) }
                    return
                }
                guard tuned?.isSame(as: channel) == true else { return }
                // A load that lands behind Movies, Series or Search stays paused.
                holdLoadedBehindContent()
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
            if launchStarted?.sourceID == id { launchStarted = nil }
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

        /// Tunes `channel` from the picker and shows Live full screen. A
        /// channel already in the Guide's small picture plays on without a reload.
        func pick(_ channel: Channel) async {
            await keepGuidePreview(channel)
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

        var title: LocalizedStringResource {
            switch self {
            case .live: "Live"
            case .guide: "Guide"
            case .movies: "Movies"
            case .series: "Series"
            case .search: "Search"
            case .settings: "Settings"
            }
        }

        /// The tab's element name (design-system/accessibility-identifiers-follow-the-board):
        /// `shell.tab.<identifier>`, and `shell.settings` for Settings, the name its button had.
        var elementName: String {
            self == .settings ? "shell.settings" : "shell.tab.\(identifier)"
        }

        /// The last part of `shell.tab.<identifier>`.
        var identifier: String {
            switch self {
            case .live: "live"
            case .guide: "guide"
            case .movies: "movies"
            case .series: "series"
            case .search: "search"
            case .settings: "settings"
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
            dependencies.launchLogins = { LaunchLogins(credentials: loader.credentials).logins(for: $0) }
            dependencies.storedTitles = { refresher?.status(of: $0).titleCounts ?? LastLoadStore().readTitles($0) }
            return dependencies
        }
    }
#endif
