#if os(tvOS)
    import AntennaCore
    import Foundation
    import Observation
    import os

    /// State and rules of the Apple TV shell (tvos-shell capability): the open tab, the
    /// sources as they load, the channel tuned at launch and the
    /// pause, then stop, behind Movies, Series and Search.
    @MainActor @Observable
    final class ShellModel {
        struct Dependencies {
            var engine: any PlaybackEngine
            var load: @MainActor (SourceDescriptor) async throws -> Playlist
            var hasLogin: @MainActor (SourceDescriptor) -> Bool
            var recents: RecentsStore
            /// The channels each source had on this Apple TV, for the New group.
            var seen = SeenChannelsStore.scratch
            var sleep: @MainActor (Duration) async throws -> Void
            var guide: AppGuideStore?
            var languages = ChannelLanguageStore()
            /// Where Sign in on the error stores a login.
            var credentials: any CredentialStoring = CredentialStore()
            /// The connection the player watches to recover from an offline error.
            var network: NetworkWatch = .system
            /// How long the spinner shows before it names the source as slow.
            var slowDelay = Duration.seconds(10)
            /// How the ten-second count waits, when not as `sleep`.
            var watchSleep: (@MainActor (Duration) async throws -> Void)?
            /// The tiles' engines and limit when multi-view starts.
            var multiView = MultiViewModel.Dependencies()
            /// Builds Start over's catch-up addresses.
            var catchup = CatchupAddresses()
            /// True for a file source whose playlist has not synced yet.
            var waitsForICloud: @MainActor (SourceDescriptor) -> Bool = { _ in false }
            /// The movies and episodes a source's last load had on this device, nil when unknown.
            var storedTitles: @MainActor (UUID) -> TitleCounts? = { _ in nil }
        }

        static let logger = Logger(subsystem: "se.codecrave.antenna", category: "shell")
        static let launchDeadline = Duration.seconds(10)

        private(set) var tab: ShellTab = .live
        /// True while the highlight is in the system tab bar; the shell's view reports it.
        var barFocused = false
        /// Counts select on the open tab in the bar, which sends the highlight into its page.
        private(set) var reselects = 0
        private(set) var sources: [ShellSource] = []
        private(set) var channels: [Channel] = []
        private(set) var tuned: Channel?
        /// The channels watched lately on this Apple TV, newest first.
        var recents: [LastChannelKey] = []
        /// Each loaded source's memory of its channels (new-channels).
        private(set) var seen: [UUID: SeenChannels] = [:]
        /// The programme Search asked the Guide to show; the Guide clears it once shown.
        var guideRequest: ProgrammeKey?
        private(set) var pickerOpen = false
        /// The sections the sources offer: an Xtream source, or a playlist by
        /// what its last load had (m3u-playlists/movies-and-series-show-by-what-the-sources-offer).
        var titleOffer: TitleOffer {
            TitleOffer(sourceKinds.map { ($0.id, $0.kind) }) { titleCounts[$0] }
        }
        private var sourceKinds: [(id: UUID, kind: SourceKind)] = []
        /// Each playlist's movies and episodes from its last load, seeded from
        /// what this device remembers (m3u-playlists/what-a-playlist-offered-is-remembered).
        private var titleCounts: [UUID: TitleCounts] = [:]
        /// The source Sign in on the error asks a login for, nil while closed.
        var signInRequest: SignInRequest?
        /// Multi-view over Live, nil while one channel plays.
        var multiView: MultiViewModel?
        /// Counts multi-view handing a channel back, which shows the info bar.
        private(set) var multiViewEnds = 0
        /// Counts Guide picks of the channel already in its small picture, which shows the info bar.
        var guidePicks = 0

        @ObservationIgnored let engine: any PlaybackEngine
        /// The spinner, the reconnect count and the error for the tuned channel.
        @ObservationIgnored let player: PlayerModel
        @ObservationIgnored let dependencies: Dependencies
        @ObservationIgnored private(set) var descriptors: [UUID: SourceDescriptor] = [:]
        @ObservationIgnored private var loads: [UUID: Task<Void, Never>] = [:]
        @ObservationIgnored private var channelsBySource: [UUID: [Channel]] = [:]
        @ObservationIgnored private var finishOrder: [UUID] = []
        /// The channel to tune at launch, read once.
        @ObservationIgnored var stored: LastChannelKey?
        /// True once the first `sourcesChanged` has run.
        private(set) var launched = false
        @ObservationIgnored private(set) var deadlinePassed = false
        /// A Top Shelf item waiting for its source; the launch tune waits while set.
        @ObservationIgnored var shelfItem: UUID?
        @ObservationIgnored private var deadline: Task<Void, Never>?
        /// The pause, then stop, behind Movies, Series and Search.
        @ObservationIgnored let hold: LiveHold
        /// True from opening Movies, Series or Search until Live or the
        /// Guide opens; Settings in between keeps it.
        @ObservationIgnored var behindContent = false
        /// The last tab change's work on the video; the next one waits for it.
        @ObservationIgnored private(set) var tabChange: Task<Void, Never>?
        /// What the shell did to the channel behind Movies, Series or Search, nil when nothing.
        var heldByShell: LiveHold.Kind? { hold.kind }
        var pausedByShell: Bool { heldByShell != nil }
        /// What played before the Guide's small picture first followed the
        /// highlight; nil while it shows the channel the Guide opened with.
        @ObservationIgnored var guideReturn: GuideReturn?
        /// The channel whose row the Guide's highlight rests on, and the wait before the picture tunes it.
        @ObservationIgnored var guideRest: (channel: Channel, wait: Task<Void, Never>)?
        @ObservationIgnored let languages: ChannelLanguages
        /// Stores the last channel and counts a channel as watched.
        @ObservationIgnored let session: SessionTracker

        init(_ dependencies: Dependencies) {
            self.dependencies = dependencies
            self.engine = dependencies.engine
            languages = ChannelLanguages(store: dependencies.languages, watching: dependencies.engine)
            session = SessionTracker(store: dependencies.recents, sleep: dependencies.watchSleep ?? dependencies.sleep)
            player = PlayerModel(
                .init(
                    engine: dependencies.engine, sleep: dependencies.sleep, network: dependencies.network,
                    slowDelay: dependencies.slowDelay))
            hold = LiveHold(engine: dependencies.engine, timeshift: player.timeshift, sleep: dependencies.sleep)
            player.reload = { [weak self] channel in self?.load(channel) }
            wireStartOver()
            player.hasLogin = { [weak self] id in
                guard let self, let source = descriptors[id] else { return false }
                return self.dependencies.hasLogin(source)
            }
        }

        // MARK: Derived state

        /// `.loading` until the first `sourcesChanged`, so the empty screen
        /// never flashes at launch.
        var liveScreen: LiveScreen {
            if tuned != nil { return .playing }
            if !launched { return .loading }
            return sources.contains { $0.state == .loading } ? .loading : .empty
        }

        // MARK: Sources

        /// Call on appearance and whenever the stored sources change. The first
        /// call is the launch: it reads the last channel and starts the
        /// deadline. New sources load, edited ones load again and removed ones
        /// drop out. A removed source's channel keeps playing unless every
        /// source is gone. A repeated id counts once, the first wins.
        func sourcesChanged(_ all: [SourceDescriptor]) {
            var seen: Set<UUID> = []
            let list = all.filter { seen.insert($0.id).inserted }
            sourceKinds = list.map { ($0.id, $0.kind) }
            titleCounts = titleCounts.filter { id, _ in list.contains { $0.id == id } }
            for source in list where titleCounts[source.id] == nil {
                titleCounts[source.id] = dependencies.storedTitles(source.id)
            }
            let gone = tuned?.sourceID.map { id in !list.contains { $0.id == id } } ?? false
            if tuned != nil, list.isEmpty || gone {
                // A deleted source's channel stops (sources-and-settings/delete-a-source-and-everything-that-came-with-it).
                tuned = nil
                player.tuned(nil)
                session.tuned(nil)
                Task { await engine.stop() }
            }
            if !launched {
                launched = true
                stored = dependencies.recents.read()
                startDeadline()
            }
            let ids = Set(list.map(\.id))
            if descriptors.keys.contains(where: { !ids.contains($0) }) { leaveUnofferedTab() }
            for id in descriptors.keys where !ids.contains(id) {
                loads[id]?.cancel()
                loads[id] = nil
                descriptors[id] = nil
                channelsBySource[id] = nil
                self.seen[id] = nil
                finishOrder.removeAll { $0 == id }
            }
            var changed: [SourceDescriptor] = []
            // A rename loads nothing again (sources-and-settings/changes-from-other-devices-show-up-by-themselves).
            for source in list where descriptors[source.id] != source {
                if descriptors[source.id]?.loadsLike(source) != true { changed.append(source) }
                descriptors[source.id] = source
            }
            let previous = Dictionary(uniqueKeysWithValues: sources.map { ($0.id, $0) })
            sources = list.map { source in
                var row = previous[source.id] ?? ShellSource(id: source.id, name: source.name, state: .loading)
                row.name = source.name
                return row
            }
            rebuildChannels()
            changed.forEach(startLoad)
            considerTune()
        }

        /// Loads again every source that added nothing and shows the loading
        /// screen while they load. Restarts the launch deadline when nothing
        /// is tuned.
        func retry() {
            let again = sources.filter(\.state.addedNothing)
            guard !again.isEmpty else { return }
            if tuned == nil {
                deadlinePassed = false
                startDeadline()
            }
            for row in again {
                if let source = descriptors[row.id] { startLoad(source) }
            }
        }

        /// Call when the scene becomes active after launch. A source whose
        /// login has arrived since loads, and a tuned channel the shell did
        /// not pause plays on without loading again.
        func becameActive() async {
            guard launched else { return }
            if tuned != nil, !pausedByShell { await engine.play() }
            session.stateChanged(await engine.state)
            for row in sources where row.state == .waitingForLogin {
                if let source = descriptors[row.id], dependencies.hasLogin(source) { startLoad(source) }
            }
        }

        /// A source that has channels keeps them while it loads again and when
        /// that load fails (sources-and-settings/a-failed-refresh-keeps-your-channels).
        private func startLoad(_ source: SourceDescriptor) {
            loads[source.id]?.cancel()
            if channelsBySource[source.id]?.isEmpty ?? true {
                channelsBySource[source.id] = nil
                finishOrder.removeAll { $0 == source.id }
                setState(.loading, for: source.id)
            }
            rebuildChannels()
            loads[source.id] = Task { [weak self] in
                guard let self else { return }
                let result: Result<Playlist, any Error>
                if !dependencies.hasLogin(source) {
                    result = .failure(LoadFailure.waitingForLogin)
                } else {
                    do {
                        result = .success(try await dependencies.load(source))
                    } catch {
                        result = .failure(error)
                    }
                }
                guard !Task.isCancelled else { return }
                await finish(source, with: result)
            }
        }

        private static func state(for error: any Error) -> ShellSource.State {
            if case LoadFailure.waitingForLogin? = error as? LoadFailure { return .waitingForLogin }
            let offline: Set<URLError.Code> = [.notConnectedToInternet, .networkConnectionLost, .dataNotAllowed]
            if let urlError = error as? URLError, offline.contains(urlError.code) { return .offline }
            return .failed
        }

        private func setState(_ state: ShellSource.State, for id: UUID) {
            guard let index = sources.firstIndex(where: { $0.id == id }) else { return }
            sources[index].state = state
            sources[index].waitsForICloud = state == .waitingForLogin && descriptors[id].map(dependencies.waitsForICloud) == true
        }

        /// Leaves `channels` alone when a reload brought the same list, so
        /// the screens reading it do not redraw.
        private func rebuildChannels() {
            let all = sources.flatMap { channelsBySource[$0.id] ?? [] }
            if all != channels { channels = all }
        }

        // MARK: Launch tune

        private func startDeadline() {
            deadline?.cancel()
            deadline = Task { [weak self] in
                guard let self else { return }
                do {
                    try await dependencies.sleep(Self.launchDeadline)
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                deadlinePassed = true
                considerTune()
            }
        }

        /// Tunes once: the stored channel when its source loads before the
        /// deadline, otherwise the first channel of the first source that
        /// finished with channels. Nothing changes once a channel is tuned.
        func considerTune() {
            guard tuned == nil, launched, shelfItem == nil else { return }
            if let stored, !deadlinePassed {
                let state = sources.first { $0.id == stored.sourceID }?.state
                if state == .loading { return }
                if let match = channelsBySource[stored.sourceID]?.first(where: stored.matches) {
                    tune(match)
                    return
                }
            }
            guard let first = finishOrder.first, let channel = channelsBySource[first]?.first else { return }
            tune(channel)
        }

        /// Plays `channel` full screen. A successful load writes the last
        /// channel; a failed one leaves the stored channel as it was. With
        /// `remember` false, as for the Guide's small picture following the
        /// highlight, the channel is neither stored nor counted as watched.
        func tune(_ channel: Channel, remember: Bool = true) {
            if remember { guideReturn = nil } else { session.tuned(nil) }
            tuned = channel
            player.tuned(subject(for: channel))
            deadline?.cancel()
            load(channel, remember: remember)
        }

        // MARK: Navigation

        /// The system tab bar moved to `target`, by focus or by select. The
        /// page changes at once and the video follows in order. Picked again,
        /// the open tab sends the highlight onto its page.
        func choose(_ target: ShellTab) {
            guard target != tab else {
                reselects += 1
                return
            }
            switchTab(to: target, picked: true)
        }

        /// Opens `target` from code, as Search, a reminder or a shelf link
        /// do, and returns where focus goes: the picture or the Live screen
        /// on Live, nil elsewhere, where the tab bar or the page takes it.
        @discardableResult
        func select(_ target: ShellTab) async -> ShellFocus? {
            _ = await switchTab(to: target, picked: true).value
            return target == .live ? liveFocus : nil
        }

        /// Where focus goes on Live: the picture once tuned, Try again while
        /// the error shows, else the loading or empty screen.
        var liveFocus: ShellFocus {
            guard tuned != nil else { return .liveScreen }
            return player.failure == nil ? .picture : .retry
        }

        /// Shows `target` now and queues what the video does behind it after
        /// any earlier tab change. Movies, Series and Search hold the video;
        /// Live and the Guide end the hold, resuming a paused video and
        /// tuning a stopped one again; Settings leaves it as it is. Live
        /// `picked` by the user also loads a failed stream again. True when
        /// the channel loads again.
        @discardableResult
        private func switchTab(to target: ShellTab, picked: Bool = false) -> Task<Bool, Never> {
            let from = tab
            tab = target
            pickerOpen = false
            let previous = tabChange
            let change = Task { [weak self] in
                await previous?.value
                guard let self else { return false }
                return await opened(target, from: from, picked: picked)
            }
            tabChange = Task { _ = await change.value }
            return change
        }

        private func opened(_ target: ShellTab, from: ShellTab, picked: Bool) async -> Bool {
            if from == .guide, target != .guide { await leaveGuide() }
            switch target {
            case .movies, .series, .search:
                guard !behindContent else { return false }
                behindContent = true
                await holdBehindContent()
                return false
            case .settings:
                return false
            case .live, .guide:
                behindContent = false
                if await resume() { return true }
                // The Guide's small picture plays on a stream the user paused (tv-guide-grid/the-channel-keeps-playing-in-a-small-picture).
                // A pause the user made stays (timeshift-catch-up-and-start-over/leaving-the-app-calls-and-other-interruptions).
                if target == .guide, !player.timeshift.userPaused, await engine.state == .paused { await engine.play() }
                // A failed stream, or one a movie stopped, loads again.
                if target == .live, picked, let tuned, await engine.state.hasStopped {
                    tune(tuned)
                    return true
                }
                return false
            }
        }

        /// Live full screen with the picker closed.
        func showLive() async {
            _ = await switchTab(to: .live).value
        }

        /// Opens Search, Settings or the Guide at a programme. Closes the picker first.
        func show(_ destination: ShellNavigator.Destination) async {
            switch destination {
            case .search:
                _ = await switchTab(to: .search).value
            case .settings:
                _ = await switchTab(to: .settings).value
            case .guide(let programmeKey):
                guideRequest = programmeKey
                _ = await switchTab(to: .guide).value
            }
        }
    }

    // The setters these need are private to this file.
    extension ShellModel {
        // MARK: Channel picker (stand-in for the channel overlay)

        func openPicker() {
            pickerOpen = true
        }

        func closePicker() {
            pickerOpen = false
        }

        /// Multi-view ended with `channel`'s player now playing here with no
        /// reload, or with every tile stopped when nil (multi-view/leave-multi-view).
        /// It counts as one channel change, and the channel is the last one.
        func multiViewEnded(keeping channel: Channel?) async {
            multiView = nil
            tuned = channel
            player.tuned(channel.map(subject(for:)))
            session.tuned(channel)
            multiViewEnds += 1
            guard let channel else { return }
            if let key = LastChannelKey(channel) { session.store.write(key) }
            let state = await engine.state
            player.stateChanged(state)
            session.stateChanged(state)
        }
    }

    extension ShellModel {
        /// Movies or Series open after its last source stopped offering it
        /// shows Live (m3u-playlists/movies-and-series-show-by-what-the-sources-offer).
        private func leaveUnofferedTab() {
            guard !tabs.contains(tab) else { return }
            Task { await showLive() }
        }

        private func finish(_ source: SourceDescriptor, with result: Result<Playlist, any Error>) async {
            loads[source.id] = nil
            switch result {
            case .success(let playlist):
                let tagged = Channel.tagged(playlist.channels, sourceID: source.id)
                titleCounts[source.id] = TitleCounts(movies: playlist.movies.count, episodes: playlist.episodes.count)
                leaveUnofferedTab()
                channelsBySource[source.id] = tagged
                seen[source.id] = dependencies.seen.record(source.id, channelIDs: tagged.map(\.id))
                setState(.loaded(channels: tagged.count), for: source.id)
                if !tagged.isEmpty { finishOrder.append(source.id) }
                rebuildChannels()
                considerTune()
                if let guide = dependencies.guide {
                    await guide.register(epgURLs: playlist.epgURLs, for: source.id)
                    await guide.update(channels: tagged)
                    await guide.refreshIfStale(now: .now)
                }
            case .failure(let error):
                let state = Self.state(for: error)
                if let kept = channelsBySource[source.id], !kept.isEmpty, state != .waitingForLogin {
                    setState(.loaded(channels: kept.count), for: source.id)
                    return
                }
                channelsBySource[source.id] = nil
                finishOrder.removeAll { $0 == source.id }
                rebuildChannels()
                setState(state, for: source.id)
                considerTune()
            }
        }

        /// Loads the sources in `ids` again, in the order given. Their channels
        /// stay while they load (sources-and-settings/refresh-by-hand).
        func reload(_ ids: [UUID]) {
            for id in ids {
                if let source = descriptors[id] { startLoad(source) }
            }
        }
    }
#endif
