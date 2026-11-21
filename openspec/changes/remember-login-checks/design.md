# Design

## Context

`SourceLoader.hasLogin` called `CredentialStore.load(for:)` on every
check. `load` makes three `SecItemCopyMatching` calls for a login in the
shared group: one listing the groups that hold it, one reading its data,
and one more listing groups in `removeCopies`. The callers are main-actor
closures: `ShelfModel` on every info fetch and preview (`fetch`), on each
shelf load, and `ShelfModel.hasLogin` before Play (`TitleModel.checkLogin`);
`LiveModel` and `ShellModel` on each source load and in `checkLogins`,
which runs every 5 seconds while a login is missing and on each return to
the front; `AppIntentHost` before an intent plays.

The secret itself is read in `ShelfLoader.info`, `episodes` and `load`,
which are nonisolated `async` and run off the main actor, and in the
Play address (`ShelfLoader.movieURL` and `episodeURL`), once per press.

No screen changes, so no board applies.

## Decisions

### What to remember

Options:
1. Cache the credential in memory. Every later read is free, but a copy
   of every password sits in a dictionary for the app's life, and a change
   on another device is missed until the cache is dropped.
2. Cache only whether a login is here, for logins found. A missing login
   is asked about again on every check, so one that iCloud Keychain
   delivers is seen at once, which `checkLogins` depends on.
3. Cache both answers. The 5 second poll for a missing login would then
   never see it arrive without a separate invalidation from the Keychain,
   which has no change notification.

Chosen: 2. `LoginPresence` holds a `Set` of service and account pairs
behind a `Mutex`. An unreadable login (locked Keychain, bad data) counts
as here, as before, and is remembered too: unlocking does not change the
answer.

### Where the cache sits

`CredentialStoring` gains `hasLogin(for:accepts:)`. Its default
implementation reads every time, so the in-memory stores in tests behave
as before. `CredentialStore` answers from its `presence` (default
`LoginPresence.shared`) and forgets a key in `save` and `delete`. Entries
are keyed by service as well as account, so tests that use their own
service never share entries with each other or with the app. `accepts`
carries the Stalker rule that the username must be a MAC; each key
belongs to one source, so the rule is the same on every ask.

### When to forget

`save` and `delete` on this device forget that key. A login deleted or
changed on another device reaches this one through iCloud Keychain with
no notification, so `ForgetLoginsOnActivate` on the window's root view
forgets everything each time the scene becomes active. Until then a
source whose login was removed elsewhere still counts as having one; its
next load then finds no login and shows no channels, which is the
existing "Missing credential yields no channels" path.

### Play stays as it is

Building the Play address reads the secret on the main actor once per
press. Moving it off would make `ShelfPlayback.start` async and change
when `playing` is set, which the playback and Up Next tests rely on. One
read per press is not on a scrolling or focus path.

## Measurements

Keychain lookups for one Xtream source whose login is in the shared group:

| | Before | After |
|-|--------|-------|
| One `hasLogin` | 3 | 3 the first time, 0 after |
| 50 info fetches, then Play | 156 (51 checks, plus the address) | 6 (1 check, plus the address) |

Counted from `CredentialStore.load`, which `CountingKeychain` in
`LoginPresenceTests` runs against. The time per lookup could not be measured
against the data-protection Keychain the app uses: an unsigned command
line tool gets `errSecMissingEntitlement`. On the legacy file Keychain of
this Mac (M-series, macOS 27.2) one lookup took 5.9 ms for an item that
exists and 18.9 ms for one that does not, so the figures above are a
count, and the time saved per check depends on the device.
