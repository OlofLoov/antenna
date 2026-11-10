import Foundation
import AntennaCore
import SwiftData

extension CatalogueGroup {
    /// The name the group column, the chips and the list heading show.
    var label: String {
        switch self {
        case .favorites: "Favorites"
        case .all: "All channels"
        case .named(_, let name): name
        case .ungrouped: "Ungrouped"
        }
    }

    /// How the Apple TV channel column is sorted, under its heading.
    var order: String {
        self == .favorites ? "Your order" : "Sorted by number"
    }

    var systemImage: String? {
        self == .favorites ? "star" : nil
    }
}

extension RowKey {
    /// The row's part of an identifier such as `overlay.channel.<rowKey>`:
    /// its source and position, never the channel id, which can hold the
    /// stream link.
    var identifier: String { "\(sourceID.uuidString).\(position)" }
}

extension Catalogue where Token == PersistentIdentifier {
    /// The app's catalogue: its channels in source order, groups in
    /// first-appearance order, and `profile`'s stored favorites (profiles capability).
    static func shell(channels: [Channel], favorites: [FavoriteRecord], profile: UUID = Profile.mainID) -> Self {
        let owned = favorites.filter { ProfileList.owns(profile, recordProfile: $0.profileID) }
        return Catalogue(channels: channels, groupOrder: [:], favorites: owned.map(\.snapshot))
    }
}

extension FavoriteRecord {
    /// The record as the catalogue reads it.
    var snapshot: FavoriteSnapshot<PersistentIdentifier> {
        FavoriteSnapshot(channelID: channelID, sourceID: sourceID, sortOrder: sortOrder, recordToken: persistentModelID)
    }
}
