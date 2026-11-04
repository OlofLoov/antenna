# 0028. Session restore and recently watched channels

- Status: Draft
- Date: 2026-11-04
- Depends on ADRs: 0002, 0003, 0005
- ADR needed: none for the design below. Recents and the restored session are per device in `UserDefaults`, as 0015/AC-8 and 0012/AC-11 already do. One decision this spec makes that no ADR covers is that the restored channel plays at launch without asking; it is an open question, not an ADR. If the owner wants recents to sync, that is a `RecentChannelRecord` under ADR-0002 and needs an ADR before AC-1 to AC-4 are implemented; see Open questions.
- Platforms: iOS, iPadOS, macOS, tvOS
- Builds on specs 0013 (catalogue, `RowKey`, `channel(for:)`), 0015 (tvOS launch into the last channel, `LastChannelKey`, the `shell.lastChannel` key), 0010 (Live on iPhone, iPad and Mac: chips, sidebar, inline player, nothing-selected state), 0007 (overlay groups), 0008 (channel-change event, current group, full-screen swipes), 0006 (first channel after onboarding). Fills 0010's out-of-scope item "Session restore of the last played channel (later spec)".
- Blocked on the playback engine spec (not yet written) for an observable engine state; AC-2b, AC-12 and AC-16 use a fake engine until then.

## Design

Boards: `docs/design/boards/iPhone-Recents.dc.html` (iOS and any compact width): the Recents chip selected after Favorites, the list in most-recent-first order with the playing channel as row one, rows in 0010/AC-5 anatomy, no list header. Placement on the other platforms follows the boards those specs own: on `iPad.dc.html` the Recents entry is a Groups row between Favorites and All channels (36 pt, 16 pt text, count at 14 pt muted, 0.08 surface and weight 600 when selected); on `Main.dc.html` it is a group row between Favorites and All channels (64 pt, 29 pt text, count at the trailing edge, Focus token when focused, 0.12 surface and weight 600 when selected but unfocused).
Design rules that apply: DR-1, DR-2, DR-3, DR-4, DR-5, DR-6, DR-7, DR-8, DR-11, DR-12, DR-13. Deviations: none beyond those 0007 and 0010 already declare for their rows.
Identifiers (DR-11): `recents.chip`, `recents.group`, `recents.overlayGroup`, named in the board's comments. Rows and headers keep the host screen's identifiers (`browse.row.<rowKey>`, `browse.listHeader`, `overlay.channel.<rowKey>`, `overlay.channelsHeader`).
Not drawn: the iPad and Mac sidebar row (`recents.group`: the Favorites row of `iPad.dc.html` with a clock glyph, 14 by 14 pt, in place of the star, label "Recents", count trailing); the overlay group row (`recents.overlayGroup`: the Favorites row of `Main.dc.html` with a 26 by 26 pt clock glyph in place of the star, label "Recents", count trailing); the iPad list header for Recents (`browse.listHeader` reading "Recents" and "<n> channels" in the 0010/AC-4 style); the overlay header for Recents (`overlay.channelsHeader` reading "Recents" and "Most recent first" in the 0007/AC-4 style). Each is a one-row variant of a drawn row. No empty state exists: the group is absent when it has nothing to show (AC-7).

## Problem

On iPhone, iPad and Mac the app forgets everything at launch: the user lands on nothing selected, in All channels, and has to find the channel they were watching five minutes ago. On every platform the channels a user returns to are buried among thousands, and favorites only help once the user has curated them. TiviMate users list its recently-watched list among the things they like; its last-channel restore is the behaviour every TV has.

## Scope

In:
- `LastChannelKey`, `RecentChannel`, `RecentsList`, `SessionState` and `BrowseSection` value types in AntennaCore. `LastChannelKey(sourceID: UUID, channelID: String)` is the type 0015/AC-8 names, placed here.
- `RecentsStore` protocol in AntennaCore and `UserDefaultsRecentsStore` as its production implementation over an injected `UserDefaults` suite. Foundation only, no SwiftData (ADR-0005).
- A `.recents` group kind in 0013's `CatalogueGroup`, built by `Catalogue` from `[RecentChannel]`, present only while at least one recent resolves.
- `SessionTracker`, a `@MainActor` type in `Apps/Shared/`, fed by every tune and by the engine state: writes the last channel on every tune, a recent after ten seconds of playback, and the session on every section or group change.
- Session restore on iPhone, iPad and Mac: section, group and channel, at cold launch and after the system kills the app in the background.
- The Recents group in 0010's chips and sidebar and in 0007's overlay.
- Two full-screen swipes on tvOS: left for the previously watched channel, right for the overlay opened on Recents.
- Removal of a source's entries when that source is deleted.
- Accessibility identifiers with prefix `recents.`.

Out (explicitly):
- Syncing recents or the session between devices (needs an ADR; Open questions).
- tvOS launch into the last channel (0015/AC-2a, AC-2b, AC-8; this spec only moves the storage behind `RecentsStore`).
- Restoring the current group on tvOS at cold launch (0008/AC-15c stands; Open questions).
- Clearing or editing recents, and a privacy toggle that stops recording (Sources and Settings spec).
- Restoring Search, Settings or a Movies detail page (AC-15 falls back; 0011 and 0012 own their screens).
- Resume position inside VOD playback (0011/AC-10a).
- Multiple windows on macOS and iPadOS: one session is stored and restored for the first window.
- Recent searches (0012/AC-11, a separate store).
- Top Shelf or Siri Suggestions built from recents.

Required of other specs:
- 0013: `CatalogueGroup` gains `.recents` and `Codable`; `Catalogue.init` gains `recents: [RecentChannel]` and `Catalogue` gains `unresolvedRecents: [RecentChannel]`; AC-2 and AC-17's exact group lists read "[`.favorites`, `.recents` when AC-5 of 0028 resolves at least one entry, `.all`, ...]"; AC-3 adds "`.recents` is the number of resolved recents".
- 0015: `LastChannelKey` is the AntennaCore type; the shell reads and writes it through `RecentsStore` and AC-8's key and payload are unchanged. The shell's `ShellNavigator` gains `showOverlay(selecting: CatalogueGroup)` for AC-17.
- 0007: AC-3 lists Recents after Favorites when the group exists; AC-4's header reads "Recents" and "Most recent first" for it; a way to open the overlay with a given group selected and focus on its first row, replacing AC-2's initial focus for that call.
- 0008: swipe left and swipe right in full-screen playback are consumed by AC-16 and AC-17, which answers its open question "Should swiping left or right change the current group?" with no.
- 0010: AC-3 and AC-4 list Recents after Favorites when the group exists; the Scope line "Session restore of the last played channel (later spec)" names this spec.

## User flow

iPhone, iPad and Mac:
1. The user watches Sport One from the Sport group, then switches to the Guide tab, then goes to the home screen. Hours later iOS has killed the app.
2. The user opens Antenna. The Guide tab is shown. Tapping Live shows the Sport chip selected and Sport One playing inline, as it was.
3. The chips now read Favorites, Recents, All channels, Sport, …. Tapping Recents lists the channels watched for at least ten seconds, most recent first, Sport One on top.
4. Tapping a row plays it. The list keeps its order while it is on screen; the next time Recents is opened the row is on top.

Apple TV:
1. The user has watched channel A, then B. While B plays full screen, swiping left tunes to A and the zap bar shows; swiping left again returns to B.
2. Swiping right opens the overlay with Recents selected and focus on the first row, the channel now playing.
3. In the overlay, Recents sits between Favorites and All channels with its count. Tuning from it does not change the current group, so swipe up and down afterwards still step through the group the user was in.

## Acceptance criteria

Each criterion is testable in isolation and has a stable id. Do not renumber.

### AC-1 Recording order, dedup and cap
Given a `RecentsList` with limit 20 holding keys K1 (newest) to K20 (oldest)
When `recording(K7, at: t)` runs with t later than every stored date, then `recording(K21, at: t + 1)`
Then after the first call K7 is first with `lastWatchedAt == t`, the other nineteen keep their relative order and dates, and the count stays 20; after the second call K21 is first, K20 is gone and the count is 20; the function is pure and the input list is unchanged.

### AC-2a Last channel on every tune
Given a `SessionTracker` with an in-memory `RecentsStore`
When channel A is tuned
Then the store's `lastChannel()` is A's `LastChannelKey` before the tune call returns, on every platform and from every screen that tunes (0007/AC-9, 0008/AC-9, 0008/AC-11, 0009, 0010/AC-6, 0012, 0006/AC-15).

### AC-2b Dwell before a channel counts as recent
Given a `SessionTracker` with an injected clock, a fake engine and an empty `RecentsStore`
When channel A is tuned at t, channel B at t + 4 s, and the clock advances to t + 14 s with the engine `.playing`
Then `recents()` is empty until t + 14 s and then holds exactly B with `lastWatchedAt` t + 14 s; A is never recorded. If the engine is not `.playing` at the deadline, nothing is recorded and no later check is made for that tune.

### AC-3 Store round trip
Given a `UserDefaultsRecentsStore` over an injected suite
When a `RecentsList`, a `LastChannelKey` and a `SessionState` are saved and a second store is opened over the same suite
Then the second store returns equal values; the suite holds `Data` under `recents.list` and `recents.session` and, under `shell.lastChannel`, `Data` decoding to the `LastChannelKey` exactly as 0015/AC-8 asserts; `persistentDomain(forName:)` of the suite holds exactly these three keys.

### AC-4 Removing a source
Given a store with recents from sources S and T, the last channel in S, and a session whose group is `.named(S, "Sport")` and section `.live`
When `remove(sourceID: S)` runs
Then `recents()` holds only T's entries in their order, the last channel is nil, the session's group is nil and its section is still `.live`.

### AC-5 Recents group in the catalogue
Given recents R1 (newest) to R4 where R1 and R3 resolve under 0013/AC-15's rule (the channel with that `sourceID` and `id`, when exactly one is loaded), R2's `channelID` matches no loaded channel and R4's `sourceID` matches no loaded source
When the catalogue is built with those recents
Then `groups` is [`.favorites`, `.recents`, `.all`, ...], `count(of: .recents)` is 2, `rows(in: .recents)` lists R1's then R3's channel with their `RowKey`s, and `unresolvedRecents` is [R2, R4] in list order; `channel(for:)` on the returned keys gives the two channels.

### AC-6a Recents chip on iPhone
Given the catalogue of AC-5 at compact width
When the chips are rendered
Then `recents.chip` reads "Recents", sits after Favorites and before All channels, carries no count, and selecting it lists the AC-5 rows in that order with 0010/AC-5's anatomy, no `browse.listHeader`, and the chip shown selected.

### AC-6b Recents in the iPad and Mac sidebar
Given the catalogue of AC-5 at regular width
When the sidebar is rendered
Then `recents.group` reads "Recents" with count "2" after Favorites and before All channels, and selecting it lists the AC-5 rows with `browse.listHeader` reading "Recents" and "2 channels".

### AC-6c Recents in the overlay
Given the catalogue of AC-5 on tvOS
When the overlay opens
Then `recents.overlayGroup` reads "Recents" with count 2 at the trailing edge after Favorites and before All channels, and focusing it lists the AC-5 rows with `overlay.channelsHeader` reading "Recents" and "Most recent first".

### AC-7 Absent when nothing resolves
Given an empty store, or a store whose entries all fail AC-5's resolution
When chips, sidebar or overlay groups are rendered
Then `recents.chip`, `recents.group` and `recents.overlayGroup` do not exist, `groups` has no `.recents`, and the groups that follow Favorites are as 0010/AC-3, 0010/AC-4 and 0007/AC-3 describe without this spec.

### AC-8 Order is frozen while on screen
Given the Recents list is on screen with rows [A, B, C] and A playing
When the user tunes C from the list and the clock passes the AC-2b dwell
Then the rows on screen stay [A, B, C] with C highlighted; leaving the group and returning, reopening the overlay, or relaunching lists [C, A, B].

### AC-9 Tuning from Recents keeps the current group
Given the current group is G on tvOS and the overlay shows Recents
When the user tunes a channel from the Recents column
Then the current group stays G, 0008/AC-15b's position label applies and 0007/AC-22 does not commit Recents.

### AC-10 Session written on every change
Given Live is shown on iPhone, iPad or Mac
When the user selects a section, selects a group, or tunes a channel
Then before the handler returns the store's `SessionState` holds that `section` (`.live`, `.guide`, `.movies`, `.series`, `.search`, `.settings`), that `group` and that `lastChannel`; no field is written only on termination or on entering the background.

### AC-11 Launch restores section and group
Given a saved session with section `.movies` and group `.named(S, "Sport")`
When the app cold launches with S loaded
Then Movies is the shown section; when the user opens Live the Sport group is selected (chip or sidebar row with the selected state) and `browse.filter` is empty; given group `.named(S, "Kids")` and S loaded without "Kids", or `.recents` with nothing resolving, All channels is selected instead; the selection made at the first rendering of chips or sidebar is not changed by a source finishing later.

### AC-12 Launch restores the channel
Given a saved last channel K whose source S finishes loading with that channel
When Live is shown
Then the engine receives `load(_:)` once with that channel's URL within one second of S finishing (or of Live appearing, when S had finished first), its state is `.playing`, `browse.row.<rowKey>` is highlighted and `browse.nowPlaying` or `browse.panel` shows it; when the restored section is not Live, no `load(_:)` happens until Live is first shown.

### AC-13 Restore fallbacks
Given no last channel, or K whose `sourceID` matches no `SourceRecord`, or K whose source finished loading without that `channelID`
When Live is shown
Then `browse.player` shows 0010/AC-23's nothing-selected state, no `load(_:)` is made, and the group follows AC-11; given K whose source failed to load, the restore stays pending and completes per AC-12 when a Retry succeeds, unless the user has tuned a channel in between, which ends the pending restore.

### AC-14 Survives being killed in the background
Given Sport One playing in the Sport group with the Guide tab then selected
When the process is terminated while in the background and the app is launched again with the same `UserDefaults` suite
Then AC-11 shows Guide, and Live then shows Sport selected and Sport One playing per AC-12.

### AC-15 Sections that are not restored
Given a saved session with section `.search` or `.settings`
When the app cold launches
Then Live is shown and the saved group and channel restore per AC-11 and AC-12.

### AC-16 Swipe left returns to the previous channel (tvOS)
Given full-screen playback of B, bar visible or hidden, with no overlay, pill or guide visible, and recents [B, A] both resolving
When the user swipes left
Then `load(_:)` is called once with the URL of the first resolving recent other than the playing channel (A) and the channel-change event fires (0008/AC-1 shows the bar); a second swipe left, before or after A's dwell has passed, loads B; when no resolving recent other than the playing channel exists the swipe does nothing and the engine state is unchanged.

### AC-17 Swipe right opens the overlay on Recents (tvOS)
Given full-screen playback, bar visible or hidden, with no overlay, pill or guide visible
When the user swipes right
Then the overlay is presented with `recents.overlayGroup` selected and focus on the first Recents row, the engine state unchanged (0007/AC-1); when `.recents` is absent (AC-7) the overlay opens as 0007/AC-2 describes.

### AC-18 Malformed stored data
Given the suite holds bytes under `recents.list`, `recents.session` and `shell.lastChannel` that do not decode
When a `UserDefaultsRecentsStore` is opened
Then `recents()` is empty, `session()` is nil and `lastChannel()` is nil without throwing; the next save replaces the bytes and AC-3 holds.

### AC-19 First launch with an empty store
Given no `SourceRecord` and an empty suite
When onboarding completes and 0006/AC-15 plays the first channel
Then the store's last channel is that channel, the session's section is `.live` and its group is nil (no group was selected), so the next launch shows All channels and plays it per AC-11 and AC-12.

## Edge cases and failure modes

- Offline at launch: every source fails (0010/AC-20), the restore stays pending (AC-13), Retry after reconnecting completes it.
- Slow or huge source: the restored channel waits for its source; the group selection is decided when chips or sidebar first render (AC-11). Resolving 20 recents against 50 000 channels is two dictionary lookups per entry and is covered by 0013/AC-14's bound.
- Credential not yet synced: the key's source contributes no channels and is neither loaded nor failed (0010/AC-18), so the restore stays pending and the nothing-selected state shows with 0010/AC-24's row. When the credential arrives and the source loads, AC-12 applies.
- Source deleted on another device: the `SourceRecord` disappears from the synced container; the app calls `remove(sourceID:)` on that path as well as on local delete (AC-4).
- Channel id changed by a provider refresh: the entry stops resolving and is not listed (AC-5); it stays in the store and ages out through AC-1's cap.
- Two channels with the same `id` in one source (0013/AC-11a): the entry does not resolve, as 0013/AC-15 returns nil.
- `channelID` for an M3U channel without `tvg-id` embeds the stream URL until the 0001 follow-up 0013 names lands, so for such channels the key can carry credentials. The store is a local suite that is never synced, never logged and never put in an identifier, label or error; `RecentChannel` has no `streamURL` field (ADR-0003). This is the same exposure 0015/AC-8 and `FavoriteRecord` accept.
- The dwell timer is cancelled by a tune, by the app entering the background, and by the engine leaving `.playing` before the deadline.
- tvOS: AC-16 and AC-17 are ignored while the overlay, pill or guide is visible, and while 0008's bar is visible the swipe is still handled (the bar is not focusable). Reduce Motion: no slide.
- VoiceOver: the Recents chip and rows read "Recents, n channels"; rows read as 0010 and 0007 define.
- Entitlement lapse (ADR-0006): the store is untouched and restores after the entitlement returns.
- A `SessionState` whose `section` raw value is unknown (newer app version) decodes as `.live`.

## Test plan

`RecentsList`, the store, the catalogue group and `SessionState` coding are swift-testing tests in AntennaCore over an injected `UserDefaults(suiteName:)`. `SessionTracker` is a `@MainActor` type in `Apps/Shared/` tested with a fake engine, an injected clock and an in-memory `RecentsStore`. UI tests launch with `-antenna.uiTest`, a named defaults suite seeded by launch argument, a fixture catalogue and the fake engine that records `load(_:)` to a file in the test's temp directory; nothing derived from `streamURL` appears in any accessibility attribute (ADR-0003). AC-14 uses `XCUIApplication.terminate()` followed by a second `launch()` with the same suite. Identifiers: `recents.chip`, `recents.group`, `recents.overlayGroup`.

| Criterion | Layer | Test |
|-----------|-------|------|
| AC-1 | core | TBD |
| AC-2a | integration (SessionTracker, in-memory store) | TBD |
| AC-2b | integration (SessionTracker, injected clock, fake engine) | TBD |
| AC-3 | core | TBD |
| AC-4 | core | TBD |
| AC-5 | core | TBD |
| AC-6a | ui (iPhone) | TBD |
| AC-6b | ui (iPad, macOS) | TBD |
| AC-6c | ui (tvOS) | TBD |
| AC-7 | core (groups) + ui (three platforms) | TBD |
| AC-8 | ui (iPhone, injected clock) | TBD |
| AC-9 | ui (tvOS) | TBD |
| AC-10 | integration (SessionTracker, in-memory store) | TBD |
| AC-11 | ui (iPhone and iPad, seeded suite) | TBD |
| AC-12 | ui (seeded suite, fake engine log) | TBD |
| AC-13 | ui (seeded suite, stubbed sources) | TBD |
| AC-14 | ui (terminate and relaunch) | TBD |
| AC-15 | ui (seeded suite) | TBD |
| AC-16 | ui (tvOS, fake engine log) | TBD |
| AC-17 | ui (tvOS) | TBD |
| AC-18 | core | TBD |
| AC-19 | ui (iPhone, onboarding fixture) | TBD |

## Open questions

Decisions made without an interview; each can be overturned at review.

- Recents do not sync. Reasons: two Apple TVs in one home would overwrite each other (0015's reasoning), the M3U `channelID` edge above would push credential-bearing ids through CloudKit until the 0001 follow-up lands, and the research names sync of settings and favourites, not of recents. Overturning this means a `RecentChannelRecord` and an ADR.
- Cap of 20 entries and a dwell of ten seconds. TiviMate's list is longer; ten seconds is a guess at "watched" versus "zapped past".
- Restore plays the channel at launch on iPhone, iPad and Mac, including on cellular. The alternative is to select it and show the panel with a play control.
- Search and Settings are not restored (AC-15); Guide, Movies and Series are.
- Tuning from Recents does not make it the current group (AC-9), so swipe up and down never step through a list that reorders itself. TiviMate does the opposite.
- The Recents group is hidden when empty (AC-7) rather than shown with an empty state as Favorites is.
- The order freezes while the list is on screen (AC-8).
- Swipe left is "previous channel" and swipe right is "overlay on Recents" (AC-16, AC-17). Either could instead be a long press, or left could step through recents rather than toggle between two.
- tvOS still forgets the current group at cold launch (0008/AC-15c). Restoring it is one more field in `SessionState` and a change to 0008.
- Clearing recents is left to the Sources and Settings spec.
