## Why

A user who adds a playlist on their iPhone expects it on their Apple TV without typing it again. Sources have to be stored once, synced through the user's own iCloud account, and loaded into one channel list, and credentials must never travel through SwiftData. This serves the household setter-upper who wants "sources I add on one device to appear on my other devices, so I never type a URL or password twice", the user who wants "to edit, refresh or remove a source, and change how the app behaves, so my setup stays right as my subscription changes", and the user who wants "my passwords kept private, so a synced device or a log never shows them in plain text".

Written after the fact. It records behavior shipped in commit 082034b so later changes have a spec to revise. This archive holds the part with passing tests; the change `complete-source-management` holds the criteria still waiting on a UI test target or a device check.

## What Changes

- An add-source sheet in Settings: type (M3U, Xtream Codes, Stalker portal), name, URL, optional guide link for M3U, username and password for the others.
- A synced source record in SwiftData with CloudKit; credentials in the Keychain keyed by the record id.
- Sources listed in Settings, with swipe to delete on iOS and iPadOS, which also removes the Keychain item.
- The channel list loads every source when shown and again whenever a source is added, removed, reordered or changed by sync, skipping unchanged sources that already produced channels.

Out of scope:
- Editing or reordering a source.
- Caching channel lists between launches, refresh policy, last-refreshed time.
- Loading Stalker channels (the type saves but gives no channels).
- Showing load errors to the user (recorded, not rendered).
- The "credential not yet synced" state.
- Choosing a playback engine.
- Search, group filtering and favorites.

## Capabilities

### New Capabilities
- `source-management`: add, store, sync, delete and load the user's sources.

### Modified Capabilities

## Impact

- App: `SourceRecord`, `AddSourceView`, the Settings source list, `SourceLoader`, `ChannelListModel`, `CredentialStore`.
- Depends on `m3u-playlists` and `xtream-live-source` for parsing.
- Superseded in part, once those changes are implemented: the empty state and the channel tap by `add-live-tv-on-iphone-ipad-mac`; deletion, the Settings list and the load rules by `add-sources-and-settings`; the Stalker rule by `add-stalker-portal-source`.
