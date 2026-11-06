# Proposal

## Why

> As a watcher, I want to resume a movie or episode where I left off, on any of my devices, and keep a list of things to watch later.

Movies and series browsing saves how far into a movie or episode the user got and lets them add titles to My list, and search keeps recent searches, but nothing stores any of them yet, and recent searches stay on the device that typed them. Someone who stops a film on the iPad expects the Apple TV to offer to resume it, and syncing between devices tops the TiviMate wish list. This change gives those screens the storage and the rules so they do not have to invent them.

Not reviewed yet.

## What Changes

- Three kinds of synced record: how far into a title the user is, a My list entry, and a recent search.
- One shared rule set for "in progress" and "watched" that the movies and series rows rely on.
- Disagreements between devices settle so every device ends up showing the same thing.
- Recent searches capped at ten, matching regardless of case and accents, shared across the account.
- Deleting a source on this device removes its progress and list entries.
- Everything works offline and without iCloud.
- Recent searches that an earlier build kept on the device move into the synced store, once.
- Screens are told when something changed, including changes arriving from another device.

Out of scope:
- Any screen, including "mark as watched" or "clear history".
- When positions are saved during playback.
- Building Continue watching rows, ordering them and choosing the next episode.
- Search matching and the recent searches screen.
- Progress for live TV, catch-up or timeshift.
- Progress for M3U, Stalker, Jellyfin or Channels DVR titles. Their source changes add it.
- Trakt or any outside watch history service.
- Merging progress across two sources that point at the same provider.
- A device removing records on its own when it sees a source deleted elsewhere. The deleting device's removals sync instead.
- Clearing watch history or removing one title from Continue watching. Until a later change adds it, the user cannot erase watch history.

## Capabilities

### New Capabilities
- `watch-progress-sync`: synced watch progress, My list entries and recent searches, with the rules for settling disagreements and for "in progress" and "watched".

### Modified Capabilities
- `source-management`: deleting a source also removes its watch progress and My list entries.

## Impact

- Platforms: iOS, iPadOS, macOS, tvOS.
- Depends on: `source-management`, `channel-catalogue`, `xtream-vod-client`, and the changes `add-movies-and-series-browsing`, `add-search`.
- Needs from other capabilities and changes: `add-movies-and-series-browsing` reads and writes progress and My list through this store and uses these thresholds. `add-search` stores recent searches here with the 100-character cap. `source-management`'s delete path removes the source's progress and My list entries.
- Blocked on: a decision adding watch progress, My list entries and recent searches to the iCloud sync of adr-0002, together with the reminders of `add-programme-reminders`, and fixing the conflict rule (the most recent change wins). The requirements assume that outcome.
