# Proposal: keep per-device state in UserDefaults, outside CloudKit sync (adr-0009)

## Why

Recorded as Proposed; the owner has not accepted it yet.

Sources and favorites sync through SwiftData on private CloudKit (decision
adr-0002), and secrets live in the synchronizable Keychain (decision
adr-0003). Some state belongs to one device. Two Apple TVs in one home would
overwrite each other's last channel if it synced. The `tvos-shell` capability
tunes the channel last watched on this Apple TV at launch, and the change
`add-session-restore-and-recently-watched` adds a recents list and a session
record on every platform. Channel ids from M3U playlists still embed the
stream link, which can carry provider credentials.

## What Changes

- Per-device state that is not a secret goes in `UserDefaults.standard`. It
  does not go in SwiftData, CloudKit or `NSUbiquitousKeyValueStore`.
- Keys are namespaced by the screen that owns them, `shell.` and
  `recents.`. Current keys are `shell.lastChannel`, `recents.list` and
  `recents.session`.
- Values are small `Codable` structs stored as JSON. A value that cannot be
  decoded reads as absent.
- Nothing stored holds a secret or a stream link. A channel id that contains
  `://` is not stored until the M3U id no longer embeds the link.
- The app owns the `UserDefaults` access. The value types may move into
  AntennaCore as long as they import Foundation only.

## Capabilities

### New Capabilities

None. This is an architecture decision with no requirement of its own.

### Modified Capabilities

None.

## Impact

- No schema, no migration, no sync conflicts. Each device keeps its own
  state.
- Tests swap in a `UserDefaults(suiteName:)` per test.
- A user setting up a new Apple TV starts from the first channel, not from
  where another device left off.
- M3U channels are not restored at launch until the M3U id stops embedding
  the stream link.
- Related: `tvos-shell` and `add-session-restore-and-recently-watched`.
- Follow-up: `add-session-restore-and-recently-watched` reuses this store
  and moves `LastChannelKey` into AntennaCore. It also names the follow-up
  in `m3u-playlists` that stops the M3U channel id from embedding the link.
