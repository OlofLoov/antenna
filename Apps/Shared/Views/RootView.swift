import SwiftUI

/// Top-level navigation. tvOS gets the sidebar-adaptable tab bar that the
/// system apps use; iPhone gets a regular tab bar; iPad and Mac get the
/// sidebar automatically via `.sidebarAdaptable`.
struct RootView: View {
    enum Tab: Hashable { case guide, channels, favorites, settings }
    @State private var selection: Tab = .channels

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
    }
}

#Preview("Root, no sources") {
    RootView()
        .modelContainer(for: [SourceRecord.self, FavoriteRecord.self], inMemory: true)
}
