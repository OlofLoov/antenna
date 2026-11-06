## Why

Users keep a short list of the channels they watch out of thousands. That list has to survive source reloads and follow the user to every device. This serves the viewer who wants "my favorite channels together in one list, across all my subscriptions and devices".

Written after the fact. It records behavior shipped in commit 082034b so later changes have a spec to revise. Only the storage and the tab exist; nothing adds a favorite yet.

## What Changes

- A synced favorite record holding a channel id, a source id, the time added and a sort order.
- A Favorites tab showing an empty state, or the favorites in sort order.

Out of scope:
- Adding or removing a favorite from any screen.
- Showing a favorite's channel name or logo, or playing it; the list shows the raw channel id.
- Reordering, deduplicating, and cleaning up favorites whose source was deleted.

## Capabilities

### New Capabilities
- `favorites`: store favorites and list them in a Favorites tab.

### Modified Capabilities

## Impact

- App: `FavoriteRecord`, `FavoritesView`.
- Depends on the channel ids from `m3u-playlists` and `xtream-live-source`. The `channel-catalogue` capability later resolves favorites to channels.
