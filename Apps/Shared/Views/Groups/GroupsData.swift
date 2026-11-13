import AntennaCore
import SwiftData
import SwiftUI

extension EnvironmentValues {
    /// Every loaded channel, tagged, for the Groups screen and its picker.
    @Entry var loadedChannels: [Channel] = []
}

/// What the Groups screens read: the records, the channels and the
/// catalogue built from them with the locks open, since the screens show
/// only after the passcode (group-management capability).
@MainActor
struct GroupsData {
    let catalogue: Catalogue<PersistentIdentifier>
    let records: [GroupRecord]
    let sourceNames: [UUID: String]
    /// The rules as stored. The catalogue drops locks while they are open,
    /// so the screen reads them from here.
    let rules: GroupRules

    init(
        channels: [Channel], groups: [GroupRecord], members: [GroupMemberRecord], hidden: [HiddenGroupRecord], sources: [SourceRecord],
        profile: UUID
    ) {
        let rules = GroupStore.rules(groups: groups, members: members, hidden: hidden, profile: profile, locksOpen: true)
        self.rules = rules
        catalogue = Catalogue(channels: channels, groupOrder: [:], favorites: [], rules: rules)
        records = groups
        sourceNames = Dictionary(sources.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
    }

    /// Every group the screen lists, All channels first.
    var groups: [CatalogueGroup] { catalogue.managedGroups }

    func isLocked(_ group: CatalogueGroup) -> Bool { rules.locked.contains(group) }
    func isHidden(_ group: CatalogueGroup) -> Bool { rules.hidden.contains(group) }

    /// Settings for groups no loaded playlist has, and duplicate records,
    /// each with its group (group-management/settings-for-groups-that-are-gone).
    var orphans: [CatalogueGroup] {
        let duplicates = GroupStore.duplicates(records).compactMap(\.group).filter { $0 != .all }
        return (catalogue.orphanedGroups + duplicates).uniquedGroups()
    }

    /// "Sport", "Ungrouped" or the user's name, then the playlist.
    func caption(_ group: CatalogueGroup) -> String {
        switch group {
        case .named(let source, _), .ungrouped(let source):
            let name = sourceNames[source].map { " · \($0)" } ?? ""
            return group.label + name
        case .favorites, .recents, .new, .all, .own: return catalogue.label(of: group)
        }
    }
}

extension [CatalogueGroup] {
    fileprivate func uniquedGroups() -> [CatalogueGroup] {
        var seen: Set<CatalogueGroup> = []
        return filter { seen.insert($0).inserted }
    }
}
