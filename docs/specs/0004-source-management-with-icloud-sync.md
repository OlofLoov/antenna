# 0004. Source management with iCloud sync

- Status: In progress
- Progress: AC-2 to AC-6, AC-9 to AC-11, AC-13, AC-15 to AC-18 and the integration halves of AC-1 and AC-8 in this PR. AC-7, AC-14 and the ui halves of AC-1 and AC-8 wait for the UI test target that the 0005 UI test work adds.
- Date: 2026-11-03
- Depends on ADRs: 0001, 0002, 0003, 0005
- Platforms: iOS, iPadOS, macOS, tvOS
- User stories: US-2, US-5, US-7
- Superseded in part: AC-8, AC-14 and the loading-indicator edge case by 0010
  on iOS, iPadOS and macOS (Accepted; the Channels tab is renamed Live).
  AC-6, AC-7, AC-9 ("first time"), AC-10 and AC-11 by 0023 (Draft). AC-18 by
  0030 (Draft). Each criterion stays in force until the replacing spec is
  Implemented. The delete-path additions other specs expect of 0004 (0021
  `GuideOverridesRecord`, 0029 `removeSource(_:)`, 0037 `remove(sourceID:)`)
  belong to 0023's delete path, not to this spec.
- Retroactive: documents behaviour shipped in commit 082034b. Written so later
  changes have a spec to revise or supersede. Its tests live in
  `AntennaTests` and run in CI only; rows still marked TBD need a UI test
  target.

## Design

Boards: none. The shipped UI predates docs/design; the boarded Settings is
0023, the add flow 0006, and Live 0010.
Design rules that apply: none.
Identifiers: `settings.addSource`, `settings.source.<id>`, `addSource.save`,
`addSource.error`, `channels.emptyState`, `player.view`.

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
keyboard on tvOS. Save and Cancel are the sheet's toolbar items. Deleting a
source has no affordance on either platform today (known gap). Source rows
are not focusable on tvOS; only the Add source button is, so a long source
list cannot be scrolled. Initial focus in the sheet and what Menu does there
are not specified (see open questions).

## Acceptance criteria

Each criterion is testable in isolation and has a stable id. Do not renumber.

### AC-1 Invalid URL is rejected
Given the URL field contains text without a scheme
When the user taps Save
Then the save fails with the message "Enter a valid URL.", the sheet stays open, and no `SourceRecord` is inserted.

### AC-2 M3U source is saved
Given N existing sources, type M3U, playlist URL U and EPG URL E
When the user taps Save
Then exactly one new `SourceRecord` exists with `kind` m3u, `url` U, `epgURL` E, `credentialKey` nil and `sortOrder` N.

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
Then the save fails with a message beginning "Could not store credentials" and no `SourceRecord` is inserted.

### AC-6 Deleting a source removes its credential
Given a saved Xtream source, on iOS or iPadOS
When the user swipes to delete it in the Settings list
Then the `SourceRecord` is gone and the Keychain item for its key is gone.

### AC-7 Settings lists sources in order
Given three sources with `sortOrder` 0, 1, 2
When Settings is shown
Then rows `settings.source.<id>` appear in that order, each with its name and URL.

### AC-8 Empty state
Given no sources
When the Channels tab is shown
Then `channels.emptyState` is shown and no network request is made.

### AC-9 Channels from all sources are combined
Given an M3U source with 2 channels and an Xtream source with 3 streams
When the Channels tab loads for the first time
Then 5 channels are listed, M3U first, in source `sortOrder`.

### AC-10 Missing credential yields no channels
Given an Xtream source (sortOrder 0) whose Keychain item is absent on this device and an M3U source (sortOrder 1) with 2 channels
When the Channels tab loads
Then `ChannelListModel.channels` holds exactly the M3U source's 2 channels and no request is made to the Xtream server.

### AC-11 One failing source does not block the rest
Given an M3U source (sortOrder 0) whose request fails with a transport error and an M3U source (sortOrder 1) with 2 channels
When the Channels tab loads
Then `ChannelListModel.channels` holds exactly the second source's 2 channels.

### AC-12 Sources sync between devices
Given a source saved on device A
When device B, signed into the same iCloud account, finishes a CloudKit import
Then the source is listed in device B's Settings.

### AC-13 Stalker type is stored
Given type Stalker portal with a MAC address and password
When saved
Then a `SourceRecord` with `kind` stalker exists, and the Keychain item under its id holds the MAC address as username and the password.

### AC-14 Tapping a channel starts playback (stopgap)
Given a listed channel
When the user selects it (tap on iOS and iPadOS, click on macOS, select on tvOS)
Then `player.view` is pushed onto the Channels navigation stack, playing `channel.streamURL`, with `navigationTitle` set to the channel name on every platform.

### AC-15 Load failure is recorded
Given the AC-11 fixture
When the Channels tab loads
Then `ChannelListModel.error` equals the failure's `localizedDescription`. With two failing sources it holds the later one, and a later successful source does not clear it.

### AC-16 Nil credential key yields no channels
Given an Xtream source (sortOrder 0) whose `credentialKey` is nil and an M3U source (sortOrder 1) with 2 channels
When the Channels tab loads
Then `ChannelListModel.channels` holds exactly the M3U source's 2 channels and no request is made to the Xtream server.

### AC-17 Unreadable credential
Given an Xtream source whose Keychain read fails with a status other than `errSecItemNotFound`, or whose stored data does not decode
When the Channels tab loads
Then the source contributes zero channels and the failure is handled as AC-11 and AC-15 describe.

### AC-18 Stalker contributes no channels
Given a Stalker source (sortOrder 0) with a stored credential and an M3U source (sortOrder 1) with 2 channels
When the Channels tab loads
Then `ChannelListModel.channels` holds exactly the 2 M3U channels and no request is made to the portal.

## Edge cases and failure modes

- Any load that yields zero channels in total (offline, Stalker-only, empty playlist) leaves the list on the loading indicator and retries on each appearance, because no error is rendered.
- Offline at launch: every source fails or yields nothing; the list stays on the loading indicator and `ChannelListModel.error` holds the last transport error.
- An M3U URL answering non-2xx fails that source like a transport error (AC-11, AC-15). An HTML page answering 200 still parses to zero channels and records no error.
- Slow source: the whole list waits for the slowest source. Sources load sequentially.
- A source with tens of thousands of channels is downloaded, parsed and held in memory before anything renders.
- Adding, removing or reordering a source reloads the list.
- Deleting a source reloads the list without its channels. Deleting every source clears the list and shows the AC-8 empty state.
- Adding the same source twice is allowed (no dedup, ADR-0002). Both load, and channels with identical ids appear twice in one `List`; SwiftUI identity for those rows is undefined.
- An Xtream source whose categories repeat a `category_id` loads; the first name for that id is used.
- Sync lag: a `SourceRecord` can arrive before its Keychain item (AC-10 covers the silent case).
- A source synced to device B while its Channels list is open reloads the list there.
- tvOS: synchronizable Keychain items do not reach Apple TV (pending the ADR-0003 amendment named in 0006 and 0023), so a synced Xtream or Stalker source is listed in Settings and contributes zero channels there permanently (AC-10).
- A `SourceRecord` with `url == nil`, possible after a partial CloudKit sync, is silently skipped by the loader and shows an empty URL line in Settings.
- An unknown `kindRaw`, from a newer app version, falls back to `.m3u` and is fetched as a playlist.
- The EPG URL is not validated; any text is stored through the lenient `URL(string:)`, empty gives nil.
- An EPG URL typed before switching the type to Xtream or Stalker is hidden but still saved as `epgURL`.
- If counting the existing sources fails during save, the new source gets `sortOrder` 0 and the save goes ahead.
- An M3U URL with no host (for example `file:///x.m3u`) gets the default name "Source". A whitespace-only name is stored as-is.
- The AC-5 message appends the raw error, for example "unexpectedStatus(-34018)", so users see an internal status code.
- Equal `sortOrder` values (two devices adding at once) render in undefined order.
- User-supplied M3U URLs that embed credentials (`get.php?username=…&password=…`) are stored and synced as part of `url` and displayed in clear in Settings. ADR-0003 rejected embedding credentials in URLs as our own storage strategy; it does not address URLs the user supplies. Accepted today; see open questions.
- Keychain delete failure during AC-6 is swallowed; the record is still deleted and the Keychain item is orphaned.
- The downloaded playlist is decoded as UTF-8 with replacement characters; non-UTF-8 playlists are not rejected.
- All channels of all sources are held in one in-memory array and rendered in a single `List` with an `AsyncImage` per row. Memory and scroll performance are not bounded.
- Not signed into iCloud: the store works locally, nothing syncs, and nothing tells the user.
- `ModelContainer` creation failure is a `fatalError` at launch.
- Deleting a source leaves `FavoriteRecord`s pointing at it (spec 0005).
- Schema rules per ADR-0002: every stored property on `SourceRecord` is optional or defaulted, no unique attributes. Changing the schema needs an ADR.

## Test plan

AC-1 to AC-6 and AC-13 require extracting `AddSourceView.save()` and the
Settings `onDelete` body into a testable type with an injected
`CredentialStore` before tests can be written. AC-9 to AC-11 and AC-15 to
AC-18 additionally require `SourceLoader` to take an injected `URLSession`
and `CredentialStore` (or a `URLProtocol` stub registered on a custom
session) and `ChannelListModel` to call it through that seam. AC-14's URL
check is manual until `PlayerView` exposes its player. UI tests require the
identifiers in the Design section, which the code sets.

| Criterion | Layer | Test |
|-----------|-------|------|
| AC-1 | integration (save path) + ui (sheet stays open) | `SourceManagementTests.invalidURL`; ui half TBD, needs a UI test target |
| AC-2 | integration (in-memory ModelContainer) | `SourceManagementTests.m3uSaved` |
| AC-3 | integration | `SourceManagementTests.nameDefaultsToHost` |
| AC-4 | integration (Keychain in simulator) | `SourceManagementTests.xtreamCredentialsInKeychain` |
| AC-5 | integration (injected failing store) | `SourceManagementTests.keychainFailureBlocksSave` |
| AC-6 | integration | `SourceManagementTests.deleteRemovesCredential` |
| AC-7 | ui | TBD, needs a UI test target |
| AC-8 | ui (empty state) + integration (URLProtocol stub records zero requests) | `SourceManagementTests.emptyStateMakesNoRequest` (iOS, hosts `ChannelsView`); ui half TBD |
| AC-9 | integration (stubbed `URLSession`) | `SourceManagementTests.combined` |
| AC-10 | integration | `SourceManagementTests.missingCredential` |
| AC-11 | integration | `SourceManagementTests.failingSourceDoesNotBlock` |
| AC-12 | device | CloudKit cannot run in CI; manual two-device check |
| AC-13 | integration (Keychain in simulator) | `SourceManagementTests.stalkerStored` |
| AC-14 | ui (view pushed) + manual (current item URL) | TBD, needs a UI test target |
| AC-15 | integration | `SourceManagementTests.lastFailureRecorded` |
| AC-16 | integration | `SourceManagementTests.nilCredentialKey` |
| AC-17 | integration (injected failing store, garbled Keychain item) | `SourceManagementTests.unreadableCredential` |
| AC-18 | integration | `SourceManagementTests.stalkerInert` |

## Open questions

- Fix the duplicate `category_id` crash: build the name map with `Dictionary(_:uniquingKeysWith:)`.
- Should the Stalker option be hidden until the portal handshake ships?
- Where does the error from AC-15 get rendered: inline per source in Settings, or a banner in Channels?
- Should `url` be redacted in Settings, or should credential-bearing M3U URLs be split into Keychain plus base URL?
- Delete affordance on tvOS and macOS.
- `sortOrder` collisions when two devices add a source at once (ADR-0002 follow-up).
- tvOS add sheet: where initial focus lands and whether Menu dismisses without saving. Not checked against a build.
