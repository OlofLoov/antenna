#if os(iOS) || os(macOS)
    import SwiftData
    import SwiftUI

    /// The window root on iPhone, iPad and Mac. Owns the Live model and its
    /// engine, so the channel plays on whichever layout is shown. Apple TV
    /// opens on `ShellView` instead (tvos-shell capability).
    struct RootView: View {
        @Environment(\.sourceLoader) private var loader
        @Environment(\.guideStore) private var guideStore
        @State private var live: LiveModel?
        @State private var lifecycle: PlaybackLifecycle?

        var body: some View {
            ZStack {
                Palette.ground.ignoresSafeArea()
                if let live {
                    CompactTabs()
                        .modifier(LiveSync(live: live))
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
                self.lifecycle = lifecycle
            }
        }

        private func dependencies() -> LiveModel.Dependencies {
            #if DEBUG
                if let scripted = UITestingLive.dependencies() { return scripted }
            #endif
            return .live(loader: loader, guide: guideStore)
        }
    }

    /// The tab bar on iPhone: Live, Guide, Movies, Search and Settings. Series
    /// sits inside Movies.
    private struct CompactTabs: View {
        enum Tab: Hashable { case live, guide, movies, search, settings }
        @State private var selection: Tab = .live

        var body: some View {
            TabView(selection: $selection) {
                SwiftUI.Tab("Live", systemImage: "tv", value: .live) {
                    LiveCompactView()
                }
                SwiftUI.Tab("Guide", systemImage: "list.bullet.rectangle", value: .guide) {
                    GuideView()
                }
                SwiftUI.Tab("Movies", systemImage: "film", value: .movies) {
                    StandIn(title: "Movies", systemImage: "film")
                }
                SwiftUI.Tab("Search", systemImage: "magnifyingglass", value: .search) {
                    StandIn(title: "Search", systemImage: "magnifyingglass")
                }
                SwiftUI.Tab("Settings", systemImage: "gearshape", value: .settings) {
                    SettingsView()
                }
            }
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
