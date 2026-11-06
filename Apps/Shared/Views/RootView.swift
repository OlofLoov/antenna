import SwiftData
import SwiftUI

/// Top-level navigation on iPhone, iPad and Mac: a regular tab bar on
/// iPhone, the sidebar on iPad and Mac via `.sidebarAdaptable`. Apple TV
/// opens on `ShellView` instead (spec 0015).
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
        .guideRefreshTriggers()
    }
}

#Preview("Root, no sources") {
    RootView()
        .modelContainer(for: [SourceRecord.self, FavoriteRecord.self], inMemory: true)
}
