# 0004. Source management with iCloud sync

- Status: Draft
- Date: 2026-11-03
- Depends on ADRs: 0001, 0002, 0003, 0005
- Platforms: iOS, iPadOS, macOS, tvOS
- Retroactive: documents behaviour shipped in commit 082034b. Written so later
  changes have a spec to revise or supersede. Tests that do not yet cite a
  criterion are marked TBD in the test plan.

## Problem

A user who adds a playlist on their iPhone expects it on their Apple TV
without typing it again. Sources must be stored once, synced through the
user's own iCloud account, and loaded into one channel list. Credentials must
never travel through SwiftData.

## Scope

In:
- Add source sheet in Settings: type (M3U, Xtream Codes, Stalker portal), name, URL, optional EPG URL for M3U, username and password for the others.
- `SourceRecord` in SwiftData with CloudKit sync; credentials in the Keychain keyed by the record id.
- Sources listed in Settings; swipe-to-delete on iOS and iPadOS, which also removes the Keychain item.
- Channels tab loads every source the first time it is shown with an empty channel list. It does not reload when sources are added, removed or synced (known gap).
- Tapping a channel pushes the player screen.

Out (explicitly):
- Editing or reordering a source.
- Caching channel lists between launches; refresh policy; `lastRefreshedAt`.
- Reloading channels after a source changes.
- Stalker channel loading (the type can be saved but yields no channels).
- Showing load errors to the user (recorded on the model, not rendered).
- The "credential not yet synced" UI state (ADR-0003 follow-up).
- Playback engine selection. The player screen uses `AVPlayer` for every URL as a stopgap, contrary to ADR-0001. A playback spec supersedes AC-14.
- Search, group filtering, favorites (spec 0005).

## User flow

1. User opens Settings, taps "Add source…".
2. Picks a type, enters name and URL, and for Xtream or Stalker a username (or MAC) and password.
3. Taps Save. The sheet closes and the source appears in the Settings list.
4. Opens Channels. A loading indicator shows, then the combined list of channels from all sources.
5. Taps a channel. The player is pushed onto the Channels stack.
6. On another device signed into the same iCloud account the source appears without any action.

tvOS and macOS: the add form is the same, driven by the remote and on-screen
keyboard on tvOS. Deleting a source has no affordance on either platform
today (known gap). Source rows are not focusable on tvOS; only the Add source
button is, so a long source list cannot be scrolled.

## Acceptance criteria

Each criterion is testable in isolation and has a stable id. Do not renumber.

### AC-1 Invalid URL is rejected
Given the URL field contains text without a scheme
When the user taps Save
Then the message "Enter a valid URL." is shown, the sheet stays open, and no `SourceRecord` is inserted.

### AC-2 M3U source is saved
Given type M3U, a valid playlist URL and an EPG URL
When the user taps Save
Then one `SourceRecord` exists with `kind` m3u, that `url` and `epgURL`, `credentialKey` nil, and `sortOrder` equal to the number of sources that existed before.

### AC-3 Name defaults to host
Given an empty name field and URL `http://example.com/list.m3u`
When saved
Then the record name is "example.com".

### AC-4 Xtream credentials go to the Keychain only
Given type Xtream Codes with username and password
When saved
Then the Keychain holds a synchronizable item under service `se.codecrave.antenna.sources` whose account equals `SourceRecord.id.uuidString`, and the `SourceRecord` contains the key but neither the username nor the password.

### AC-5 Keychain failure blocks the save
Given the Keychain write fails
When the user taps Save
Then an error beginning "Could not store credentials" is shown and no `SourceRecord` is inserted.

### AC-6 Deleting a source removes its credential
Given a saved Xtream source, on iOS or iPadOS
When the user swipes to delete it in the Settings list
Then the `SourceRecord` is gone and the Keychain item for its key is gone.

### AC-7 Settings lists sources in order
Given three sources with `sortOrder` 0, 1, 2
When Settings is shown
Then they appear in that order, each with its name and URL.

### AC-8 Empty state
Given no sources
When the Channels tab is shown
Then the "No sources yet" view is shown and no network request is made.

### AC-9 Channels from all sources are combined
Given an M3U source with 2 channels and an Xtream source with 3 streams
When the Channels tab loads for the first time
Then 5 channels are listed, M3U first, in source `sortOrder`.

### AC-10 Missing credential yields no channels
Given an Xtream source whose Keychain item is absent on this device, or whose `credentialKey` is nil
When the Channels tab loads
Then that source contributes zero channels and the other sources still load. A Keychain read error other than not-found follows the AC-11 path.

### AC-11 One failing source does not block the rest
Given one source whose URL returns an error
When the Channels tab loads
Then the remaining sources' channels are listed and the last failure's `localizedDescription` is recorded on the model. Earlier failures are overwritten; none is rendered.

### AC-12 Sources sync between devices
Given a source saved on device A
When device B, signed into the same iCloud account, is online
Then the source appears in device B's Settings and Channels without user action.

### AC-13 Stalker type is stored but inert
Given type Stalker portal with a MAC address and password
When saved and the Channels tab loads
Then a `SourceRecord` with `kind` stalker and a Keychain item exist, the source contributes zero channels, and if it is the only source the Channels tab stays on the loading indicator.

### AC-14 Tapping a channel starts playback (stopgap)
Given a listed channel
When the user taps it
Then a `PlayerView` for the channel is pushed onto the Channels navigation stack and its player's current item URL equals `channel.streamURL`. On iOS, iPadOS and macOS the navigation title is the channel name; tvOS shows no title.

## Edge cases and failure modes

- Any load that yields zero channels in total (offline, Stalker-only, empty playlist) leaves the list on the loading indicator and retries on each appearance, because no error is rendered.
- Slow source: the whole list waits for the slowest source. Sources load sequentially.
- Adding a second source after the list has loaded shows nothing new until the next launch.
- Known defect: an Xtream source whose categories contain duplicate `category_id` values crashes the app (precondition failure in `Dictionary(uniqueKeysWithValues:)` in `SourceLoader`). AC-11 does not hold for this failure mode.
- Sync lag: a `SourceRecord` can arrive before its Keychain item (AC-10 covers the silent case).
- A `SourceRecord` with `url == nil`, possible after a partial CloudKit sync, is silently skipped.
- An unknown `kindRaw`, from a newer app version, falls back to `.m3u` and is fetched as a playlist.
- The EPG URL is not validated; any text is stored through the lenient `URL(string:)`, empty gives nil.
- An M3U URL with no host (for example `file:///x.m3u`) gets the default name "Source". A whitespace-only name is stored as-is.
- User-supplied M3U URLs that embed credentials (`get.php?username=…&password=…`) are stored and synced as part of `url` and displayed in clear in Settings. ADR-0003 rejected embedding credentials in URLs as our own storage strategy; it does not address URLs the user supplies. Accepted today; see open questions.
- Keychain delete failure during AC-6 is swallowed; the record is still deleted and the Keychain item is orphaned.
- The downloaded playlist is decoded as UTF-8 with replacement characters; non-UTF-8 playlists are not rejected.
- All channels of all sources are held in one in-memory array and rendered in a single `List` with an `AsyncImage` per row. Memory and scroll performance are not bounded.
- Not signed into iCloud: the store works locally, nothing syncs, and nothing tells the user.
- `ModelContainer` creation failure is a `fatalError` at launch.
- Deleting a source leaves `FavoriteRecord`s pointing at it (spec 0005).
- Schema rules per ADR-0002: every stored property on `SourceRecord` is optional or defaulted, no unique attributes. Changing the schema needs an ADR.

## Test plan

AC-2 to AC-6 require extracting `AddSourceView.save()` into a testable type
with an injected `CredentialStore` before tests can be written; until then
they are manual. AC-9 to AC-11 and AC-13 additionally require `SourceLoader`
to take an injected `URLSession` and `CredentialStore` (or a `URLProtocol`
stub registered on a custom session) and `ChannelListModel` to call it through
that seam; until then they are manual. AC-14's URL assertion needs `PlayerView`
to expose its player. UI tests require accessibility identifiers
`settings.addSource`, `addSource.save`, `addSource.error`,
`channels.emptyState`, `channels.list` and `player.view`, to be added by the
implementing PR.

| Criterion | Layer | Test |
|-----------|-------|------|
| AC-1 | ui | TBD |
| AC-2 | integration (in-memory ModelContainer, after refactor) | TBD |
| AC-3 | integration (after refactor) | TBD |
| AC-4 | integration (Keychain in simulator, after refactor) | TBD |
| AC-5 | integration (injected failing store, after refactor) | TBD |
| AC-6 | integration (after refactor) | TBD |
| AC-7 | ui | TBD |
| AC-8 | ui | TBD |
| AC-9 | integration (stubbed `URLSession`, after refactor) | TBD |
| AC-10 | integration (after refactor) | TBD |
| AC-11 | integration (after refactor) | TBD |
| AC-12 | device | CloudKit cannot run in CI; manual two-device check |
| AC-13 | integration (after refactor) | TBD |
| AC-14 | ui (view pushed) + manual (current item URL, until `PlayerView` exposes its player) | TBD |

## Open questions

- Fix the duplicate `category_id` crash: build the name map with `Dictionary(_:uniquingKeysWith:)`.
- Should the Stalker option be hidden until the portal handshake ships?
- Where does the error from AC-11 get rendered: inline per source in Settings, or a banner in Channels?
- Should `url` be redacted in Settings, or should credential-bearing M3U URLs be split into Keychain plus base URL?
- Delete affordance on tvOS and macOS.
- `sortOrder` collisions when two devices add a source at once (ADR-0002 follow-up).
