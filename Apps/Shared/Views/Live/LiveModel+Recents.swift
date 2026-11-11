import AntennaCore
import Foundation

/// Recents and deleted sources on Live (session-restore-and-recently-watched capability).
extension LiveModel {
    /// A source was deleted, here or on another device, and its channels
    /// left the stored recents (session-restore-and-recently-watched/deleting-a-source-clears-its-channels).
    /// Its channel playing now stops counting as watched.
    func sourceDeleted(_ id: UUID) {
        session.remove(source: id)
        latestRecents.removeAll { $0.sourceID == id }
        shownRecents.removeAll { $0.sourceID == id }
        catalogue = catalogue.replacingRecents(shownRecents)
        if !catalogue.groups.contains(group) { group = .all }
    }

    /// Shows `group`'s channels and clears the filter. The playing channel
    /// plays on. Recents opens in its newest order.
    func show(_ group: CatalogueGroup) {
        if shownRecents != latestRecents {
            shownRecents = latestRecents
            catalogue = catalogue.replacingRecents(shownRecents)
        }
        self.group = catalogue.groups.contains(group) ? group : .all
        filter = ""
    }

    /// A channel counted as watched. Recents on screen keeps its order
    /// until it opens again; elsewhere the group changes at once.
    func recentsChanged(_ entries: [LastChannelKey]) {
        latestRecents = entries
        guard group != .recents else { return }
        shownRecents = entries
        catalogue = catalogue.replacingRecents(entries)
    }
}
