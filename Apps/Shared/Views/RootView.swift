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
        @State private var live: LiveModel?
        @State private var shelves: ShelfLibrary?
        @State private var playback: ShelfPlayback?
        @State private var lifecycle: PlaybackLifecycle?
        /// Search keeps its query across tabs and layouts.
        @State private var search = SearchModel()
        #if os(iOS)
            @Environment(\.horizontalSizeClass) private var sizeClass
        #endif

        var body: some View {
            ZStack {
                Palette.ground.ignoresSafeArea()
                if let live, let shelves, let playback {
                    layout
                        .environment(search)
                        // Playback stops before "Who's watching?" (profiles/switching-profile).
                        .environment(\.switchProfile, stopping(live))
                        .modifier(LiveSync(live: live))
                        .modifier(ShelfSync(library: shelves, playback: playback))
                }
            }
            .preferredColorScheme(.dark)
            .guideRefreshTriggers()
            .task {
                guard live == nil else { return }
                let live = LiveModel(dependencies())
                let engine = live.engine
                // Live keeps its sound when the app leaves the screen
                // (player-controls-and-playback-errors/keep-listening-in-the-background).
                let lifecycle = PlaybackLifecycle(engine: engine) { true }
                lifecycle.start()
                self.live = live
                self.shelves = .app(loader)
                self.playback = .app(loader) { await live.suspend() }
                self.lifecycle = lifecycle
            }
        }

        /// The tab bar on iPhone and in a narrow iPad window, the columns on
        /// a wider iPad window and on Mac. Both read the same model.
        @ViewBuilder private var layout: some View {
            #if os(iOS)
                if sizeClass == .compact || forcedCompact {
                    CompactTabs()
                } else {
                    LiveRegularView()
                }
            #else
                LiveRegularView()
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
                if let scripted = UITestingLive.dependencies() { return scripted }
                if let scripted = UITestingShelf.liveDependencies() { return scripted }
            #endif
            return .live(loader: loader, guide: guideStore, profile: profile)
        }
    }

    /// The tab bar on iPhone and in a narrow iPad window: Live, Guide, Movies, Search and Settings. Series
    /// sits inside Movies, and Movies shows only with an Xtream source
    /// (movies-and-series-browsing/movies-and-series-appear-when-your-provider-has-them).
    private struct CompactTabs: View {
        enum Tab: Hashable { case live, guide, movies, search, settings }
        @State private var selection: Tab = .live
        /// The tab Search was opened from, where Cancel goes back to.
        @State private var beforeSearch: Tab = .live
        @Environment(LiveModel.self) private var live
        @Environment(ShelfLibrary.self) private var shelves
        @Environment(ShelfActivity.self) private var activity
        @Environment(ShelfPlayback.self) private var playback
        @Environment(SearchModel.self) private var search
        #if os(iOS)
            @Environment(\.verticalSizeClass) private var verticalSizeClass
        #endif

        var body: some View {
            TabView(selection: $selection) {
                SwiftUI.Tab("Live", systemImage: "tv", value: .live) {
                    LiveCompactView()
                }
                SwiftUI.Tab("Guide", systemImage: "list.bullet.rectangle", value: .guide) {
                    GuideView()
                }
                if shelves.hasXtream {
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
            // The Movies tab goes with the last Xtream source.
            .onChange(of: shelves.hasXtream) { _, has in
                if !has, selection == .movies { selection = .live }
            }
            .onChange(of: selection) { old, new in
                if new == .search, old != .search { beforeSearch = old }
            }
            #if os(iOS)
                // Turning an iPhone sideways on Live fills the screen with
                // the picture; turning it back returns to the list
                // (live-tv-on-iphone-ipad-mac/full-screen).
                .onChange(of: verticalSizeClass) { _, size in
                    guard selection == .live, UIDevice.current.userInterfaceIdiom == .phone else { return }
                    live.setFullScreen(size == .compact)
                }
            #endif
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
                    guard !hit.isOnNow else { return watch(channel) }
                    watch(channel)
                    live.pick(channel, later: hit.programme)
                },
                title: { title in
                    switch title.kind {
                    case .movie: playback.play(title, library: shelves, activity: activity)
                    case .series: shelves.openPage(title, from: .search, in: title.kind)
                    }
                })
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
            if let key = RowKey(channel), !live.catalogue.rows(in: live.group).contains(key) { live.show(.all) }
            live.pick(channel)
            selection = .live
        }
    }

    #Preview("Root, no sources") {
        RootView()
            .modelContainer(for: [SourceRecord.self, FavoriteRecord.self], inMemory: true)
    }
#endif
