import AntennaCore
import Foundation
import SwiftData

/// Building Live's catalogue (channel-catalogue capability) away from the
/// main actor, so 50 000 channels arriving never stall the list.
extension LiveModel {
    /// Builds the catalogue and its name index from `inputs` away from the
    /// main actor. Only the newest build shows, with the favorites, recents
    /// and group rules of the moment it lands.
    func startCatalogueBuild(_ inputs: CatalogueInputs<PersistentIdentifier>) {
        builds += 1
        let ticket = builds
        let seenAt = seenChanges
        let build = dependencies.buildCatalogue
        building = Task { [weak self] in
            let interval = BrowseSignposts.signposter.beginInterval("catalogue")
            let built = await build(inputs)
            BrowseSignposts.signposter.endInterval("catalogue", interval)
            guard let self, ticket == builds else { return }
            var catalogue = built.catalogue
            if favorites != inputs.favorites { catalogue = catalogue.replacingFavorites(favorites) }
            if shownRecents != inputs.recents { catalogue = catalogue.replacingRecents(shownRecents) }
            if groupRules != inputs.rules { catalogue = catalogue.replacingRules(groupRules) }
            self.catalogue = catalogue
            names = built.names
            restoreGroup()
            building = nil
            if seenChanges != seenAt { await showNew() }
        }
    }

    /// Lists the New group again from `seen`, away from the main actor. A
    /// catalogue replaced meanwhile is worked on again; a build in flight
    /// does it when it lands.
    func showNew() async {
        while building == nil {
            let current = catalogue
            let updated = await Self.withNew(current, seen: seen, now: .now)
            guard building == nil else { return }
            if catalogue.revision == current.revision {
                if updated.rows(in: .new) != current.rows(in: .new) { catalogue = updated }
                return
            }
        }
    }

    @concurrent
    private static func withNew(
        _ catalogue: Catalogue<PersistentIdentifier>, seen: [UUID: SeenChannels], now: Date
    ) async -> Catalogue<PersistentIdentifier> {
        NewChannels.group(catalogue, seen: seen, now: now)
    }

    /// Waits until no source is loading and the catalogue is built. For tests.
    func settled() async {
        while true {
            if let next = loads.values.first {
                await next.value
            } else if let next = records.values.first {
                await next.task.value
            } else if let building {
                await building.value
                if self.building == building { self.building = nil }
            } else {
                return
            }
        }
    }
}
