# 0009. Keep per-device state in UserDefaults, outside CloudKit sync

- Status: Proposed
- Date: 2026-11-06
- Related specs: 0015, 0028

## Context

ADR-0002 syncs sources and favorites through SwiftData on private CloudKit,
and ADR-0003 keeps secrets in the synchronizable Keychain. Some state
belongs to one device. Two Apple TVs in one home would overwrite each
other's last channel if it synced. Spec 0015 tunes the channel last watched
on this Apple TV at launch and stores it as `shell.lastChannel`; spec 0028
adds `recents.list` and `recents.session` on every platform. Channel ids
from M3U playlists still embed the stream link, which can carry provider
credentials.

## Decision

Per-device state that is not a secret goes in `UserDefaults.standard`, not
in SwiftData and not in CloudKit or `NSUbiquitousKeyValueStore`.

- Keys are namespaced by the screen that owns them: `shell.`, `recents.`.
- Values are small `Codable` structs stored as JSON. A value that cannot be
  decoded reads as absent.
- Nothing stored holds a secret or a stream link. A channel id that contains
  `://` is not stored until the M3U id no longer embeds the link (the 0001
  follow-up 0028 names).
- The app owns the `UserDefaults` access. The value types may move into
  AntennaCore (0028 moves `LastChannelKey` there) as long as they import
  Foundation only.

## Options considered

1. **SwiftData with a local-only configuration.** A second container and
   schema for a handful of values, with migrations to maintain.
2. **`NSUbiquitousKeyValueStore`.** Syncs, which is what this state must not do.
3. **A JSON file in Application Support.** Same result as `UserDefaults`
   with file handling to write and test.

## Consequences

- Good: no schema, no migration, no sync conflicts; each device keeps its own.
- Good: tests swap in a `UserDefaults(suiteName:)` per test.
- Bad: a user setting up a new Apple TV starts from the first channel, not
  from where another device left off.
- Bad: M3U channels are not restored at launch until the M3U id stops
  embedding the stream link.
- Follow-ups: 0028 reuses this store and moves `LastChannelKey` into
  AntennaCore.
