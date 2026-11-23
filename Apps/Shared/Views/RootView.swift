#if os(iOS) || os(macOS)
    import AntennaCore
    import SwiftData
    import SwiftUI

    /// The window root on iPhone, iPad and Mac. Owns the Live model and its
    /// engine, so the channel plays on whichever layout is shown. Apple TV
    /// opens on `ShellView` instead (tvos-shell capability).
    struct RootView: View {
        @Environment(\.sourceLoader) private var loader
        @Environment(\.guideStore) private var guideStore
        @Environment(\.currentProfile) private var profile
        @Environment(\.switchProfile) private var switchProfile
        @Environment(\.onboardingHandoff) private var handoff
        @Environment(\.sourceRefresher) private var refresher
        @Environment(\.intentHost) private var intentHost
        @State private var live: LiveModel?
        @State private var shelves: ShelfLibrary?
        @State private var playback: ShelfPlayback?
        @State private var lifecycle: PlaybackLifecycle?
        /// Search keeps its query across tabs and layouts.
        @State private var search = SearchModel()
        /// The Guide keeps its day, zoom and details across layouts.
        @State private var guide = GuideBoardModel(store: .app)
        #if os(iOS)
            @Environment(\.horizontalSizeClass) private var sizeClass
        #endif

        var body: some View {
            ZStack {
                Palette.ground.ignoresSafeArea()
                if let live, let shelves, let playback {
                    layout
                        .environment(search)
                        .environment(guide)
                        // Playback stops before "Who's watching?" (profiles/switching-profile).
                        .environment(\.switchProfile, stopping(live))
                        .modifier(LiveSync(live: live))
                        .modifier(ShelfSync(library: shelves, playback: playback))
                        .environment(\.publishesMenuCommands, !compact)
                        .onChange(of: compact, initial: true) { _, compact in guide.compact = compact }
                }
            }
            .preferredColorScheme(.dark)
            .guideRefreshTriggers()
            // Leaving the app's screens, as when it locks, stops what plays.
            .onDisappear { Task { [engine = live?.engine] in await engine?.stop() } }
            .task {
                guard live == nil else { return }
                let live = LiveModel(dependencies())
                let engine = live.engine
                // Live keeps its sound when the app leaves the screen
                // (player-controls-and-playback-errors/keep-listening-in-the-background).
                let lifecycle = PlaybackLifecycle(engine: engine) { true }
                lifecycle.follow(live.player.timeshift)
                lifecycle.start()
                self.live = live
                refresher?.attach { [weak live] in live?.reload($0) }
                // Start watching in onboarding plays its first channel here.
                if let channel = handoff?.takeChannel() { live.pick(channel) }
                let shelves = ShelfLibrary.app(loader)
                self.shelves = shelves
                self.playback = .app(loader) { await live.suspend() }
                intentHost?.attach(live: live, shelves: shelves, profile: profile)
                self.lifecycle = lifecycle
            }
        }

        /// The tab bar on every iPhone and in a narrow iPad window, the
        /// columns on a wider iPad window and on Mac. Both read the same model.
        @ViewBuilder private var layout: some View {
            if compact {
                CompactTabs()
                    .modifier(PhoneSizeClass())
            } else {
                LiveRegularView()
            }
        }

        /// A Plus or Pro Max iPhone held sideways reports a regular width
        /// and still gets the tab bar (live-tv-on-iphone-ipad-mac/every-iphone-keeps-the-phone-layout).
        private var compact: Bool {
            #if os(iOS)
                sizeClass == .compact || UIDevice.current.userInterfaceIdiom == .phone || forcedCompact
            #else
                false
            #endif
        }

        /// `switchProfile` after the engine stops; nil outside a profile gate.
        private func stopping(_ live: LiveModel) -> SwitchProfileAction? {
            guard let switchProfile else { return nil }
            return SwitchProfileAction {
                Task {
                    await live.engine.stop()
                    switchProfile()
                }
            }
        }

        private var forcedCompact: Bool {
            #if DEBUG
                UITestingLive.Layout.shared.compact
            #else
                false
            #endif
        }

        private func dependencies() -> LiveModel.Dependencies {
            #if DEBUG
                if var scripted = UITestingLive.dependencies() {
                    scripted.launchLogins = UITestingRecents.launchLogins
                    // Settings reads the scripted sources' status from the app's refresher.
                    if let refresher {
                        scripted.load = { try await refresher.load($0) }
                        scripted.hasLogin = { refresher.hasLogin($0) }
                    }
                    return scripted
                }
                if let scripted = UITestingShelf.liveDependencies() { return scripted }
                if let scripted = UITestingOnboarding.loader() {
                    var dependencies = LiveModel.Dependencies.live(loader: scripted, guide: nil, profile: profile)
                    let log = ProcessInfo.processInfo.environment[UITestingLive.logVariable].map { URL(fileURLWithPath: $0) }
                    dependencies.engine = UITestingLive.Engine(log: log)
                    return dependencies
                }
            #endif
            return .live(loader: loader, guide: guideStore, profile: profile, refresher: refresher)
        }
    }

    /// The tab bar on iPhone and in a narrow iPad window: Live, Guide, Movies
    /// and Series, with Search as the system's search button at the trailing
    /// end (live-tv-on-iphone-ipad-mac/the-iphone-tab-bar). Movies and Series
    /// each show only when a source offers them
    /// (m3u-playlists/playlist-titles-show-on-every-platform). Settings opens
    /// as a sheet from the profile button.
    private struct CompactTabs: View {
        enum Tab: Hashable { case live, guide, movies, series, search }
        @State private var selection: Tab = .live
        /// Settings over the open tab, from the profile button or a link.
        @State private var settingsShown = false
        /// Taps on the tab that was already open, per tab.
        @State private var taps: [Tab: Int] = [:]
        /// The tab Search was opened from, where Cancel goes back to.
        @State private var beforeSearch: Tab = .live
        @Environment(LiveModel.self) private var live
        @Environment(ShelfLibrary.self) private var shelves
        @Environment(\.sourceRefresher) private var refresher
        @Environment(ShelfActivity.self) private var activity
        @Environment(ShelfPlayback.self) private var playback
        @Query private var records: [SourceRecord]
        /// The last session's tab was opened once, at the first appearance.
        @State private var restored = false
        @Environment(GuideBoardModel.self) private var guide
        @Environment(\.onboardingHandoff) private var handoff
        @Query private var preferences: [PreferencesRecord]
        #if os(iOS)
            @Environment(\.verticalSizeClass) private var verticalSizeClass
        #endif

        /// Movies and Series each show when the sources offer them
        /// (m3u-playlists/playlist-titles-show-on-every-platform).
        private var offer: TitleOffer { shelves.offer }

        /// The offer read straight from the store and the remembered counts,
        /// for the first appearance before `ShelfSync` has run.
        private var storedOffer: TitleOffer { TitleOffer(records: records, refresher: refresher) }

        var body: some View {
            TabView(selection: tabSelection) {
                SwiftUI.Tab("Live", systemImage: "tv", value: .live) {
                    LiveCompactView()
                        .environment(\.tabTaps, taps[.live, default: 0])
                }
                SwiftUI.Tab("Guide", systemImage: "list.bullet.rectangle", value: .guide) {
                    GuideCompactScreen()
                        .environment(\.guideBoardOpenLive, GuideOpenLiveAction { selection = .live })
                        .environment(\.tabTaps, taps[.guide, default: 0])
                }
                if offer.movies {
                    SwiftUI.Tab("Movies", systemImage: LiveSection.movies.systemImage, value: .movies) {
                        titles(.movie)
                    }
                }
                if offer.series {
                    SwiftUI.Tab("Series", systemImage: LiveSection.series.systemImage, value: .series) {
                        titles(.series)
                    }
                }
                // The system draws the search tab as its own round button at the trailing end.
                SwiftUI.Tab(value: .search, role: .search) {
                    SearchCompactScreen { selection = beforeSearch }
                        .modifier(SearchSupply(picks: picks))
                        .environment(\.tabTaps, taps[.search, default: 0])
                }
            }
            .environment(\.showSettings, ShowSettingsAction { settingsShown = true })
            .sheet(isPresented: $settingsShown) {
                SettingsView()
                    .environment(\.closeSettings, ShowSettingsAction { settingsShown = false })
                    // The banner shows over Settings too (programme-reminders/a-banner-while-antenna-is-open).
                    .reminderBanner(live: live, watch: { watch($0) }, showLive: showLive)
                    .overlay(alignment: .bottomLeading) {
                        #if DEBUG
                            // The channel behind the sheet, for the UI tests.
                            UITestingLive.Probe(engine: live.engine)
                                .frame(width: 60, height: 30)
                                .allowsHitTesting(false)
                        #endif
                    }
            }
            // No channel plays behind Settings; closing it goes back to the tab as it was
            // (live-tv-on-iphone-ipad-mac/settings-from-the-profile-button).
            .onChange(of: settingsShown) { _, shown in live.settingsSheet(shown: shown, over: selection.session) }
            // A narrow iPad window that widens drops the sheet with the tab bar.
            .onDisappear { if settingsShown { live.settingsSheet(shown: false, over: selection.session) } }
            // Movies or Series goes when no source offers it.
            .onChange(of: offer) { _, offer in
                if selection == .movies, !offer.movies { selection = .live }
                if selection == .series, !offer.series { selection = .live }
            }
            .onChange(of: selection) { old, new in
                if new == .search, old != .search { beforeSearch = old }
                live.opened(new.session)
            }
            // Opens on the tab the user left (session-restore-and-recently-watched/reopen-on-the-same-tab-and-group).
            .onAppear {
                guard !restored else { return }
                restored = true
                selection = Tab(live.restoredTab, offer: storedOffer)
                // Browse movies in onboarding opens Movies; otherwise the launch
                // preference, when not Live, wins over the restored tab
                // (sources-and-settings/choose-how-the-app-behaves).
                let titles = Tab(LiveSection.titles(storedOffer))
                defer { live.screenRestored(onLive: selection == .live) }
                if handoff?.takeMovies() == true { return selection = titles }
                switch PreferencesStore.current(preferences).launchScreen(offersMovies: storedOffer.any) {
                case .live: break
                case .guide: selection = .guide
                case .movies: selection = titles
                }
            }
            .environment(\.shellNavigator, navigator)
            .modifier(IntentRequests(navigator: navigator))
            .reminderBanner(live: live, watch: { watch($0) }, showLive: showLive)
            // A movie that ends over Live, as one Siri started, brings Live
            // back as if it had just opened: the channel plays again
            // (live-tv-on-iphone-ipad-mac/sideways-on-iphone-fills-the-screen).
            .onChange(of: playback.playing == nil) { _, ended in
                if ended, selection == .live { live.appeared() }
            }
            #if os(iOS)
                // An iPhone held sideways on Live with a channel playing fills
                // the screen however it got there; turning it upright returns
                // to the list (live-tv-on-iphone-ipad-mac/sideways-on-iphone-fills-the-screen).
                .onChange(of: sidewaysLive, initial: true) { old, new in
                    if new.sideways, new.channel != nil {
                        live.setFullScreen(true)
                    } else if old.sideways, !new.sideways {
                        live.setFullScreen(false)
                    }
                }
            #endif
        }

        /// The selection, counting a tap on the tab already open
        /// (live-tv-on-iphone-ipad-mac/tap-the-open-tab-to-go-back-to-the-top).
        private var tabSelection: Binding<Tab> {
            Binding {
                selection
            } set: { tab in
                if tab == selection { taps[tab, default: 0] += 1 }
                selection = tab
            }
        }

        #if os(iOS)
            /// What sideways full screen depends on. A new channel while
            /// sideways fills the screen again after Exit full screen. A movie
            /// or episode playing over Live counts as leaving it, so closing
            /// one fills the screen again.
            private var sidewaysLive: SidewaysLive {
                SidewaysLive(
                    sideways: selection == .live && verticalSizeClass == .compact && UIDevice.current.userInterfaceIdiom == .phone
                        && playback.playing == nil,
                    channel: live.playing)
            }
        #endif
    }

    private struct SidewaysLive: Equatable {
        let sideways: Bool
        let channel: Channel?
    }

    /// Every iPhone reads as compact width in either orientation, so the
    /// tab bar, the track picker, Guide sources and the reminder banner keep
    /// their phone layout on a Plus or Pro Max held sideways. The override
    /// sits on the window scene, so UIKit's tab bar and SwiftUI agree.
    private struct PhoneSizeClass: ViewModifier {
        func body(content: Content) -> some View {
            #if os(iOS)
                content.task { Self.overrideScenes() }
            #else
                content
            #endif
        }

        #if os(iOS)
            @MainActor private static func overrideScenes() {
                guard UIDevice.current.userInterfaceIdiom == .phone else { return }
                for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
                    scene.traitOverrides.horizontalSizeClass = .compact
                }
            }
        #endif
    }

    extension CompactTabs.Tab {
        /// The tab the sidebar section maps to. Settings has no tab and opens Live.
        init(_ section: LiveSection) {
            switch section {
            case .guide: self = .guide
            case .movies: self = .movies
            case .series: self = .series
            case .search: self = .search
            case .live, .settings: self = .live
            }
        }

        /// The tab a session left open. Movies or Series with nothing
        /// offered, Search and Settings open Live, as in the sidebar.
        init(_ tab: LiveSession.Tab, offer: TitleOffer) {
            self.init(LiveSection(tab, offer: offer))
        }

        init(_ kind: ShelfTitle.Kind) {
            self = kind == .movie ? .movies : .series
        }

        var session: LiveSession.Tab {
            switch self {
            case .live: .live
            case .guide: .guide
            case .movies: .movies
            case .series: .series
            case .search: .search
            }
        }
    }

    extension CompactTabs {
        /// A channel or programme plays in Live; a movie plays and a series
        /// opens its page, as from the Movies tab
        /// (search/pick-a-channel-or-title-to-watch).
        private var picks: SearchPicks {
            SearchPicks(
                channel: { watch($0) },
                programme: { hit, channel in
                    guard !hit.isOnNow, navigator.showLater(hit.programme, on: channel) else { return watch(channel) }
                },
                title: { title in
                    switch title.kind {
                    case .movie: playback.play(title, library: shelves, activity: activity)
                    case .series: shelves.openPage(title, from: .search, in: title.kind)
                    }
                },
                person: { shelves.openPerson($0, fromSearchIn: .movie) })
        }

        /// Opens Search, the Guide at a programme, or Live, and sets the
        /// group Live and the Guide share.
        /// Settings opens as a sheet over the open tab; any other place closes
        /// the sheet first.
        private var navigator: ShellNavigator {
            .window(live: live, guide: guide) { place in
                guard place != .settings else { return settingsShown = true }
                settingsShown = false
                selection = Tab(LiveSection(place))
            }
        }

        /// The Movies or Series tab's screen.
        private func titles(_ kind: ShelfTitle.Kind) -> some View {
            ShelfCompactScreen(kind: kind)
                .environment(\.tabTaps, taps[Tab(kind), default: 0])
                .overlay(alignment: .bottomLeading) {
                    #if DEBUG
                        // The channel behind the tab, for the UI tests, out of the way of the header.
                        UITestingLive.Probe(engine: live.engine)
                            .frame(width: 60, height: 30)
                            .allowsHitTesting(false)
                    #endif
                }
        }

        /// Shows Live with `channel` playing, in All channels when the open
        /// group does not hold it. Search keeps its query.
        private func watch(_ channel: Channel) {
            if let key = RowKey(channel), !live.catalogue.rows(in: live.group).contains(key) { live.show(.all, picked: false) }
            live.pick(channel)
            showLive()
        }

        /// Closes Settings and opens Live.
        private func showLive() {
            settingsShown = false
            selection = .live
        }
    }

    #Preview("Root, no sources") {
        RootView()
            .modelContainer(for: [SourceRecord.self, FavoriteRecord.self], inMemory: true)
    }
#endif
