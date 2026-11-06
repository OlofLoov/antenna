## Why

Every screen needs the same answers: which groups exist and in what order, what number a channel has, what to draw when a logo is missing, and which favorites can be shown. If each view derived these itself they would disagree. One pure catalogue in AntennaCore, built from the loaded channels, gives every platform the same list. This serves the user who wants several subscriptions "merged into one channel list and one guide", the living-room viewer who wants "to flip channels quickly with the remote, by up and down or by typing a number, so it feels like cable", and the viewer who wants "my favorite channels together in one list, across all my subscriptions and devices".

## What Changes

- Tag each loaded channel with its source and its 0-based position in that source's list.
- Key rows by source, channel id and position, with a lookup that degrades gracefully.
- Build groups (Favorites, All channels, each source's named groups, each source's Ungrouped), numbers, sort orders, initials, favorite resolution, digit matching and position in group.
- A favorite snapshot value the app maps to and from its stored favorite records.

Out of scope:
- Loading, refreshing or caching channels.
- Inserting or deleting stored favorites; the screen that owns the toggle decides when.
- User-defined groups, hiding, renaming, locking, reordering, and merging groups across sources.
- Anything that renders.

## Capabilities

### New Capabilities
- `channel-catalogue`: one shared, pure model of groups, numbers and favorites over the loaded channels.

### Modified Capabilities

## Impact

- AntennaCore: `Catalogue`, `CatalogueGroup`, `RowKey`, `FavoriteSnapshot`, `Channel.tagged`, `Channel.initials`, and the `sourceID` and `position` fields on `Channel`.
- Depends on `m3u-playlists` and `xtream-live-source` for channels, `source-management` for loading, and `favorites` for the records. Fills the favorites gap of resolving a favorite to a channel.
- Constraint on consumers: no screen may insert the snapshot that adding a favorite returns until M3U channel ids stop embedding the stream URL, because a stored favorite would otherwise carry credentials (decision adr-0003).
- The source loader and the favorites store must call `tagged`, pass each source's category order, rebuild after each source loads, and own the mapping between records and snapshots. That wiring belongs to those capabilities.
