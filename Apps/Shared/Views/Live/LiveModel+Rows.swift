import AntennaCore
import Foundation
import SwiftData

/// What the open group's list reads, kept as it is while the group's rows
/// stay the same, so a channel joining Recents or a new star does not make
/// a list of 50 000 rows draw again
/// (live-tv-on-iphone-ipad-mac/a-very-large-source-stays-responsive).
extension LiveModel {
    struct RowsSource {
        var catalogue: Catalogue<PersistentIdentifier>
        var group: CatalogueGroup
        var filter: String
    }

    /// Works out `rows` again unless the catalogue, the group and the
    /// filter leave them as they are. A new name index always counts.
    func refreshRows(namesChanged: Bool = false) {
        let from = namesChanged ? nil : rowsFrom
        if let from, from.group == group, from.filter == filter, catalogue.sameRows(in: group, as: from.catalogue) {
            rowsFrom?.catalogue = catalogue
            return
        }
        rowsFrom = RowsSource(catalogue: catalogue, group: group, filter: filter)
        let fresh = names.filter(catalogue.rows(in: group), by: ChannelFilter(filter))
        if fresh != rows { rows = fresh }
    }
}
