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
        private func stopping(_ live: LiveModel) -> (@MainActor () -> Void)? {
            guard let switchProfile else { return nil }
            return {
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

    /// The tab bar on iPhone and in a narrow iPad window: Live, Guide, Movies, Search and Settings. Series
    /// sits inside Movies, and Movies shows only when a source offers titles
    /// (m3u-playlists/playlist-titles-show-on-every-platform).
    private struct CompactTabs: View {
        enum Tab: Hashable { case live, guide, movies, search, settings }
        @State private var selection: Tab = .live
        /// The tab Search was opened from, where Cancel goes back to.
        @State private var beforeSearch: Tab = .live
        @Environment(LiveModel.self) private var live
        @Environment(ShelfLibrary.self) private var shelves
        @Environment(\.sourceRefresher) private var refresher
        @Environment(ShelfActivity.self) private var activity
        @Environment(ShelfPlayback.self) private var playback
        @Environment(SearchModel.self) private var search
        @Query private var records: [SourceRecord]
        /// The last session's tab was opened once, at the first appearance.
        @State private var restored = false
        @Environment(GuideBoardModel.self) private var guide
        @Environment(\.onboardingHandoff) private var handoff
        @Query private var preferences: [PreferencesRecord]
        #if os(iOS)
            @Environment(\.verticalSizeClass) private var verticalSizeClass
        #endif

        /// Movies, with Series inside, shows when the sources offer either
        /// (m3u-playlists/playlist-titles-show-on-every-platform).
        private var showsMovies: Bool { shelves.offer.any }

        /// The offer read straight from the store and the remembered counts,
        /// for the first appearance before `ShelfSync` has run.
        private var storedOffer: TitleOffer { TitleOffer(records: records, refresher: refresher) }

        var body: some View {
            TabView(selection: $selection) {
                SwiftUI.Tab("Live", systemImage: "tv", value: .live) {
                    LiveCompactView()
                }
                SwiftUI.Tab("Guide", systemImage: "list.bullet.rectangle", value: .guide) {
                    GuideCompactScreen()
                        .environment(\.guideBoardOpenLive) { selection = .live }
                }
                if showsMovies {
                    SwiftUI.Tab("Movies", systemImage: "film", value: .movies) {
                        ShelfCompactScreen()
                            .environment(\.openSearch, opener)
                    }
                }
                SwiftUI.Tab("Search", systemImage: "magnifyingglass", value: .search) {
                    SearchCompactScreen { selection = beforeSearch }
                        .modifier(SearchSupply(picks: picks))
                }
                SwiftUI.Tab("Settings", systemImage: "gearshape", value: .settings) {
                    SettingsView()
                }
            }
            // The Movies tab goes when no source offers titles.
            .onChange(of: showsMovies) { _, has in
                if !has, selection == .movies { selection = .live }
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
                if handoff?.takeMovies() == true { return selection = .movies }
                switch PreferencesStore.current(preferences).launchScreen(offersMovies: storedOffer.any) {
                case .live: break
                case .guide: selection = .guide
                case .movies: selection = .movies
                }
            }
            .environment(\.shellNavigator, navigator)
            .modifier(IntentRequests(navigator: navigator))
            .reminderBanner(live: live, watch: { watch($0) }, showLive: { selection = .live })
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
        /// Series sits inside Movies; Movies with nothing offered opens Live.
        init(_ tab: LiveSession.Tab, offer: TitleOffer) {
            switch tab {
            case .guide: self = .guide
            case .movies, .series: self = offer.any ? .movies : .live
            case .live, .search, .settings: self = .live
            }
        }

        var session: LiveSession.Tab {
            switch self {
            case .live: .live
            case .guide: .guide
            case .movies: .movies
            case .search: .search
            case .settings: .settings
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
                })
        }

        /// Opens Search, the Guide at a programme, or Live, and sets the
        /// group Live and the Guide share.
        private var navigator: ShellNavigator {
            .window(live: live, guide: guide) { place in
                selection = place == .live ? .live : place == .guide ? .guide : .search
            }
        }

        /// The Movies tab's search button opens Search set to movies or series.
        private var opener: SearchOpener {
            SearchOpener { kind, text in
                search.start(kind == .movie ? .movies : .series, text: text)
                selection = .search
            }
        }

        /// Shows Live with `channel` playing, in All channels when the open
        /// group does not hold it. Search keeps its query.
        private func watch(_ channel: Channel) {
            if let key = RowKey(channel), !live.catalogue.rows(in: live.group).contains(key) { live.show(.all, picked: false) }
            live.pick(channel)
            selection = .live
        }
    }

    #Preview("Root, no sources") {
        RootView()
            .modelContainer(for: [SourceRecord.self, FavoriteRecord.self], inMemory: true)
    }
#endif
