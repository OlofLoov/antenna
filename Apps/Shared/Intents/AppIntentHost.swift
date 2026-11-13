#if !os(tvOS)
    import AntennaCore
    import AppIntents
    import Foundation
    import SwiftData
    #if os(iOS)
        import UIKit
    #endif

    /// The app's provider for Siri and Shortcuts (app-intents capability).
    /// With a window open it reads Live and the Movies library; with the app
    /// started in the background for an action it loads only the sources the
    /// action needs, for at most `deadline`, and keeps them for later actions
    /// in this run.
    @MainActor
    final class AppIntentHost: IntentCatalogueProvider {
        struct Dependencies {
            var container: ModelContainer
            /// Read from the cached entitlement, never waiting on the App Store.
            var isUnlocked: @MainActor () -> Bool
            var locksOpen: @MainActor () -> Bool = { false }
            var protectedDataAvailable: @MainActor () -> Bool = { true }
            var device: IntentFailure.Device = .iPhone
            var profile: @MainActor () -> UUID = { CurrentProfileStore().read() ?? Profile.mainID }
            var loadPlaylist: @MainActor (SourceDescriptor) async throws -> Playlist
            var hasLogin: @MainActor (SourceDescriptor) -> Bool
            var loadTitles: @MainActor (SourceDescriptor, ShelfTitle.Kind) async throws -> [ShelfTitle]
            /// How long a background load may hold an answer; the load itself goes on.
            var deadline = Duration.seconds(10)
            var sleep: @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
            /// Nil asks the system; tests answer here.
            var bringForward: (@MainActor () async throws -> Void)?
            /// Told after favorites change, so Siri's phrases offer the new list.
            var favoritesChanged: @MainActor () -> Void = { AntennaShortcuts.updateAppShortcutParameters() }
        }

        let dependencies: Dependencies
        let inbox = IntentInbox()
        /// Live and the Movies library, once a window shows them.
        private(set) weak var live: LiveModel?
        private(set) weak var shelves: ShelfLibrary?

        /// The profile the window shows.
        private var windowProfile: UUID?
        /// Background loads: what each source gave, how it ended, and the loads running.
        private var playlists: [UUID: [Channel]] = [:]
        private var playlistStates: [UUID: IntentSource.State] = [:]
        private var playlistLoads: [UUID: Task<Void, Never>] = [:]
        private var catalogues: [UUID: [ShelfTitle]] = [:]
        private var catalogueStates: [UUID: IntentSource.State] = [:]
        private var catalogueLoads: [UUID: Task<Void, Never>] = [:]
        /// The matcher and the channels and rules it was built from.
        private var matcher: (built: ChannelMatcher, from: MatcherInputs)?

        private struct MatcherInputs: Equatable {
            var channels: [Channel]
            var rules: GroupRules
        }

        init(_ dependencies: Dependencies) {
            self.dependencies = dependencies
        }

        /// The window's Live model and library and the profile it shows;
        /// actions read them from now on.
        func attach(live: LiveModel, shelves: ShelfLibrary, profile: UUID) {
            self.live = live
            self.shelves = shelves
            windowProfile = profile
        }

        /// The window's profile, else the one chosen last on this device.
        private var profile: UUID { windowProfile ?? dependencies.profile() }

        private var context: ModelContext { dependencies.container.mainContext }

        private var descriptors: [SourceDescriptor] {
            let records = (try? context.fetch(FetchDescriptor<SourceRecord>(sortBy: SourceRecord.displayOrder))) ?? []
            return records.compactMap(\.descriptor)
        }

        // MARK: IntentCatalogueProvider

        func checkAccess() throws(IntentFailure) {
            guard dependencies.isUnlocked() else { throw .notUnlocked }
            guard !descriptors.isEmpty else { throw .noSources }
        }

        var protectedDataAvailable: Bool { dependencies.protectedDataAvailable() }

        var device: IntentFailure.Device { dependencies.device }

        var playing: Channel? { live?.playing }

        func channels(loading sources: Set<UUID>?) async -> IntentChannels {
            if let live { return library(live) }
            let all = descriptors
            let wanted = all.filter { sources?.contains($0.id) ?? true }
            await waitForDeadline(wanted.map(startPlaylistLoad))
            let channels = all.flatMap { Channel.tagged(playlists[$0.id] ?? [], sourceID: $0.id) }
            let owner = profile
            let favorites = ((try? context.fetch(FetchDescriptor<FavoriteRecord>(sortBy: [SortDescriptor(\.sortOrder)]))) ?? [])
                .filter { ProfileList.owns(owner, recordProfile: $0.profileID) }.map(\.snapshot)
            let catalogue = Catalogue(channels: channels, groupOrder: [:], favorites: favorites, rules: rules(profile: owner))
            let states = all.map { IntentSource(id: $0.id, name: $0.name, state: playlistStates[$0.id] ?? .loading) }
            return IntentChannels(catalogue: catalogue, sources: states, matcher: matcher(for: channels, rules: catalogue.rules, catalogue))
        }

        func titles(loading sources: Set<UUID>?) async -> IntentTitles {
            let store = ActivityStore(context: context, profile: profile)
            let myList = (store.myList(.movie) + store.myList(.series)).map { ActivityKey(titleID: $0.titleID, sourceID: $0.sourceID) }
            if let shelves {
                // The library loads its titles only once a section opens.
                shelves.open()
                return IntentTitles(
                    titles: shelves.movies.titles + shelves.series.titles, sources: Self.states(shelves), progress: store.allProgress(),
                    myList: myList)
            }
            // Playlists count as Xtream sources do (m3u-playlists/playlist-titles-show-on-every-platform).
            let all = descriptors.filter { $0.kind == .xtream || $0.isPlaylist }
            let wanted = all.filter { sources?.contains($0.id) ?? true }
            await waitForDeadline(wanted.map(startCatalogueLoad))
            let titles = all.flatMap { catalogues[$0.id] ?? [] }
            let states = all.map { IntentSource(id: $0.id, name: $0.name, state: catalogueStates[$0.id] ?? .loading) }
            return IntentTitles(titles: titles, sources: states, progress: store.allProgress(), myList: myList)
        }

        func setFavorite(_ channel: Channel, to favorite: Bool, in catalogue: Catalogue<PersistentIdentifier>) {
            guard catalogue.isFavorite(channel) != favorite else { return }
            FavoriteRecord.toggle(channel, in: catalogue, profile: profile, context: context)
            dependencies.favoritesChanged()
        }

        func open(_ request: IntentRequest) {
            inbox.receive(request)
        }

        func bringForward<Intent: AppIntent>(_ intent: Intent) async throws {
            if let bringForward = dependencies.bringForward { return try await bringForward() }
            guard intent.systemContext.currentMode != .foreground else { return }
            guard intent.systemContext.currentMode.canContinueInForeground else {
                throw intent.needsToContinueInForegroundError(nil, alwaysConfirm: false)
            }
            try await intent.continueInForeground(nil, alwaysConfirm: false)
        }

        // MARK: Window

        private func library(_ live: LiveModel) -> IntentChannels {
            let states = live.sources.map { source in
                let state: IntentSource.State =
                    switch source.state {
                    case .loading: .loading
                    case .loaded: .loaded
                    case .offline: .offline
                    case .failed: .failed
                    case .waitingForLogin: .waitingForLogin
                    }
                return IntentSource(id: source.id, name: source.name, state: state)
            }
            return IntentChannels(
                catalogue: live.catalogue, sources: states, matcher: matcher(for: live.channels, rules: live.groupRules, live.catalogue))
        }

        private static func states(_ shelves: ShelfLibrary) -> [IntentSource] {
            shelves.movies.sources.map { movies in
                let series = shelves.series.sources.first { $0.id == movies.id }?.state ?? movies.state
                let state: IntentSource.State =
                    switch (movies.state, series) {
                    case (.loading, _), (_, .loading): .loading
                    case (.loaded, .loaded): .loaded
                    case (.waitingForLogin, _): .waitingForLogin
                    case (.offline, _): .offline
                    case (.failed, _), (.loaded, _): .failed
                    }
                return IntentSource(id: movies.id, name: movies.name, state: state)
            }
        }

        /// One matcher per set of channels and rules, built when either changes.
        private func matcher(for channels: [Channel], rules: GroupRules, _ catalogue: Catalogue<PersistentIdentifier>) -> ChannelMatcher {
            let inputs = MatcherInputs(channels: channels, rules: rules)
            if let matcher, matcher.from == inputs { return matcher.built }
            let built = ChannelMatcher(catalogue)
            matcher = (built, inputs)
            return built
        }

        // MARK: Background loads

        private func rules(profile: UUID) -> GroupRules {
            GroupStore.rules(
                groups: (try? context.fetch(FetchDescriptor<GroupRecord>())) ?? [],
                members: (try? context.fetch(FetchDescriptor<GroupMemberRecord>())) ?? [],
                hidden: (try? context.fetch(FetchDescriptor<HiddenGroupRecord>())) ?? [], profile: profile,
                locksOpen: dependencies.locksOpen())
        }

        /// The source's load, started once per run and shared by every
        /// action that asks while it runs. A failed load starts again.
        private func startPlaylistLoad(_ source: SourceDescriptor) -> Task<Void, Never> {
            if let running = playlistLoads[source.id] { return running }
            if playlistStates[source.id] == .loaded { return Task {} }
            let task = Task { [weak self] in
                guard let self else { return }
                if !dependencies.hasLogin(source) {
                    playlistStates[source.id] = .waitingForLogin
                } else {
                    do {
                        playlists[source.id] = try await dependencies.loadPlaylist(source).channels
                        playlistStates[source.id] = .loaded
                    } catch {
                        playlistStates[source.id] = Self.state(for: error)
                    }
                }
                playlistLoads[source.id] = nil
            }
            playlistLoads[source.id] = task
            return task
        }

        private func startCatalogueLoad(_ source: SourceDescriptor) -> Task<Void, Never> {
            if let running = catalogueLoads[source.id] { return running }
            if catalogueStates[source.id] == .loaded { return Task {} }
            let task = Task { [weak self] in
                guard let self else { return }
                if !dependencies.hasLogin(source) {
                    catalogueStates[source.id] = .waitingForLogin
                } else {
                    do {
                        let movies = try await dependencies.loadTitles(source, .movie)
                        catalogues[source.id] = movies + (try await dependencies.loadTitles(source, .series))
                        catalogueStates[source.id] = .loaded
                    } catch {
                        catalogueStates[source.id] = Self.state(for: error)
                    }
                }
                catalogueLoads[source.id] = nil
            }
            catalogueLoads[source.id] = task
            return task
        }

        /// Waits for `loads` or the deadline, whichever comes first. The
        /// loads are never canceled, so a slow source is ready next time
        /// (app-intents/a-clear-reply-when-a-channel-or-title-cannot-play).
        private func waitForDeadline(_ loads: [Task<Void, Never>]) async {
            guard !loads.isEmpty else { return }
            let sleep = dependencies.sleep
            let deadline = dependencies.deadline
            // A task group would wait for both racers; whichever finishes
            // first resumes here and the other runs on unheard.
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                let race = Race(continuation)
                Task { @MainActor in
                    for load in loads { await load.value }
                    race.finish()
                }
                Task { @MainActor in
                    try? await sleep(deadline)
                    race.finish()
                }
            }
        }

        /// Resumes its continuation once, for the first racer to finish.
        @MainActor
        private final class Race {
            private var continuation: CheckedContinuation<Void, Never>?

            init(_ continuation: CheckedContinuation<Void, Never>) {
                self.continuation = continuation
            }

            func finish() {
                continuation?.resume()
                continuation = nil
            }
        }

        private static func state(for error: any Error) -> IntentSource.State {
            let offline: Set<URLError.Code> = [.notConnectedToInternet, .networkConnectionLost, .dataNotAllowed]
            if let urlError = error as? URLError, offline.contains(urlError.code) { return .offline }
            return .failed
        }
    }

    extension AppIntentHost.Dependencies {
        /// The app's: the network and the Keychain through `loader`, the
        /// entitlement `unlock` caches, and `locks`.
        @MainActor
        static func app(container: ModelContainer, unlock: Unlock, locks: GroupLocks, loader: SourceLoader = SourceLoader()) -> Self {
            let shelf = ShelfLoader(session: loader.session, credentials: loader.credentials, playlists: loader)
            var dependencies = Self(
                container: container, isUnlocked: { unlock.gate.applied.isUnlocked }, locksOpen: { locks.isOpen },
                loadPlaylist: { try await loader.load($0) }, hasLogin: { loader.hasLogin($0) },
                loadTitles: { try await shelf.load($0, kind: $1).titles })
            #if os(iOS)
                dependencies.protectedDataAvailable = { UIApplication.shared.isProtectedDataAvailable }
                dependencies.device = UIDevice.current.userInterfaceIdiom == .pad ? .iPad : .iPhone
            #else
                dependencies.device = .mac
            #endif
            return dependencies
        }
    }
#endif
