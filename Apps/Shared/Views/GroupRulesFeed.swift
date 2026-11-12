import AntennaCore
import SwiftData
import SwiftUI

/// Watches the group records, saved here or arriving through iCloud, and
/// hands the current profile's rules to the screen that builds the
/// catalogue (group-management/changes-follow-you-to-every-device).
struct GroupRulesFeed: ViewModifier {
    /// Told the rules once at first and again after every change.
    let changed: (GroupRules) -> Void
    var locksOpen = false
    @Query private var groups: [GroupRecord]
    @Query private var members: [GroupMemberRecord]
    @Query private var hidden: [HiddenGroupRecord]
    @Environment(\.currentProfile) private var profile

    func body(content: Content) -> some View {
        content.onChange(of: rules, initial: true) { _, rules in changed(rules) }
    }

    private var rules: GroupRules {
        GroupStore.rules(groups: groups, members: members, hidden: hidden, profile: profile, locksOpen: locksOpen)
    }
}

extension Catalogue {
    /// The name every screen shows for `group`: the user's name when they
    /// gave one (group-management/give-a-group-your-own-name), else the app's
    /// or the provider's.
    func label(of group: CatalogueGroup) -> String {
        customName(of: group) ?? group.label
    }
}

/// Per-device group settings kept in `UserDefaults`, never synced.
enum GroupDefaults {
    /// True when search on this device includes hidden groups.
    static let searchHidden = "groups.searchHidden"
}
