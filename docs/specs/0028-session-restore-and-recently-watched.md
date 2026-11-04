# 0028. Session restore and recently watched channels

- Status: Draft (one spec-reviewer round, verdict REWORK, every finding applied; second round pending)
- Date: 2026-11-04
- Depends on ADRs: 0002, 0003, 0005
- ADR needed: none for the design below. Recents and the restored session are per device in `UserDefaults`, as 0015/AC-8 and 0012/AC-11 already do. If the owner wants recents to sync, that is a `RecentChannelRecord` under ADR-0002 and needs an ADR before AC-1 to AC-5 are implemented; see Open questions.
- Platforms: iOS, iPadOS, macOS, tvOS
- Builds on specs 0013 (catalogue, `RowKey`, `channel(for:)`), 0015 (tvOS launch into the last channel, `LastChannelKey`, the `shell.lastChannel` key), 0010 (Live on iPhone, iPad and Mac: chips, sidebar, inline player, nothing-selected state), 0007 (overlay groups), 0008 (channel-change event, current group, full-screen swipes), 0006 (first channel after onboarding), 0004 (source deletion). Fills 0010's out-of-scope item "Session restore of the last played channel (later spec)".
- Blocked on the playback engine spec (not yet written) for an observable engine state; AC-2b, AC-2c, AC-12 and AC-16a to AC-16c use a fake engine until then.
- Blocked on (implementing PR): the 0001 follow-up that hashes `streamURL` out of `Channel.id` (0013 header). 0013's edge cases forbid writing a channel id to `UserDefaults` until then, because an M3U id without `tvg-id` embeds the stream URL and often the provider's credentials. Until it merges, `UserDefaultsRecentsStore` refuses any `channelID` that contains `://` (AC-20) and AC-1 to AC-5 are tested with hashed fixture ids only. The core layer and this spec's core tests can be implemented before the follow-up.

## Design

Boards: `docs/design/boards/iPhone-Recents.dc.html` (iOS and any compact width): the Recents chip selected after Favorites, the list in most-recent-first order with the playing channel as row one, rows in 0010/AC-5 anatomy, no list header. Placement on the other platforms follows the boards those specs own: on `iPad.dc.html` the Recents entry is a Groups row between Favorites and All channels (36 pt, 16 pt text, count at 14 pt muted, 0.08 surface and weight 600 when selected); on `Main.dc.html` it is a group row between Favorites and All channels (64 pt, 29 pt text, count at the trailing edge, Focus token when focused, 0.12 surface and weight 600 when selected but unfocused).
Design rules that apply: DR-1, DR-2, DR-3, DR-4, DR-5, DR-6, DR-7, DR-8, DR-11, DR-12, DR-13. Deviations: none beyond those 0007 and 0010 already declare for their rows.
Identifiers (DR-11): `recents.chip`, `recents.group`, `recents.overlayGroup`, named in the board's comments. Rows and headers keep the host screen's identifiers (`browse.row.<rowKey>`, `browse.listHeader`, `overlay.channel.<rowKey>`, `overlay.channelsHeader`). The Recents chip and rows also carry the host's index identifier (`browse.chip.<index>`, `browse.group.<index>`, `overlay.group.<index>`), which shifts All channels and every group by one while a recent exists; 0007 and 0010 UI tests run with an empty recents suite, and this spec's tests address the entry by `recents.*` only.
Not drawn, to be added before the implementing PR: the iPad and Mac sidebar row (`recents.group`: the Favorites row of `iPad.dc.html` with a clock glyph, 14 by 14 pt, in place of the star, label "Recents", count trailing); the overlay group row (`recents.overlayGroup`: the Favorites row of `Main.dc.html` with a 26 by 26 pt clock glyph in place of the star, label "Recents", count trailing); the iPad list header for Recents (`browse.listHeader` reading "Recents" and "<n> channels" in the 0010/AC-4 style); the overlay header for Recents (`overlay.channelsHeader` reading "Recents" and "Most recent first" in the 0007/AC-4 style); `browse.loading` with the restored channel already playing (`iPhone-Loading.dc.html` and `iPad-Loading.dc.html` with the player showing video and 0010/AC-10a's controls instead of the nothing-selected player, AC-12). No empty state exists: the group is absent when it has nothing to show (AC-7).

## Problem

On iPhone, iPad and Mac the app forgets everything at launch: the user lands on nothing selected, in All channels, and has to find the channel they were watching five minutes ago. On every platform the channels a user returns to are buried among thousands, and favorites only help once the user has curated them. TiviMate users list its recently-watched list among the things they like; its last-channel restore is the behaviour every TV has.

## Scope

In:
- `LastChannelKey`, `RecentChannel`, `RecentsList`, `SessionState` and `BrowseSection` value types in AntennaCore. `LastChannelKey(sourceID: UUID, channelID: String)` is the type 0015/AC-8 names, placed here. `SessionState` carries `section` and `group` only; the last channel has one home, `RecentsStore.lastChannel()`.
- `RecentsStore` protocol in AntennaCore (`recents()`, `save(_ list: RecentsList)`, `lastChannel()`, `save(lastChannel:)`, `session()`, `save(_ session: SessionState)`, `remove(sourceID:)`) and `UserDefaultsRecentsStore` as its production implementation over an injected `UserDefaults`. Production passes `UserDefaults.standard`; tests pass a fresh named suite. Foundation only, no SwiftData (ADR-0005).
- A `.recents` group kind in 0013's `CatalogueGroup`, built by `Catalogue` from `[RecentChannel]` and replaced without a rebuild through `replacingRecents(_:)`, present only while at least one recent resolves.
- `SessionTracker`, a `@MainActor` type in `Apps/Shared/`. Every live tune on every platform goes through `SessionTracker.tune(_ channel: Channel)`, which calls the engine; screens never call `load(_:)` themselves. A VOD or episode play (0011/AC-3a, AC-9b) is not a tune and touches nothing here. The tracker writes the last channel on every tune, a recent after ten seconds of playback, and the session on every section or group change.
- Session restore on iPhone, iPad and Mac: section, group and channel, at cold launch and after the system kills the app in the background.
- The Recents group in 0010's chips and sidebar and in 0007's overlay.
- Two full-screen swipes on tvOS: left for the previously watched channel, right for the overlay opened on Recents.
- Removal of a source's entries when that source is deleted, on the local path and when the record disappears from the synced container.
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
- 0013: `CatalogueGroup` gains `.recents` and `Codable`; `Catalogue.init` gains `recents: [RecentChannel]`; `Catalogue` gains `unresolvedRecents: [RecentChannel]` and `replacingRecents(_ recents: [RecentChannel]) -> Catalogue`, which rebuilds only the Recents group, leaves every other group, number and key unchanged (AC-11b of 0013 holds across the call) and runs within AC-19's bound; AC-2 and AC-17's exact group lists read "[`.favorites`, `.recents` when AC-5 of 0028 resolves at least one entry, `.all`, ...]"; AC-3 adds "`.recents` is the number of resolved recents".
- 0015: `LastChannelKey` is the AntennaCore type; the shell reads and writes it through `RecentsStore` and AC-8's key and payload are unchanged. `ShellNavigator` gains `showOverlay(selecting: CatalogueGroup)` for AC-17.
- 0007: AC-3 lists Recents after Favorites when the group exists; AC-4's header reads "Recents" and "Most recent first" for it; an entry point that opens the overlay with a given group selected (trait and surface, in place of the current group) and focus on its first row, replacing AC-2's initial focus for that call; AC-22 excludes `.recents`: a tune from the Recents column leaves the current group unchanged (0028/AC-9).
- 0008: swipe left and swipe right in full-screen playback are consumed by AC-16a to AC-17, which answers its open question "Should swiping left or right change the current group?" with no; AC-15b's list of tunes that keep the current group gains "the previous-channel swipe of 0028/AC-16a".
- 0010: AC-3 and AC-4 list Recents after Favorites when the group exists; the Scope line "Session restore of the last played channel (later spec)" names this spec; the selected group can disappear while Live is shown (edge case below).
- 0004, or the Sources and Settings spec that supersedes its delete: both the local delete and the observed removal of a `SourceRecord` from the synced container call `RecentsStore.remove(sourceID:)` before the catalogue is rebuilt (AC-21).

## User flow

iPhone, iPad and Mac:
1. The user watches Sport One from the Sport group, then switches to the Guide tab, then goes to the home screen. Hours later iOS has killed the app.
2. The user opens Antenna. The Guide tab is shown. Tapping Live shows the Sport chip selected and Sport One playing inline, as it was.
3. The chips now read Favorites, Recents, All channels, Sport, …. Tapping Recents lists the channels watched for at least ten seconds, most recent first, Sport One on top.
4. Tapping a row plays it. The list keeps its order while it is on screen; the next time Recents is opened the row is on top.

Apple TV:
1. The user has watched channel A, then B. While B plays full screen, swiping left tunes to A and the zap bar shows; swiping left again returns to B.
2. Swiping right opens the overlay with Recents selected and focus on the first row, which is the playing channel once it has been on for ten seconds.
3. In the overlay, Recents sits between Favorites and All channels with its count. Tuning from it does not change the current group, so swipe up and down afterwards still step through the group the user was in.

## Acceptance criteria

Each criterion is testable in isolation and has a stable id. Do not renumber.

### AC-1 Recording order, dedup and cap
Given a `RecentsList` with limit 20 holding keys K1 (newest) to K20 (oldest)
When `recording(K7, at: t)` runs with t later than every stored date, then `recording(K21, at: t + 1)`
Then after the first call K7 is first with `lastWatchedAt == t`, the other nineteen keep their relative order and dates, and the count stays 20; after the second call K21 is first, K20 is gone and the count is 20; the function is pure and the input list is unchanged.

### AC-2a Last channel on every tune
Given a `SessionTracker` with an in-memory `RecentsStore`
When `tune(A)` is called
Then `lastChannel()` is A's `LastChannelKey` before the call returns, and the engine has received `load(_:)` with A's URL once.

### AC-2b Dwell before a channel counts as recent
Given a `SessionTracker` with an injected clock, a fake engine and an empty store
When channel B is tuned at t and the engine reports `.playing` at t + 3 s
Then `recents()` is empty until t + 13 s and then holds exactly B with `lastWatchedAt` t + 13 s. The dwell is ten seconds of continuous `.playing` counted from the first `.playing` after the tune; the engine leaving `.playing` or the app entering the background before that cancels it, and a later `.playing` for the same tune starts a fresh ten seconds.

### AC-2c A tune cancels the dwell
Given the setup of AC-2b with A tuned at t and `.playing` at t
When B is tuned at t + 4 s, `.playing` at t + 5 s, and the clock reaches t + 15 s
Then `recents()` holds exactly B; A is never recorded.

### AC-2d Every screen tunes through the tracker
Given the fixture catalogue and a seeded empty suite
When a channel is tuned from a browse row (iPhone, iPad, Mac), from the overlay, the guide and the previous-channel swipe (tvOS), and from a channel search result (every platform)
Then the suite holds that channel under `shell.lastChannel` before the UI has updated to show it playing.

### AC-3 Store round trip
Given a `UserDefaultsRecentsStore` over a fresh named suite
When a `RecentsList`, a `LastChannelKey` and a `SessionState` are saved and a second store is opened over the same suite
Then the second store returns equal values; the suite holds `Data` under `recents.list` and `recents.session` and, under `shell.lastChannel`, `Data` decoding to the `LastChannelKey` exactly as 0015/AC-8 asserts; `persistentDomain(forName:)` of the suite holds exactly these three keys.

### AC-4 Removing a source
Given a store with recents from sources S and T, `lastChannel()` in S, and a session whose group is `.named(S, "Sport")` and section `.live`
When `remove(sourceID: S)` runs
Then `recents()` holds only T's entries in their order, `lastChannel()` is nil, the session's group is nil and its section is still `.live`.

### AC-5 Recents group in the catalogue
Given recents R1 (newest) to R4 where R1 and R3 each match exactly one loaded channel by `sourceID` and `id`, R2's `channelID` matches no loaded channel and R4's `sourceID` matches no loaded source
When the catalogue is built with those recents
Then `groups` is [`.favorites`, `.recents`, `.all`, ...], `count(of: .recents)` is 2, `rows(in: .recents)` lists R1's then R3's channel with their `RowKey`s and `channel(for:)` on those keys returns the two channels, and `unresolvedRecents` is [R2, R4] in list order. An entry whose `sourceID` and `id` match two loaded channels (0013/AC-11a) is unresolved.

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

### AC-8a Order is frozen while on screen
Given the Recents list is on screen on iPhone, iPad or Mac with rows [A, B, C] and A playing
When the user tunes C from the list and the clock passes the AC-2b dwell
Then the rows on screen stay [A, B, C] with C highlighted.

### AC-8b Order refreshes when shown again
Given AC-8a's state
When the user selects another group and returns to Recents (iPhone, iPad, Mac), reopens the overlay (tvOS), or relaunches
Then the list reads [C, A, B].

### AC-9 Tuning from Recents keeps the current group
Given the current group is G on tvOS and the overlay shows Recents
When the user tunes a channel from the Recents column
Then the current group stays G, 0008/AC-15b's position label applies and 0007/AC-22 does not commit Recents.

### AC-10 Session written on every change
Given Live is shown on iPhone, iPad or Mac
When the user selects a section, or selects a group
Then before the handler returns the store's `SessionState` holds that `section` (`.live`, `.guide`, `.movies`, `.series`, `.search`, `.settings`) and that `group`.

### AC-11a Launch restores section and group
Given a saved session with section `.movies` and group `.named(S, "Sport")`, and S loaded before Live is first shown
When the app cold launches
Then Movies is the shown section; when the user opens Live the Sport group is selected (chip or sidebar row with the selected state) and `browse.filter` is empty.

### AC-11b Group fallbacks
Given a saved group that is nil, or `.named(S, "Kids")` with S loaded without "Kids", or `.recents` with nothing resolving
When Live is first shown
Then All channels is selected.

### AC-11c Group whose source is still loading
Given a saved group `.named(S, "Sport")` and S not yet in a terminal state (0010/AC-16) when Live is first shown
When S finishes loading
Then until then All channels is selected; when S finishes with "Sport" and the user has not selected a group since launch, Sport becomes selected; when S finishes without it, or the user has selected a group, the selection is unchanged. AC-12 plays the saved channel independently of this rule.

### AC-11d Sections that no longer exist
Given a saved section `.movies` or `.series` and no Xtream source (0011/AC-1), or `.series` at compact width
When the app cold launches
Then Live is shown in the first case; in the second, Movies is shown with `movies.kind` on Series.

### AC-12 Launch restores the channel
Given a saved `lastChannel()` K whose source S finishes loading with that channel
When Live is shown
Then the engine receives `load(_:)` once with that channel's URL within one second of S finishing (or of Live appearing, when S had finished first), its state is `.playing`, `browse.nowPlaying` or `browse.panel` shows it, and `browse.row.<rowKey>` is highlighted when it is in the shown group; when the restored section is not Live, no `load(_:)` happens until Live is first shown.

### AC-13a Nothing to restore
Given no `lastChannel()`, or K whose `sourceID` matches no `SourceRecord`, or K whose source finished loading without that `channelID`
When Live is shown
Then `browse.player` shows 0010/AC-23's nothing-selected state, no `load(_:)` is made, and the group follows AC-11a to AC-11c.

### AC-13b Restore stays pending
Given K whose source failed to load, or is waiting for its credential (0010/AC-18)
When Retry succeeds or the credential arrives and the source loads with that channel
Then AC-12 applies, unless the user tuned a channel in between, in which case no `load(_:)` for K is made.

### AC-14 Survives being killed in the background
Given Sport One playing in the Sport group with the Guide tab then selected
When the process is terminated without `applicationWillTerminate` running (`XCUIApplication.terminate()`) and launched again with the same suite
Then AC-11a shows Guide, and Live then shows Sport selected and Sport One playing per AC-12.

### AC-15 Sections that are not restored
Given a saved session with section `.search` or `.settings`
When the app cold launches
Then Live is shown and the saved group and channel restore per AC-11a and AC-12.

### AC-16a Swipe left returns to the previous channel (tvOS)
Given full-screen playback of B, bar visible or hidden, with no overlay, pill or guide visible, and recents [B, A] both resolving
When the user swipes left
Then `load(_:)` is called once with the URL of the first resolving recent other than the playing channel (A), through `SessionTracker.tune`, and the channel-change event fires (0008/AC-1 shows the bar); a swipe while a tune is still loading cancels that load and starts this one (0008/AC-9); with the engine `.failed` the swipe tunes as described.

### AC-16b Swipe left toggles
Given AC-16a has tuned A
When the user swipes left again, before or after A's dwell has passed
Then `load(_:)` is called once with B's URL.

### AC-16c Nothing to return to
Given full-screen playback with no resolving recent other than the playing channel
When the user swipes left
Then no `load(_:)` call is made and the engine state is unchanged.

### AC-17 Swipe right opens the overlay on Recents (tvOS)
Given full-screen playback, bar visible or hidden, with no overlay, pill or guide visible, and the current group G
When the user swipes right
Then the overlay is presented with `recents.overlayGroup` selected (the `.isSelected` trait and the 0.12 surface, G's row has neither), focus on the first Recents row, and the engine state unchanged (0007/AC-1); the current group is still G (AC-9). When `.recents` is absent (AC-7) the overlay opens as 0007/AC-2 describes.

### AC-18 Malformed stored data
Given the suite holds bytes under `recents.list`, `recents.session` and `shell.lastChannel` that do not decode
When a `UserDefaultsRecentsStore` is opened
Then `recents()` is empty, `session()` is nil and `lastChannel()` is nil without throwing; the next save replaces the bytes and AC-3 holds. Given instead a valid `SessionState` whose `section` raw value is unknown, `session()?.section` is `.live` and `group` is kept.

### AC-19 First launch with an empty store
Given no `SourceRecord` and an empty suite
When onboarding completes and 0006/AC-15 plays the first channel
Then `lastChannel()` is that channel, the session's section is `.live` and its group is nil; the next launch follows AC-11b and AC-12.

### AC-20 Credential-bearing ids are refused
Given a `UserDefaultsRecentsStore` and a key whose `channelID` contains `://`
When `save(lastChannel:)` or a `RecentsList` containing it is saved
Then that key is not written (`lastChannel()` stays as before; the list is saved without that entry), no error is thrown, and nothing derived from the key is logged. Superseded when the 0001 follow-up in the header merges; the implementing PR of that follow-up removes the filter and this criterion moves to Dropped.

### AC-21 Source deletion reaches the store
Given an in-memory `ModelContainer` with sources S and T, a `RecentsStore` with entries for both, and the app's source observer running
When S's `SourceRecord` is deleted locally, or removed from the container as a sync would remove it
Then `remove(sourceID: S)` has been called on the store before the catalogue is rebuilt, and AC-4 describes the store's contents.

## Dropped

- AC-2 split into AC-2a to AC-2d: the dwell rule contradicted the edge-case list for buffering streams, the last-channel write had no single seam a test could hit, and the per-screen claim belonged to UI tests.
- AC-8 split into AC-8a and AC-8b: freezing and refreshing fail for different reasons on different platforms.
- AC-11 split into AC-11a to AC-11d: three Givens, no nil-group case, and no rule for a section that 0011/AC-1 has removed.
- AC-13 split into AC-13a and AC-13b: fallback and pending restore are separate tests.
- AC-16 split into AC-16a to AC-16c: first swipe, toggle and nothing-to-return-to.
- AC-10's clause "no field is written only on termination or on entering the background" was an untestable universal; "before the handler returns" carries it. Its `lastChannel` field moved out of `SessionState` so the last channel has one home.

## Edge cases and failure modes

- Offline at launch: every source fails (0010/AC-20), the restore stays pending (AC-13b), Retry after reconnecting completes it.
- Slow or huge source: the restored channel and group wait for their source (AC-11c, AC-13b). Resolving 20 recents against 50 000 channels is two dictionary lookups per entry and is covered by 0013/AC-14's bound; `replacingRecents(_:)` runs on every completed dwell, so it must not rebuild the catalogue.
- Credential not yet synced: the key's source contributes no channels and is neither loaded nor failed (0010/AC-18), so the restore stays pending and the nothing-selected state shows with 0010/AC-24's row. When the credential arrives and the source loads, AC-12 applies.
- Source deleted on another device: the `SourceRecord` disappears from the synced container; the app's observer calls `remove(sourceID:)` on that path as well as on local delete (AC-21).
- The selected group disappears while Live is shown (AC-4 after a sync delete, or a refresh that leaves every recent unresolved): All channels is selected and the list re-renders; the playing channel is unchanged (iPhone, iPad, Mac; tvOS per 0007's edge case on removed rows).
- Channel id changed by a provider refresh: the entry stops resolving and is not listed (AC-5); it stays in the store and ages out through AC-1's cap.
- Two channels with the same `id` in one source (0013/AC-11a): the entry does not resolve.
- `channelID` for an M3U channel without `tvg-id` embeds the stream URL until the 0001 follow-up lands, so such channels are neither restored nor listed until then (AC-20). The store is a local suite that is never synced, never logged and never put in an identifier, label or error; `RecentChannel` has no `streamURL` field (ADR-0003).
- The dwell timer is cancelled by a tune, by the app entering the background, and by the engine leaving `.playing` before the deadline; a later `.playing` restarts it (AC-2b).
- tvOS: AC-16a to AC-17 are ignored while the overlay, pill or guide is visible; while 0008's bar is visible the swipe is still handled (the bar is not focusable). Reduce Motion: no slide.
- VoiceOver: the Recents chip and group rows read "Recents, n channels"; channel rows read as 0010 and 0007 define.
- Entitlement lapse (ADR-0006): the store is untouched and restores after the entitlement returns.

## Test plan

`RecentsList`, the store, the catalogue group and `SessionState` coding are swift-testing tests in AntennaCore over `UserDefaults(suiteName:)` with a fresh name per test. `SessionTracker` is tested with a fake engine, an injected clock and an in-memory `RecentsStore`. AC-21 uses an in-memory `ModelContainer` and a recording store. UI tests launch with `-antenna.uiTest`, a named defaults suite seeded by launch argument, a fixture catalogue with hashed ids and the fake engine that records `load(_:)` to a file in the test's temp directory; nothing derived from `streamURL` appears in any accessibility attribute (ADR-0003). AC-14 uses `XCUIApplication.terminate()` followed by a second `launch()` with the same suite. Identifiers: `recents.chip`, `recents.group`, `recents.overlayGroup`.

| Criterion | Layer | Test |
|-----------|-------|------|
| AC-1 | core | TBD |
| AC-2a | integration (SessionTracker, in-memory store, fake engine) | TBD |
| AC-2b | integration (SessionTracker, injected clock, fake engine) | TBD |
| AC-2c | integration (SessionTracker, injected clock, fake engine) | TBD |
| AC-2d | ui (iPhone, iPad, macOS, tvOS) | TBD |
| AC-3 | core | TBD |
| AC-4 | core | TBD |
| AC-5 | core | TBD |
| AC-6a | ui (iPhone) | TBD |
| AC-6b | ui (iPad, macOS) | TBD |
| AC-6c | ui (tvOS) | TBD |
| AC-7 | core (groups) + ui (iPhone, iPad, tvOS) | TBD |
| AC-8a | ui (iPhone, iPad, injected clock) | TBD |
| AC-8b | ui (iPhone, tvOS) | TBD |
| AC-9 | ui (tvOS) | TBD |
| AC-10 | integration (SessionTracker, in-memory store) | TBD |
| AC-11a | ui (iPhone, iPad, macOS, seeded suite) | TBD |
| AC-11b | ui (iPhone, iPad, seeded suite) | TBD |
| AC-11c | ui (iPad, stubbed slow source) | TBD |
| AC-11d | ui (iPhone, iPad, stubbed sources) | TBD |
| AC-12 | ui (iPhone, macOS, seeded suite, fake engine log) | TBD |
| AC-13a | ui (iPhone, seeded suite, stubbed sources) | TBD |
| AC-13b | ui (iPad, stubbed failures, fake credential store) | TBD |
| AC-14 | ui (iPhone, macOS, terminate and relaunch) | TBD |
| AC-15 | ui (iPhone, seeded suite) | TBD |
| AC-16a | ui (tvOS, fake engine log) | TBD |
| AC-16b | ui (tvOS, fake engine log) | TBD |
| AC-16c | ui (tvOS, fake engine log) | TBD |
| AC-17 | ui (tvOS) | TBD |
| AC-18 | core | TBD |
| AC-19 | ui (iPhone, onboarding fixture) | TBD |
| AC-20 | core | TBD |
| AC-21 | integration (in-memory ModelContainer, recording store) | TBD |

## Open questions

Decisions made without an interview; each can be overturned at review.

- Recents do not sync. Reasons: two Apple TVs in one home would overwrite each other (0015's reasoning), the M3U `channelID` edge above would push credential-bearing ids through CloudKit until the 0001 follow-up lands, and the research names sync of settings and favourites, not of recents. Overturning this means a `RecentChannelRecord` and an ADR.
- Cap of 20 entries and a dwell of ten seconds of continuous playback. TiviMate's list is longer; ten seconds is a guess at "watched" versus "zapped past".
- Restore plays the channel at launch on iPhone, iPad and Mac, including on cellular. The alternative is to select it and show the panel with a play control.
- Search and Settings are not restored (AC-15); Guide, Movies and Series are.
- Tuning from Recents does not make it the current group (AC-9), so swipe up and down never step through a list that reorders itself. TiviMate does the opposite.
- The Recents group is hidden when empty (AC-7) rather than shown with an empty state as Favorites is.
- The order freezes while the list is on screen (AC-8a).
- Swipe left is "previous channel" and swipe right is "overlay on Recents" (AC-16a, AC-17). Either could instead be a long press, or left could step through recents rather than toggle between two.
- AC-20 means M3U channels without `tvg-id` are not restored or listed until the 0001 follow-up merges. The alternative is to store `SHA256(channelID)` now and resolve by hashing loaded ids, which also changes 0015/AC-8's payload.
- tvOS still forgets the current group at cold launch (0008/AC-15c). Restoring it is one more field in `SessionState` and a change to 0008.
- Clearing recents is left to the Sources and Settings spec.
