import Foundation
import AntennaCore
import SwiftData
import SwiftUI

extension CatalogueGroup {
    /// The name the group column, the chips and the list heading show.
    var label: String {
        switch self {
        case .favorites: "Favorites"
        case .recents: "Recents"
        case .all: "All channels"
        case .named(_, let name): name
        case .ungrouped: "Ungrouped"
        }
    }

    /// How the Apple TV channel column is sorted, under its heading.
    var order: String {
        switch self {
        case .favorites: "Your order"
        case .recents: "Newest first"
        case .all, .named, .ungrouped: "Sorted by number"
        }
    }

    var systemImage: String? {
        switch self {
        case .favorites: "star"
        case .recents: "clock.arrow.circlepath"
        case .all, .named, .ungrouped: nil
        }
    }

    /// What VoiceOver reads for the group with `count` channels
    /// (session-restore-and-recently-watched/recents-sits-between-favorites-and-all-channels).
    func spokenLabel(count: Int) -> String {
        "\(label), \(count == 1 ? "1 channel" : "\(count) channels")"
    }
}

extension View {
    /// VoiceOver reads Recents as "Recents, n channels"; other groups keep
    /// the label their row gives them.
    func groupSpokenLabel(_ group: CatalogueGroup, count: Int) -> some View {
        modifier(GroupSpokenLabel(group: group, count: count))
    }
}

private struct GroupSpokenLabel: ViewModifier {
    let group: CatalogueGroup
    let count: Int

    func body(content: Content) -> some View {
        if group == .recents {
            content.accessibilityLabel(group.spokenLabel(count: count))
        } else {
            content
        }
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
    static func shell(
        channels: [Channel], favorites: [FavoriteRecord], profile: UUID = Profile.mainID, recents: [LastChannelKey] = []
    ) -> Self {
        let owned = favorites.filter { ProfileList.owns(profile, recordProfile: $0.profileID) }
        return Catalogue(channels: channels, groupOrder: [:], favorites: owned.map(\.snapshot), recents: recents)
    }
}

extension FavoriteRecord {
    /// The record as the catalogue reads it.
    var snapshot: FavoriteSnapshot<PersistentIdentifier> {
        FavoriteSnapshot(channelID: channelID, sourceID: sourceID, sortOrder: sortOrder, recordToken: persistentModelID)
    }
}
