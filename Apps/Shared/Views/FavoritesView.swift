import SwiftUI
import SwiftData

struct FavoritesView: View {
    @Query(sort: \FavoriteRecord.sortOrder) private var favorites: [FavoriteRecord]

    var body: some View {
        NavigationStack {
            if favorites.isEmpty {
                ContentUnavailableView("No favorites", systemImage: "star", description: Text("Favorites sync across your devices."))
                    .navigationTitle("Favorites")
            } else {
                List(favorites) { fav in
                    Text(fav.channelID)
                }
                .navigationTitle("Favorites")
            }
        }
    }
}
