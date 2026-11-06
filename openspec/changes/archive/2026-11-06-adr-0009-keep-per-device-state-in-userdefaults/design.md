# Design: per-device state in UserDefaults

## Context

Synced data goes through SwiftData on private CloudKit (decision adr-0002,
SwiftData with private CloudKit for sync). Secrets go through the
synchronizable Keychain (decision adr-0003, credentials in iCloud Keychain).
Neither fits state that belongs to one device. The `tvos-shell` capability
stores the channel last watched on this Apple TV as `shell.lastChannel` and
tunes it at launch. The change `add-session-restore-and-recently-watched`
adds `recents.list` and `recents.session` on every platform. Channel ids from
M3U playlists still embed the stream link, and that link can carry provider
credentials.

## Goals / Non-Goals

**Goals:**

- Each device keeps its own last channel and recents without another device
  overwriting them.
- No secret and no stream link is ever written to this store.

**Non-Goals:**

- Carrying per-device state to a new device.
- Restoring M3U channels at launch while their id still embeds the link.

## Decisions

**`UserDefaults.standard` for non-secret per-device state.** Not SwiftData,
not CloudKit, not `NSUbiquitousKeyValueStore`.

**Keys namespaced by the owning screen.** `shell.` and `recents.`.

**Small JSON values.** Values are small `Codable` structs encoded as JSON. A
value that fails to decode reads as absent.

**No secrets, no links.** A channel id that contains `://` is not stored
until the M3U id no longer embeds the link. The change
`add-session-restore-and-recently-watched` names that follow-up against
`m3u-playlists`.

**The app owns access.** Only the app touches `UserDefaults`. The value
types may move into AntennaCore if they import Foundation only;
`add-session-restore-and-recently-watched` moves `LastChannelKey` there.

Options considered:

1. SwiftData with a local-only configuration. Rejected because it means a
   second container and schema for a handful of values, with migrations to
   maintain.
2. `NSUbiquitousKeyValueStore`. Rejected because it syncs, which is what
   this state must not do.
3. A JSON file in Application Support. Same result as `UserDefaults`, with
   file handling to write and test.

## Risks / Trade-offs

- No schema, no migration and no sync conflicts.
- Tests swap in a `UserDefaults(suiteName:)` per test.
- A new Apple TV starts from the first channel, not from where another
  device left off.
- M3U channels are not restored at launch until the M3U id stops embedding
  the stream link.
- Follow-up: `add-session-restore-and-recently-watched` reuses this store
  and moves `LastChannelKey` into AntennaCore.
