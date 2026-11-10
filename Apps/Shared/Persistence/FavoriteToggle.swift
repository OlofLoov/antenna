import AntennaCore
import Foundation
import SwiftData

extension FavoriteRecord {
    /// Adds `channel` to Favorites, after every existing favorite, or
    /// removes every record that favorites it (tv-channel-overlay/add-or-remove-a-favorite).
    /// Returns whether the channel is a favorite afterwards.
    /// `catalogue` holds `profile`'s favorites only, and a new favorite is stored for `profile`.
    @MainActor @discardableResult
    static func toggle(
        _ channel: Channel, in catalogue: Catalogue<PersistentIdentifier>, profile: UUID = Profile.mainID, context: ModelContext
    ) -> Bool {
        let existing = catalogue.favoritesToRemove(for: channel)
        if existing.isEmpty {
            guard let added = catalogue.addFavorite(channel) else { return false }
            context.insert(
                FavoriteRecord(
                    channelID: added.channelID, sourceID: added.sourceID, sortOrder: added.sortOrder,
                    profileID: ProfileList.storedID(for: profile)))
        } else {
            for token in existing.compactMap(\.recordToken) {
                if let record = context.model(for: token) as? FavoriteRecord { context.delete(record) }
            }
        }
        try? context.save()
        return existing.isEmpty
    }
}
