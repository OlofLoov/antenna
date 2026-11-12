#if os(iOS) || os(macOS)
    import AntennaCore
    import SwiftUI

    /// Locked groups in the iPad and Mac sidebar while the locks are closed
    /// (group-management/locked-channels-stay-out-of-reach): a lock, no
    /// channel count, and the passcode prompt when picked.
    struct LockedGroupRows: View {
        @Environment(LiveModel.self) private var live
        @Environment(\.unlockGroup) private var unlock

        var body: some View {
            ForEach(live.catalogue.lockedGroups, id: \.self) { group in
                Browse.GroupRow(title: live.catalogue.label(of: group), systemImage: "lock.fill", count: 0, isSelected: false) {
                    unlock?(group)
                }
                .accessibilityLabel("\(live.catalogue.label(of: group)), locked")
                .accessibilityIdentifier("browse.locked.\(group.storageKey)")
            }
        }
    }

    /// Locked groups among the iPhone chips, opening the passcode prompt.
    struct LockedGroupChips: View {
        @Environment(LiveModel.self) private var live
        @Environment(\.unlockGroup) private var unlock

        var body: some View {
            ForEach(live.catalogue.lockedGroups, id: \.self) { group in
                Browse.Chip(title: "\(live.catalogue.label(of: group)) (locked)", isSelected: false) { unlock?(group) }
                    .accessibilityLabel("\(live.catalogue.label(of: group)), locked")
                    .accessibilityIdentifier("browse.locked.\(group.storageKey)")
            }
        }
    }
#endif
