import AntennaCore
import Foundation

/// Recents and deleted sources on Live (session-restore-and-recently-watched
/// capability). A deleted source's channels also leave New
/// (new-channels/what-new-remembers-stays-on-the-device).
extension LiveModel {
    /// A source was deleted, here or on another device, and its channels
    /// left the stored recents (session-restore-and-recently-watched/deleting-a-source-clears-its-channels).
    /// Its channel playing now stops counting as watched.
    func sourceDeleted(_ id: UUID) {
        session.remove(source: id)
        dependencies.seen.remove(id)
        latestRecents.removeAll { $0.sourceID == id }
        shownRecents.removeAll { $0.sourceID == id }
        catalogue = catalogue.replacingRecents(shownRecents)
        if !catalogue.groups.contains(group) { group = catalogue.fallbackGroup }
    }

    /// Shows `group`'s channels and clears the filter. The playing channel
    /// plays on. Recents opens in its newest order. A group the user
    /// `picked` is the one restored at launch; one the app chose is not
    /// (session-restore-and-recently-watched/reopen-on-the-same-tab-and-group).
    func show(_ group: CatalogueGroup, picked: Bool = true) {
        if shownRecents != latestRecents {
            shownRecents = latestRecents
            catalogue = catalogue.replacingRecents(shownRecents)
        }
        self.group = catalogue.groups.contains(group) ? group : catalogue.fallbackGroup
        filter = ""
        if picked { restore.picked(group) }
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
