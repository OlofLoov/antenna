# Proposal

## Why

> As a viewer with an M3U subscription, I want my favorites, recent channels and own groups to work for M3U channels the way they do for Xtream, without my provider login ending up in iCloud.

An M3U channel's id is built from its stream link. For `xc`-style playlists that link holds the provider's username and password, so every favorite of an M3U channel stores the login in the synced store. To keep logins out of saved records, other changes refuse M3U channels instead: Recents and session restore skip them, the Apple TV does not remember one as its last channel, own groups refuse them, sound and subtitle picks are not kept, and a hand-picked guide match cannot be saved. After this change M3U channels work like any other: favorites, Recents, the last channel, own groups and language picks all keep M3U channels, and none of those records holds a link.

## What Changes

- An M3U channel's id comes from its guide id, name and group, never from its stream link. Two entries that share all three are told apart by their order among those entries.
- Ids survive a changed password, a moved server, new tokens in the links and a reordered playlist. Renaming a channel or moving it to another group gives it a new id.
- Imported playlist files get the same kind of id, built from the text as synced.
- Favorites and own-group channels saved with an old id are rewritten to the new id the first time their playlist loads on a device running this version. The rewrite syncs, so other devices see the new id without doing it again, and a favorite that ends up twice is kept once.
- Recents, session restore, the Apple TV's last channel and language picks keep M3U channels. Their rule that an id holding a link is never stored stays as a guard.

Out of scope:
- Stalker, Xtream, Jellyfin and Channels DVR ids, which hold no link.
- A favorite whose source was deleted before this version ran keeps its old id: nothing can map it without its playlist.
- Matching a renamed channel to its old favorite.
- Guide matching by hand, Shortcuts and own-group screens: they only stop being blocked.

## Capabilities

### New Capabilities

None.

### Modified Capabilities
- `m3u-playlists`: channel ids come from the guide id, name and group, and each channel names the id earlier versions gave it so saved references can move over.
- `favorites`: favorites of M3U channels survive reorders and login changes, and favorites saved with an old id carry over.
- `session-restore-and-recently-watched`: M3U channels are added to Recents and restored, and no stored channel holds a link.
- `tvos-shell`: the Apple TV remembers an M3U channel as its last channel.

## Impact

- Platforms: iOS, iPadOS, macOS, tvOS.
- Depends on: `m3u-playlists`, `favorites`, `session-restore-and-recently-watched`, `tvos-shell`, and the changes `add-local-m3u-file-import` (file ids from the synced text) and `add-group-management` (own-group members).
- Unblocks: `add-group-management` (own groups take M3U channels), `add-guide-sources-and-channel-mapping` (a hand-picked match for an M3U channel can be saved), `add-app-intents` (task 1.1), and the favorites note in `add-timeshift-catch-up-and-start-over`.
- Data: no schema change. Existing `FavoriteRecord` and `GroupMemberRecord` rows are rewritten in place.
- Blocked on: nothing.
