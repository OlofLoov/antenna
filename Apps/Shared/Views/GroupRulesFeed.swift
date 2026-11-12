import AntennaCore
import SwiftData
import SwiftUI

/// Watches the group records, saved here or arriving through iCloud, and
/// hands the current profile's rules to the screen that builds the
/// catalogue (group-management/changes-follow-you-to-every-device).
struct GroupRulesFeed: ViewModifier {
    /// Told the rules once at first and again after every change.
    let changed: (GroupRules) -> Void
    @Environment(GroupLocks.self) private var locks: GroupLocks?
    @Query private var groups: [GroupRecord]
    @Query private var members: [GroupMemberRecord]
    @Query private var hidden: [HiddenGroupRecord]
    @Environment(\.currentProfile) private var profile

    func body(content: Content) -> some View {
        content.onChange(of: rules, initial: true) { _, rules in changed(rules) }
    }

    private var rules: GroupRules {
        GroupStore.rules(groups: groups, members: members, hidden: hidden, profile: profile, locksOpen: locks?.isOpen ?? false)
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

/// Closes the group locks on their own (group-management/locks-close-again-on-their-own):
/// after the app spent `GroupLocks.idleLimit` in the background, and on
/// Apple TV after that long without remote input.
struct GroupLockTimers: ViewModifier {
    let locks: GroupLocks
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .background: locks.wentToBackground()
                case .active: locks.becameActive()
                default: break
                }
            }
            #if os(tvOS)
                .task {
                    while !Task.isCancelled {
                        try? await Task.sleep(for: .seconds(30))
                        locks.checkIdle()
                    }
                }
            #endif
    }
}
