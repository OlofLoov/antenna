import SwiftUI
import SwiftData

struct FavoritesView: View {
    @Query(sort: \FavoriteRecord.sortOrder) private var favorites: [FavoriteRecord]

    var body: some View {
        NavigationStack {
            if favorites.isEmpty {
                ContentUnavailableView("No favorites", systemImage: "star", description: Text("Favorites sync across your devices."))
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("favorites.emptyState")
                    .navigationTitle("Favorites")
            } else {
                List(favorites) { fav in
                    Text(fav.channelID)
                }
                .accessibilityIdentifier("favorites.list")
                .navigationTitle("Favorites")
            }
        }
    }
}

#Preview("Favorites, empty") {
    FavoritesView()
        .modelContainer(for: [SourceRecord.self, FavoriteRecord.self], inMemory: true)
}

#Preview("Favorites, three entries") {
    FavoritesView()
        .modelContainer(previewContainer(sortOrders: [2, 0, 1]))
}

@MainActor
private func previewContainer(sortOrders: [Int]) -> ModelContainer {
    do {
        let container = try ModelContainer(
            for: SourceRecord.self, FavoriteRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        for order in sortOrders {
            container.mainContext.insert(FavoriteRecord(channelID: "channel-\(order)", sourceID: nil, sortOrder: order))
        }
        return container
    } catch {
        fatalError("Could not create the preview store: \(error)")
    }
}
