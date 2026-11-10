#if os(tvOS)
    import AntennaCore
    import Foundation
    import Observation

    /// Where the Apple TV channel overlay has focus.
    enum OverlayFocus: Hashable {
        case group(CatalogueGroup)
        case channel(RowKey)
        case watch
        case favorite
        case search
    }

    /// Which group the channel overlay shows and where it opens
    /// (tv-channel-overlay capability). Remembers the group the user last tuned from for
    /// as long as the app runs.
    @MainActor @Observable
    final class ChannelOverlayModel {
        /// The group whose channels the middle column shows.
        private(set) var group: CatalogueGroup = .all
        /// The group the user last tuned from, nil after a cold launch.
        private(set) var lastTuned: CatalogueGroup?
        /// The channel row last highlighted; the panel describes it, also
        /// while focus is on Watch or the favorite button.
        private(set) var highlighted: RowKey?

        /// Picks the group and the row to highlight when the overlay opens
        /// (tv-channel-overlay/it-opens-where-the-user-left-off): the last
        /// tuned group, else the playing channel's own group, else All
        /// channels; the playing channel in it, else its first channel. A
        /// playing channel the catalogue no longer has opens All channels.
        func open<Token>(_ catalogue: Catalogue<Token>, playing: Channel?) -> OverlayFocus {
            let key = playing.flatMap(RowKey.init)
            let playingIsListed = key.flatMap(catalogue.channel(for:)) != nil
            var chosen = lastTuned ?? playing.flatMap(catalogue.sourceGroup(of:)) ?? .all
            if playing != nil, !playingIsListed { chosen = .all }
            if !catalogue.groups.contains(chosen) { chosen = .all }
            group = chosen
            let target = highlight(in: catalogue, keeping: playingIsListed ? key : nil)
            highlighted = target.row
            return target
        }

        /// Focus moved onto a channel row.
        func highlight(_ key: RowKey) {
            highlighted = key
        }

        /// The row the panel describes when it is in the shown group, nil
        /// otherwise, so an empty group leaves the panel empty.
        func panelRow<Token>(_ catalogue: Catalogue<Token>) -> RowKey? {
            guard let highlighted, catalogue.rows(in: group).contains(highlighted) else { return nil }
            return highlighted
        }

        /// Where focus goes after the highlighted channel left Favorites
        /// while Favorites is shown (tv-channel-overlay/add-or-remove-a-favorite):
        /// the next row, else the one before, else the Favorites group.
        /// `before` is the catalogue from before the removal.
        func removedFromFavorites<Token>(_ key: RowKey, before: Catalogue<Token>) -> OverlayFocus? {
            guard group == .favorites else { return nil }
            let rows = before.rows(in: .favorites)
            guard let index = rows.firstIndex(of: key) else { return nil }
            let neighbor = index + 1 < rows.count ? rows[index + 1] : index > 0 ? rows[index - 1] : nil
            highlighted = neighbor
            return neighbor.map(OverlayFocus.channel) ?? .group(.favorites)
        }

        /// The list the info bar counts `channel` in
        /// (tv-zap-bar-and-number-entry/which-channel-this-is): the group last
        /// tuned from, else the channel's own group; All channels when the
        /// channel is not in that list, as after tuning by number or search.
        func currentList<Token>(_ catalogue: Catalogue<Token>, for channel: Channel) -> CatalogueGroup {
            let list = lastTuned ?? catalogue.sourceGroup(of: channel) ?? .all
            guard let key = RowKey(channel), catalogue.position(of: key, in: list) != nil else { return .all }
            return list
        }

        /// The highlight moved onto `group` in the group column.
        func show(_ group: CatalogueGroup) {
            self.group = group
        }

        /// A channel was tuned from `group`; the next open starts there.
        func tuned(from group: CatalogueGroup) {
            lastTuned = group
        }

        /// The row focus lands on when it moves into the channel column: the
        /// playing channel when the group holds it, else the first row. Nil
        /// for an empty group, so focus stays where it is.
        func entry<Token>(_ catalogue: Catalogue<Token>, playing: Channel?) -> RowKey? {
            let rows = catalogue.rows(in: group)
            if let key = playing.flatMap(RowKey.init), rows.contains(key) { return key }
            return rows.first
        }

        /// The line the channel column shows when the shown group has no
        /// channels (tv-channel-overlay/empty-groups-tell-the-user-what-to-do),
        /// nil while it has some.
        func emptyText<Token>(_ catalogue: Catalogue<Token>) -> String? {
            guard catalogue.rows(in: group).isEmpty else { return nil }
            switch group {
            case .favorites: return "No favorites yet. Press the star on a channel to add it."
            case .all, .named, .ungrouped: return "No channels yet. Add a source in Settings."
            }
        }

        /// The channels or favorites changed while the overlay is open
        /// (tv-channel-overlay/every-group-with-its-size). A group that is gone
        /// shows All channels; the highlight stays on `focused` while it
        /// exists, else moves to the group's first channel.
        func catalogueChanged<Token>(_ catalogue: Catalogue<Token>, focused: OverlayFocus?) -> OverlayFocus? {
            if !catalogue.groups.contains(group) { group = .all }
            if let lastTuned, !catalogue.groups.contains(lastTuned) { self.lastTuned = nil }
            switch focused {
            case .channel(let key):
                let target = highlight(in: catalogue, keeping: key)
                highlighted = target.row
                return target
            case .group(let shown) where !catalogue.groups.contains(shown):
                return .group(group)
            case .group, .watch, .favorite, .search, nil:
                return focused
            }
        }

        private func highlight<Token>(in catalogue: Catalogue<Token>, keeping key: RowKey?) -> OverlayFocus {
            let rows = catalogue.rows(in: group)
            if let key, rows.contains(key) { return .channel(key) }
            if let first = rows.first { return .channel(first) }
            return .group(group)
        }
    }

    extension OverlayFocus {
        /// The row this focus is on, if it is on one.
        var row: RowKey? {
            if case .channel(let key) = self { return key }
            return nil
        }
    }
#endif
