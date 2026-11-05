import SwiftData
import SwiftUI

/// Top-level navigation. tvOS gets the sidebar-adaptable tab bar that the
/// system apps use; iPhone gets a regular tab bar; iPad and Mac get the
/// sidebar automatically via `.sidebarAdaptable`.
struct RootView: View {
    enum Tab: Hashable { case guide, channels, favorites, settings }
    @State private var selection: Tab = .channels
    @Environment(\.guideStore) private var guideStore
    @Environment(\.scenePhase) private var scenePhase
    @Query private var sources: [SourceRecord]

    var body: some View {
        TabView(selection: $selection) {
            SwiftUI.Tab("Channels", systemImage: "tv", value: .channels) {
                ChannelsView()
            }
            SwiftUI.Tab("Guide", systemImage: "list.bullet.rectangle", value: .guide) {
                GuideView()
            }
            SwiftUI.Tab("Favorites", systemImage: "star", value: .favorites) {
                FavoritesView()
            }
            SwiftUI.Tab("Settings", systemImage: "gearshape", value: .settings) {
                SettingsView()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        // Launch and every return to the foreground refresh stale guides.
        // On iPad and Mac each window runs this; both calls are idempotent.
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active, let guideStore else { return }
            Task { await guideStore.refreshIfStale(now: .now) }
        }
        // A source deleted here or through iCloud loses its guide.
        .onChange(of: Set(sources.map(\.id)), initial: true) { _, ids in
            guard let guideStore else { return }
            Task { await guideStore.sourcesChanged(to: ids) }
        }
    }
}

#Preview("Root, no sources") {
    RootView()
        .modelContainer(for: [SourceRecord.self, FavoriteRecord.self], inMemory: true)
}
