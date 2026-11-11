#if os(iOS) || os(macOS)
    import SwiftData
    import SwiftUI

    /// The window root on iPhone, iPad and Mac. Owns the Live model and its
    /// engine, so the channel plays on whichever layout is shown. Apple TV
    /// opens on `ShellView` instead (tvos-shell capability).
    struct RootView: View {
        @Environment(\.sourceLoader) private var loader
        @Environment(\.guideStore) private var guideStore
        @Environment(\.currentProfile) private var profile
        @State private var live: LiveModel?
        @State private var shelves: ShelfLibrary?
        @State private var lifecycle: PlaybackLifecycle?
        #if os(iOS)
            @Environment(\.horizontalSizeClass) private var sizeClass
        #endif

        var body: some View {
            ZStack {
                Palette.ground.ignoresSafeArea()
                if let live, let shelves {
                    layout
                        .modifier(LiveSync(live: live))
                        .modifier(ShelfSync(library: shelves))
                }
            }
            .preferredColorScheme(.dark)
            .guideRefreshTriggers()
            .task {
                guard live == nil else { return }
                let live = LiveModel(dependencies())
                let engine = live.engine
                let lifecycle = PlaybackLifecycle(engine: engine) { engine.continuesInPictureInPicture }
                lifecycle.start()
                self.live = live
                self.shelves = .app(loader)
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
        @Environment(LiveModel.self) private var live
        @Environment(ShelfLibrary.self) private var shelves
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
                    }
                }
                SwiftUI.Tab("Search", systemImage: "magnifyingglass", value: .search) {
                    StandIn(title: "Search", systemImage: "magnifyingglass")
                }
                SwiftUI.Tab("Settings", systemImage: "gearshape", value: .settings) {
                    SettingsView()
                }
            }
            // The Movies tab goes with the last Xtream source.
            .onChange(of: shelves.hasXtream) { _, has in
                if !has, selection == .movies { selection = .live }
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

    /// Holds the place of a screen that a later change builds.
    private struct StandIn: View {
        let title: String
        let systemImage: String

        var body: some View {
            ContentUnavailableView(title, systemImage: systemImage, description: Text("Not available yet."))
                .background(Palette.ground)
        }
    }

    #Preview("Root, no sources") {
        RootView()
            .modelContainer(for: [SourceRecord.self, FavoriteRecord.self], inMemory: true)
    }
#endif
