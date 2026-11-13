# Design

## Context

`SourceEditor.switchToXtream(channels:in:)` builds an old-to-new id map with `XtreamPanelLink.liveChannelIDs(for:)` and hands it to `ChannelIDMigration.rewrite`, which moves `FavoriteRecord` and `GroupMemberRecord` rows. Four other stores key a channel by its id:

- `RecentsStore` in `UserDefaults`: `recents.list` (`[LastChannelKey]`), `shell.lastChannel` (`LastChannelKey`) and `recents.session` (`LiveSession`, which names a group, not a channel), each per profile through `ProfileKeys`.
- `ChannelLanguageStore` in `UserDefaults`: `player.languages` per profile, a `LanguageMemory` keyed `<sourceID>/<channelID>`.
- `GuideSettings.matches`, keyed by channel id, synced in `GuideSettingsRecord` through `GuideSettingsStore`.

The map's values are `xtream#<host>#<stream_id>`, which hold no link or login. Its keys are `m3u.<hash>` ids.

## Goals / Non-Goals

**Goals:**
- One switch moves every per-channel memory the device has with the map favorites already use.
- The rewrites are pure functions in AntennaCore with tests; the app only reads and writes the stores.

**Non-Goals:**
- Moving per-device state on devices that did not switch.
- The restored Live group: it names a source and a group, and an Xtream source's group names come from the panel's categories, which a panel playlist already uses as `group-title`. It stays as it is.

## Decisions

### Pure rewrites in AntennaCore

- `RecentChannels.renameChannels(_ ids: [String: String], source: UUID)`: each entry of `source` whose id the map names takes the new id; the list keeps its order and drops a later duplicate.
- `LastChannelKey.renamingChannel(_ ids:, source:)`: the key with its new id, or itself.
- `LanguageMemory.renameChannels(_ keys: [String: String])`: each entry whose key the map names takes the new key; when the new key is already in the memory, the newer pick (later in the list) wins.
- `GuideSettings.moveMatches(_ ids:, at date:) -> Bool`: each active match under an old id is copied to the new id with `modifiedAt` set to `date`, and the old id gets a tombstone at `date`. A new id that already has an active match keeps it. Returns whether anything changed.

Every rewrite refuses a new id that `LastChannelKey.canStore` rejects (one holding `://`), so a link can never be written even if a caller passes a bad map.

Options considered for guide matches:
1. **Copy and tombstone** (chosen). The settings merge entry by entry on `modifiedAt`, so another device's older copy cannot bring the old match back, and the new match wins over nothing.
2. **Copy only.** The old match stays forever as dead weight in the synced payload.
3. **Leave them.** The panel guide id often matches without a pick, but a pick made because it did not would be lost.

### Where the app does it

`ChannelIDMigration.moveDeviceState(_ ids:, source:, defaults:)` runs the `UserDefaults` rewrites for Main and every profile with a stored value, found the way `RecentsStore.remove(source:from:)` finds them. `RecentsStore.renameChannels(_:source:in:)` and `ChannelLanguageStore.renameChannels(_:source:in:)` hold the per-store code next to the code that already reads those keys. `switchToXtream` calls it and `GuideSettingsStore.update(id) { $0.moveMatches(ids, at: .now) }` after the favorites rewrite, before it returns. `SourceEditor` gains `defaults: UserDefaults = .standard` so tests run against a scratch suite.

Options considered: rewrite on the next Xtream load (the old channels and so the map are gone by then); rewrite lazily when a store is read (every read would need the map); at the switch (chosen).

### Running app

`RecentsStore.record` reads the stored list before each write, so the next channel played does not write the old ids back. Live reloads the source after the switch and builds the Recents group from the stored list.

## Risks / Trade-offs

- [Another device keeps its Recents and last channel on the old ids] → they stop matching there, as after a channel rename, and refill as the user watches.
- [A channel that was not loaded at the switch] → keeps its old id everywhere, as favorites do.
