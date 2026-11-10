#if os(tvOS)
    import AntennaCore
    import Foundation
    import Observation
    import os

    /// The tabs of the Apple TV shell, in bar order.
    enum ShellTab: Hashable, CaseIterable, Sendable {
        case live, guide, movies, series, search

        /// Movies, Series and Search: the bar always shows and the video
        /// pauses after a while behind them.
        var isContent: Bool { self == .movies || self == .series || self == .search }
    }

    /// Where focus goes after the shell handles an input.
    enum ShellFocus: Hashable {
        /// Full-screen Live with a channel tuned.
        case picture
        /// The loading screen's holder or the empty screen's Retry.
        case liveScreen
        case tab(ShellTab)
        case settings
        case content
        /// A group, channel or the Search entry in the channel overlay.
        case overlay(OverlayFocus)
    }

    /// Where Menu was pressed.
    enum MenuOrigin: Equatable {
        /// Full-screen Live, or its loading or empty screen.
        case picture
        /// The top level of an open tab.
        case content
        case bar
    }

    /// A programme another screen asks the Guide to show.
    struct ProgrammeKey: Hashable, Sendable {
        var guideKey: GuideKey
        var start: Date
    }

    /// One source as the loading and empty screens list it.
    struct ShellSource: Identifiable, Equatable, Sendable {
        enum State: Equatable, Sendable {
            case loading
            case loaded(channels: Int)
            case offline
            case failed
            case waitingForLogin

            /// True once the source finished and added nothing: loaded empty,
            /// offline, failed or waiting for its login.
            var addedNothing: Bool { self != .loading && !isLoadedWithChannels }

            var isLoadedWithChannels: Bool {
                if case .loaded(let count) = self { return count > 0 }
                return false
            }
        }

        var id: UUID
        var name: String
        var state: State
    }

    /// What Live shows when nothing has been tuned yet, or the picture.
    enum LiveScreen: Equatable {
        case playing, loading, empty
    }

    /// State and rules of the Apple TV shell (tvos-shell capability): the open tab, the
    /// bar, the sources as they load, the channel tuned at launch and the
    /// pause behind Movies, Series and Search.
    @MainActor @Observable
    final class ShellModel {
        struct Dependencies {
            var engine: any PlaybackEngine
            var load: @MainActor (SourceDescriptor) async throws -> Playlist
            var hasLogin: @MainActor (SourceDescriptor) -> Bool
            var lastChannel: LastChannelStore
            var sleep: @MainActor (Duration) async throws -> Void
            var guide: AppGuideStore?
            var languages = ChannelLanguageStore()
        }

        /// Thrown by a loader for a source whose login is not on this device.
        enum LoadFailure: Error { case waitingForLogin }

        static let logger = Logger(subsystem: "se.codecrave.antenna", category: "shell")
        static let launchDeadline = Duration.seconds(10)
        static let pauseDelay = Duration.seconds(30)

        private(set) var tab: ShellTab = .live
        private(set) var barRaised = false
        private(set) var sources: [ShellSource] = []
        private(set) var channels: [Channel] = []
        private(set) var tuned: Channel?
        private(set) var guideRequest: ProgrammeKey?
        private(set) var pickerOpen = false
        private(set) var offersMovies = false
        var settingsOpen = false

        @ObservationIgnored let engine: any PlaybackEngine
        @ObservationIgnored private let dependencies: Dependencies
        @ObservationIgnored private var descriptors: [UUID: SourceDescriptor] = [:]
        @ObservationIgnored private var loads: [UUID: Task<Void, Never>] = [:]
        @ObservationIgnored private var channelsBySource: [UUID: [Channel]] = [:]
        @ObservationIgnored private var finishOrder: [UUID] = []
        @ObservationIgnored private var stored: LastChannelKey?
        private var launched = false
        @ObservationIgnored private var deadlinePassed = false
        @ObservationIgnored private var deadline: Task<Void, Never>?
        @ObservationIgnored private var pauseTimer: Task<Void, Never>?
        @ObservationIgnored private(set) var pausedByShell = false
        @ObservationIgnored private let languages: ChannelLanguages

        init(_ dependencies: Dependencies) {
            self.dependencies = dependencies
            self.engine = dependencies.engine
            languages = ChannelLanguages(store: dependencies.languages, watching: dependencies.engine)
        }

        // MARK: Derived state

        /// The bar shows when raised by Menu and always on Movies, Series and Search.
        var barVisible: Bool { barRaised || tab.isContent }

        /// The picture or guide is dimmed under the raised bar.
        var dimmed: Bool { barRaised && !tab.isContent }

        /// The tabs the bar lists: Movies and Series only with an Xtream source (movies-and-series-browsing/movies-and-series-appear-when-your-provider-has-them).
        var tabs: [ShellTab] {
            ShellTab.allCases.filter { offersMovies || ($0 != .movies && $0 != .series) }
        }

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
            offersMovies = list.contains { $0.kind == .xtream }
            if list.isEmpty, tuned != nil {
                // With every source gone nothing keeps playing (stand-in behavior).
                tuned = nil
                Task { await engine.stop() }
            }
            if !launched {
                launched = true
                stored = dependencies.lastChannel.read()
                startDeadline()
            }
            let ids = Set(list.map(\.id))
            for id in descriptors.keys where !ids.contains(id) {
                loads[id]?.cancel()
                loads[id] = nil
                descriptors[id] = nil
                channelsBySource[id] = nil
                finishOrder.removeAll { $0 == id }
            }
            var changed: [SourceDescriptor] = []
            for source in list where descriptors[source.id] != source {
                descriptors[source.id] = source
                changed.append(source)
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
            for row in sources where row.state == .waitingForLogin {
                if let source = descriptors[row.id], dependencies.hasLogin(source) { startLoad(source) }
            }
        }

        private func startLoad(_ source: SourceDescriptor) {
            loads[source.id]?.cancel()
            channelsBySource[source.id] = nil
            finishOrder.removeAll { $0 == source.id }
            setState(.loading, for: source.id)
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

        private func finish(_ source: SourceDescriptor, with result: Result<Playlist, any Error>) async {
            loads[source.id] = nil
            switch result {
            case .success(let playlist):
                let tagged = Channel.tagged(playlist.channels, sourceID: source.id)
                channelsBySource[source.id] = tagged
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
                setState(Self.state(for: error), for: source.id)
                considerTune()
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
        }

        private func rebuildChannels() {
            channels = sources.flatMap { channelsBySource[$0.id] ?? [] }
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
        private func considerTune() {
            guard tuned == nil, launched else { return }
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
        /// channel; a failed one leaves the stored channel as it was.
        func tune(_ channel: Channel) {
            tuned = channel
            deadline?.cancel()
            Task {
                do {
                    try await engine.load(channel.streamURL, options: languages.options(for: channel))
                } catch is CancellationError {
                    return
                } catch {
                    Self.logger.info("tune failed, the stored channel is kept")
                    return
                }
                guard tuned == channel else { return }
                // A pause from the timer while the load ran stands.
                if !pausedByShell { await engine.play() }
                if let key = LastChannelKey(channel) { dependencies.lastChannel.write(key) }
            }
        }

        // MARK: Navigation

        /// Handles Menu at the shell. Content screens deeper than their root,
        /// and the picker, consume Menu before it gets here.
        func menu(from origin: MenuOrigin) async -> ShellFocus {
            switch origin {
            case .picture:
                barRaised = true
                return .tab(.live)
            case .content:
                if tab == .guide { barRaised = true }
                return .tab(tab)
            case .bar:
                if tab == .live {
                    barRaised = false
                    return liveFocus
                }
                await showLive()
                return liveFocus
            }
        }

        /// Select on a tab in the bar.
        func select(_ target: ShellTab) async -> ShellFocus {
            switch target {
            case .live:
                await showLive()
                if let tuned, case .failed = await engine.state { tune(tuned) }
                return liveFocus
            case .guide:
                await open(.guide)
                return .content
            case .movies, .series, .search:
                await open(target)
                return .content
            }
        }

        /// Swipe down while the bar has focus. Nil when the bar stays.
        func swipeDown() -> ShellFocus? {
            guard barRaised, !tab.isContent else { return nil }
            barRaised = false
            return tab == .live ? liveFocus : .content
        }

        /// Where focus goes on Live: the picture once tuned, else the loading
        /// or empty screen.
        var liveFocus: ShellFocus { tuned == nil ? .liveScreen : .picture }

        /// Opens `target`, lowering the bar. Entering Movies, Series or Search
        /// from Live or Guide starts the pause timer; leaving them for Live or
        /// Guide resumes a video the shell paused.
        private func open(_ target: ShellTab) async {
            let wasContent = tab.isContent
            tab = target
            barRaised = false
            pickerOpen = false
            if target.isContent {
                if !wasContent { startPauseTimer() }
            } else {
                await resume()
            }
        }

        /// Live full screen, the bar lowered and the picker closed.
        func showLive() async {
            await open(.live)
        }

        /// Opens Search or the Guide at a programme. Closes the picker first.
        func show(_ destination: ShellNavigator.Destination) async {
            switch destination {
            case .search:
                await open(.search)
            case .guide(let programmeKey):
                guideRequest = programmeKey
                await open(.guide)
            }
        }

        // MARK: Pause behind content tabs

        private func startPauseTimer() {
            pauseTimer?.cancel()
            pauseTimer = Task { [weak self] in
                guard let self else { return }
                do {
                    try await dependencies.sleep(Self.pauseDelay)
                } catch {
                    return
                }
                guard !Task.isCancelled, tab.isContent else { return }
                switch await engine.state {
                case .playing, .loading, .buffering, .reconnecting:
                    await engine.pause()
                    pausedByShell = true
                case .idle, .paused, .ended, .failed:
                    break
                }
            }
        }

        private func resume() async {
            pauseTimer?.cancel()
            pauseTimer = nil
            guard pausedByShell else { return }
            pausedByShell = false
            await engine.play()
        }

        /// The navigator other screens use; `ShellView` provides it.
        var navigator: ShellNavigator { .forwarding(to: self) }

        // MARK: Channel picker (stand-in for the channel overlay)

        func openPicker() {
            pickerOpen = true
        }

        func closePicker() {
            pickerOpen = false
        }

        /// Tunes `channel` from the picker and shows Live full screen.
        func pick(_ channel: Channel) async {
            if channel != tuned { tune(channel) }
            await showLive()
        }
    }
#endif
