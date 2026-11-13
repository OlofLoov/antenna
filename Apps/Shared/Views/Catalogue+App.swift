import Foundation
import AntennaCore
import SwiftData
import SwiftUI
import os

/// Intervals for the work behind the channel lists, under the "browse"
/// category in Instruments, so a stall on a device can be timed.
enum BrowseSignposts {
    static let signposter = OSSignposter(subsystem: "se.codecrave.antenna", category: "browse")
}

extension CatalogueGroup {
    /// The name the group column, the chips and the list heading show.
    var label: String {
        switch self {
        case .favorites: "Favorites"
        case .recents: "Recents"
        case .new: "New"
        case .all: "All channels"
        case .named(_, let name): name
        case .ungrouped: "Ungrouped"
        case .own: "Group"
        }
    }

    /// How the Apple TV channel column is sorted, under its heading.
    var order: String {
        switch self {
        case .favorites: "Your order"
        case .recents, .new: "Newest first"
        case .all, .named, .ungrouped: "Sorted by number"
        case .own: "Your order"
        }
    }

    var systemImage: String? {
        switch self {
        case .favorites: "star"
        case .recents: "clock.arrow.circlepath"
        case .new: "sparkles"
        case .all, .named, .ungrouped, .own: nil
        }
    }

    /// What VoiceOver reads for the group with `count` channels
    /// (session-restore-and-recently-watched/recents-sits-between-favorites-and-all-channels,
    /// new-channels/a-new-group-lists-channels-added-lately).
    func spokenLabel(count: Int) -> String {
        "\(label), \(count == 1 ? "1 channel" : "\(count) channels")"
    }
}

extension View {
    /// VoiceOver reads Recents as "Recents, n channels" and New as "New, n
    /// channels"; other groups keep the label their row gives them.
    func groupSpokenLabel(_ group: CatalogueGroup, count: Int) -> some View {
        modifier(GroupSpokenLabel(group: group, count: count))
    }
}

private struct GroupSpokenLabel: ViewModifier {
    let group: CatalogueGroup
    let count: Int

    func body(content: Content) -> some View {
        if group == .recents || group == .new {
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
    /// `rules` are the group rules from `GroupRulesFeed` (group-management capability).
    static func shell(
        channels: [Channel], favorites: [FavoriteRecord], profile: UUID = Profile.mainID, recents: [LastChannelKey] = [],
        rules: GroupRules = GroupRules()
    ) -> Self {
        let built = BrowseSignposts.signposter.beginInterval("catalogue")
        defer { BrowseSignposts.signposter.endInterval("catalogue", built) }
        return Catalogue(
            channels: channels, groupOrder: [:], favorites: FavoriteRecord.snapshots(favorites, profile: profile), recents: recents,
            rules: rules)
    }
}

extension FavoriteRecord {
    /// `profile`'s favorites among `records`, as the catalogue reads them (profiles capability).
    static func snapshots(_ records: [FavoriteRecord], profile: UUID) -> [FavoriteSnapshot<PersistentIdentifier>] {
        records.filter { ProfileList.owns(profile, recordProfile: $0.profileID) }.map(\.snapshot)
    }

    /// The record as the catalogue reads it.
    var snapshot: FavoriteSnapshot<PersistentIdentifier> {
        FavoriteSnapshot(channelID: channelID, sourceID: sourceID, sortOrder: sortOrder, recordToken: persistentModelID)
    }
}
