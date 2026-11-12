import AntennaCore
import Foundation

/// Group rules on Live (group-management capability).
extension LiveModel {
    /// The group rules changed, on this device or through sync. The list
    /// follows at once; a group that left it falls back to the first one
    /// the user may open.
    func rulesChanged(_ rules: GroupRules) {
        guard rules != groupRules else { return }
        groupRules = rules
        catalogue = catalogue.replacingRules(rules)
        names = ChannelNameIndex(catalogue)
        restoreGroup()
    }

    /// The right passcode opened `group`, picked in a channel list: it
    /// shows once the catalogue lists it, and is the group restored at launch.
    func unlocked(_ group: CatalogueGroup) {
        restore.picked(group)
        restore.group = group
        restoreGroup()
    }

    /// True while the playing channel is locked and the locks are closed
    /// (group-management/a-channel-that-gets-locked-stops-playing).
    var playingIsLocked: Bool {
        playing.flatMap(RowKey.init).map(catalogue.isLocked) ?? false
    }

    /// The prompt over a locked channel closed without the passcode: the
    /// first channel the user may watch plays, else the player stops.
    func leaveLockedChannel() {
        let group = catalogue.fallbackGroup
        let next = (catalogue.rows(in: group) + catalogue.rows(in: .all)).lazy.compactMap(catalogue.channel(for:)).first
        if let next { tune(next) } else { stop() }
    }
}
