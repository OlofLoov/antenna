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
}
