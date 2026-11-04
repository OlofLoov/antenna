# 0028. Session restore and recently watched channels

- Status: Draft (two spec-reviewer rounds, both REWORK; every finding applied, see the PR; a third round is due before acceptance)
- Date: 2026-11-04
- Depends on ADRs: 0002, 0003, 0005
- ADR needed: none for the design below. Recents and the restored session are per device in `UserDefaults`, as 0015/AC-8 does. 0012/AC-11 did the same for recent searches and 0029 is moving those into a CloudKit `RecentSearchRecord`; if recents follow, `RecentsStore` gets a SwiftData implementation and a migration as 0029/AC-11a does, under an ADR. See Open questions.
- Platforms: iOS, iPadOS, macOS, tvOS
- Builds on specs 0013 (catalogue, `RowKey`, `channel(for:)`), 0015 (tvOS launch into the last channel, `LastChannelKey`, the `shell.lastChannel` key), 0010 (Live on iPhone, iPad and Mac: chips, sidebar, inline player, nothing-selected state), 0007 (overlay groups), 0008 (channel-change event, current group, full-screen swipes), 0006 (first channel after onboarding), 0004 (source deletion), 0011 (VOD play is not a tune). Fills 0010's out-of-scope item "Session restore of the last played channel (later spec)".
- Blocked on the playback engine spec (not yet written) for an observable engine state stream; AC-2b to AC-2f, AC-12 and AC-16a to AC-16d use a fake engine until then.
- Blocked on (implementing PR): the 0001 follow-up that hashes `streamURL` out of `Channel.id` (0013 header). Until it merges, every M3U `Channel.id` embeds the stream URL (`<tvg-id>#<url>` or `m3u#<url>#<n>`, `M3UParser.channel(url:fallbackIndex:)`), which for many providers carries credentials, and 0013's edge cases forbid writing such an id to `UserDefaults`. `UserDefaultsRecentsStore` therefore refuses any `channelID` containing `://` (AC-20): no M3U channel is restored, listed in Recents, or remembered for 0015/AC-2a until then. Xtream ids (`xtream#<host>#<streamID>`) are unaffected. 0015/AC-8's key and payload are unchanged, but its behaviour for M3U channels is suspended by AC-20 and 0015's status line must say so. The core layer and this spec's core tests can be implemented before the follow-up.

## Design

Boards: `docs/design/boards/iPhone-Recents.dc.html` (iOS and any compact width): the Recents chip selected after Favorites, the list in most-recent-first order with the playing channel as row one, rows in 0010/AC-5 anatomy, no list header. Placement on the other platforms follows the boards those specs own: on `iPad.dc.html` the Recents entry is a Groups row between Favorites and All channels (36 pt, 16 pt text, count at 14 pt muted, 0.08 surface and weight 600 when selected); on `Main.dc.html` it is a group row between Favorites and All channels (64 pt, 29 pt text, count at the trailing edge, Focus token when focused, 0.12 surface and weight 600 when selected but unfocused).
Design rules that apply: DR-1, DR-2, DR-3, DR-4, DR-5, DR-6, DR-7, DR-8, DR-11, DR-12, DR-13. Deviations: none beyond those 0007 and 0010 already declare for their rows.
Identifiers (DR-11): `recents.chip`, `recents.group` and `recents.overlayGroup` are the only identifiers on those elements, named in the board's comments. They occupy an index slot, so `browse.chip.<index>`, `browse.group.<index>` and `overlay.group.<index>` of All channels and every later group shift by one while Recents exists; 0007 and 0010 UI tests run with an empty recents suite. Rows and headers keep the host screen's identifiers (`browse.row.<rowKey>`, `browse.listHeader`, `overlay.channel.<rowKey>`, `overlay.channelsHeader`).
Not drawn, to be added before the implementing PR: the iPad and Mac sidebar row (`recents.group`: the Favorites row of `iPad.dc.html` with a clock glyph, 14 by 14 pt, in place of the star, label "Recents", count trailing); the overlay group row (`recents.overlayGroup`: the Favorites row of `Main.dc.html` with a 26 by 26 pt clock glyph in place of the star, label "Recents", count trailing); the iPad list header for Recents (`browse.listHeader` reading "Recents" and "<n> channels" in the 0010/AC-4 style); the overlay header for Recents (`overlay.channelsHeader` reading "Recents" and "Most recent first" in the 0007/AC-4 style); `browse.loading` with the restored channel already playing (`iPhone-Loading.dc.html` and `iPad-Loading.dc.html` with the player showing video and 0010/AC-10a's controls instead of the nothing-selected player, AC-12). No empty state exists: the group is absent when it has nothing to show (AC-7).

### Interface

Names are binding; signatures show intent and may gain labels or `Sendable` constraints in the implementing PR.

```swift
// AntennaCore
public struct LastChannelKey: Hashable, Sendable, Codable { let sourceID: UUID; let channelID: String }
public struct RecentChannel: Hashable, Sendable, Codable { let key: LastChannelKey; let lastWatchedAt: Date }
public struct RecentsList: Equatable, Sendable, Codable {
    init(limit: Int = 20, entries: [RecentChannel] = [])
    var entries: [RecentChannel]                          // newest first
    func recording(_ key: LastChannelKey, at date: Date) -> RecentsList
    func removing(sourceID: UUID) -> RecentsList
}
public enum BrowseSection: String, Sendable, Codable { case live, guide, movies, series, search, settings }
public struct SessionState: Equatable, Sendable, Codable { var section: BrowseSection; var group: CatalogueGroup? }
public protocol RecentsStore: Sendable {
    func recents() -> RecentsList;              func save(_ list: RecentsList)
    func lastChannel() -> LastChannelKey?;      func save(lastChannel: LastChannelKey?)
    func session() -> SessionState?;            func save(_ session: SessionState)
    func remove(sourceID: UUID)
}
public final class UserDefaultsRecentsStore: RecentsStore { init(defaults: UserDefaults) }

// Apps/Shared
@MainActor final class SessionTracker {
    init(store: any RecentsStore, engine: any PlaybackEngine,
         engineStates: AsyncStream<PlaybackState>, clock: any Clock<Duration>)
    func tune(_ channel: Channel) async      // writes lastChannel, then load(_:), then play()
    func leaveLive()                         // VOD or episode play, source removal: cancels the dwell
    func select(section: BrowseSection)
    func select(group: CatalogueGroup?)
    func scenePhaseChanged(to phase: ScenePhase)
}
@MainActor final class SourceObserver { init(container: ModelContainer, store: any RecentsStore, tracker: SessionTracker) }
```

`tune` writes the key before calling the engine. When `load(_:)` throws, the key is kept and `play()` is not called, as 0015/AC-2b expects. A tune of the playing channel's `RowKey` (0015/AC-18, 0007/AC-9a after `.failed`) is a re-tune: it rewrites the same key and restarts the dwell. `ScenePhase.background` is "the app entering the background" on every platform, including macOS.

## Problem

On iPhone, iPad and Mac the app forgets everything at launch: the user lands on nothing selected, in All channels, and has to find the channel they were watching five minutes ago. On every platform the channels a user returns to are buried among thousands, and favorites only help once the user has curated them. TiviMate users list its recently-watched list among the things they like; its last-channel restore is the behaviour every TV has.

## Scope

In:
- The Interface types above. `LastChannelKey` is the type 0015/AC-8 names, placed here. `SessionState` carries `section` and `group` only; the last channel has one home, `RecentsStore.lastChannel()`.
- `UserDefaultsRecentsStore` as the production store. Production passes `UserDefaults.standard`; tests pass a fresh named suite. Foundation only, no SwiftData (ADR-0005).
- A `.recents` group kind in 0013's `CatalogueGroup`, built by `Catalogue` from `[RecentChannel]` and replaced without a rebuild through `replacingRecents(_:)`, present only while at least one recent resolves.
- `SessionTracker` in `Apps/Shared/`. Every live tune on every platform goes through `SessionTracker.tune(_:)`; no other code in `Apps/` calls `PlaybackEngine.load(_:)` (AC-2d). A VOD or episode play (0011/AC-3a, AC-9b) is not a tune; it calls `leaveLive()`.
- Session restore on iPhone, iPad and Mac: section, group and channel, at cold launch and after the system kills the app in the background.
- The Recents group in 0010's chips and sidebar and in 0007's overlay.
- Two full-screen swipes on tvOS: left for the previously watched channel, right for the overlay opened on Recents.
- `SourceObserver` in `Apps/Shared/Persistence/`: watches `ModelContext.didSave` and `NSPersistentStoreRemoteChange` on the app container, diffs the set of `SourceRecord.id`, and for each id that disappeared calls `RecentsStore.remove(sourceID:)`, then `SessionTracker.leaveLive()` when the playing channel's source is that id, then requests a catalogue rebuild (AC-21).
- Accessibility identifiers with prefix `recents.`.

Out (explicitly):
- Syncing recents or the session between devices (needs an ADR; Open questions).
- tvOS launch into the last channel (0015/AC-2a, AC-2b, AC-8; this spec only moves the storage behind `RecentsStore`).
- Restoring the current group on tvOS at cold launch (0008/AC-15c stands; Open questions).
- Clearing or editing recents, and a privacy toggle that stops recording (Sources and Settings spec).
- Restoring Search, Settings or a Movies detail page (AC-15 falls back; 0011 and 0012 own their screens).
- Resume position inside VOD playback (0011/AC-10a).
- Multiple windows on macOS and iPadOS: one session is stored and restored for the first window.
- Recent searches (0012/AC-11, 0029).
- Top Shelf or Siri Suggestions built from recents.
- Reloading channels when a source is added or edited (source refresh spec). `SourceObserver` reacts to removal only.

Required of other specs:
- 0013: `CatalogueGroup` gains `.recents` and `Codable`; `Catalogue.init` gains `recents: [RecentChannel]`; `Catalogue` gains `unresolvedRecents: [RecentChannel]` and `replacingRecents(_ recents: [RecentChannel]) -> Catalogue`, which rebuilds only the Recents group, leaves every other group, number and key unchanged (0013/AC-11b holds across the call) and runs within 0013/AC-14's bound; 0013/AC-2 and AC-17's exact group lists read "[`.favorites`, `.recents` when 0028/AC-5 resolves at least one entry, `.all`, ...]"; 0013/AC-3 adds "`.recents` is the number of resolved recents".
- 0015: `LastChannelKey` is the AntennaCore type; the shell reads and writes it through `RecentsStore` and AC-8's key and payload are unchanged; its status line records that AC-20 suspends AC-2a for M3U channels until the 0001 follow-up. The shell tunes through `SessionTracker.tune` (AC-2a, AC-2b, AC-18 of 0015). `ShellNavigator` gains `showOverlay(selecting: CatalogueGroup)` for AC-17.
- 0007: AC-3 lists Recents after Favorites when the group exists; AC-4's header reads "Recents" and "Most recent first" for it; an entry point that opens the overlay with a given group selected (the `.isSelected` trait, in place of the current group) and focus on its first row, replacing AC-2's initial focus for that call; AC-22 excludes `.recents`: a tune from the Recents column leaves the current group unchanged (0028/AC-9).
- 0008: swipe left and swipe right in full-screen playback are consumed by AC-16a to AC-17, which answers its open question "Should swiping left or right change the current group?" with no; AC-15b's list of tunes that keep the current group gains "the previous-channel swipe of 0028/AC-16a".
- 0010: AC-3 and AC-4 list Recents after Favorites when the group exists; the Scope line "Session restore of the last played channel (later spec)" names this spec; live sources start loading when the app's root appears, not when Live is first shown, so a session restored to another section has a catalogue when Live is opened (AC-11a, AC-12, AC-14); AC-16 additionally allows `browse.loading` with the restored channel playing in the player (AC-12) instead of the AC-23 state; the selected group can disappear while Live is shown (edge case below).
- 0004, or the Sources and Settings spec that supersedes its delete: the local delete saves through the app container so `SourceObserver` sees it; no direct call is needed.
- 0011: every VOD and episode play calls `SessionTracker.leaveLive()` before the engine loads the title (AC-2e).

## User flow

iPhone, iPad and Mac:
1. The user watches Sport One from the Sport group, then switches to the Guide tab, then goes to the home screen. Hours later iOS has killed the app.
2. The user opens Antenna. The Guide tab is shown. Tapping Live shows the Sport chip selected and Sport One playing inline, as it was.
3. The chips now read Favorites, Recents, All channels, Sport, …. Tapping Recents lists the channels watched for at least ten seconds, most recent first, Sport One on top.
4. Tapping a row plays it. The list keeps its order while it is on screen; the next time Recents is opened the row is on top.

Apple TV:
1. The user has watched channel A, then B, each for more than ten seconds. While B plays full screen, swiping left tunes to A and the zap bar shows; swiping left again returns to B. Channels zapped past in under ten seconds are skipped.
2. Swiping right opens the overlay with Recents selected and focus on the first row, which is the playing channel once it has been on for ten seconds.
3. In the overlay, Recents sits between Favorites and All channels with its count. Tuning from it does not change the current group, so swipe up and down afterwards still step through the group the user was in.

## Acceptance criteria

Each criterion is testable in isolation and has a stable id. Do not renumber.

### AC-1 Recording order, dedup and cap
Given a `RecentsList` with limit 20 holding keys K1 (newest) to K20 (oldest)
When `recording(K7, at: t)` runs, then `recording(K21, at: t + 1)`
Then after the first call K7 is first with `lastWatchedAt == t` regardless of `t` relative to the stored dates, the other nineteen keep their relative order and dates, and the count stays 20; after the second call K21 is first, K20 is gone and the count is 20; the function is pure and the input list is unchanged.

### AC-2a Last channel on every tune
Given a `SessionTracker` with an in-memory `RecentsStore` and a fake engine
When `tune(A)` is called
Then `lastChannel()` is A's `LastChannelKey` before the engine receives `load(_:)`, and the engine then receives `load(_:)` with A's URL once and `play()` once; when `load(_:)` throws, the key is still A and `play()` is not called.

### AC-2b Dwell before a channel counts as recent
Given a `SessionTracker` with an injected clock, a fake engine and an empty store
When channel B is tuned at t and the engine reports `.playing` at t + 3 s
Then `recents()` is empty until t + 13 s and then holds exactly B with `lastWatchedAt` t + 13 s. The dwell is ten seconds of continuous `.playing` counted from the first `.playing` after the tune.

### AC-2c A tune cancels the dwell
Given the setup of AC-2b with A tuned at t and `.playing` at t
When B is tuned at t + 4 s, `.playing` at t + 5 s, and the clock reaches t + 15 s
Then `recents()` holds exactly B; A is never recorded.

### AC-2d Every screen tunes through the tracker
Given the Apps target
When `scripts/check-specs.sh` (or a dedicated lint step) greps `Apps/` for calls to `PlaybackEngine.load(`
Then the only call site is `SessionTracker.tune`; and under `-antenna.uiTest` the fake engine's log and the `shell.lastChannel` mirror file (test plan) name the same channel after one tune per entry point: browse row, keyboard Return (0010/AC-14), overlay (0007/AC-9), zap-bar swipe up (0008/AC-9), digit entry (0008/AC-11), guide (0009), search result (0012), previous-channel swipe (AC-16a), launch restore (AC-12, 0015/AC-2a).

### AC-2e A VOD play does not complete a live dwell
Given A tuned at t and `.playing` at t
When a VOD title is played at t + 4 s (`leaveLive()`), the engine reports `.playing` at t + 5 s, and the clock reaches t + 20 s
Then `recents()` is empty.

### AC-2f Background cancels and a later play restarts the dwell
Given B tuned at t and `.playing` at t + 1 s
When `scenePhaseChanged(to: .background)` at t + 6 s, then `.active` and `.playing` at t + 8 s, and the clock reaches t + 17 s
Then `recents()` is empty until t + 18 s and then holds B with `lastWatchedAt` t + 18 s; the same holds when the engine reports `.loading` at t + 6 s and `.playing` at t + 8 s instead of the scene-phase change.

### AC-3 Store round trip
Given a `UserDefaultsRecentsStore` over a fresh named suite
When a `RecentsList`, a `LastChannelKey` and a `SessionState` are saved and a second store is opened over the same suite
Then the second store returns equal values; the suite holds `Data` under `recents.list` and `recents.session` and, under `shell.lastChannel`, `Data` decoding to the `LastChannelKey` exactly as 0015/AC-8 asserts; `persistentDomain(forName:)` of the suite holds exactly these three keys.

### AC-4 Removing a source
Given a store with recents from sources S and T, `lastChannel()` in S, and a session whose group is any `CatalogueGroup` carrying S (`.named(S, "Sport")` or `.ungrouped(S)`) and section `.live`
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

Only AC-10's route writes `SessionState.group`: a group the user selects. A group selected by the app (initial All channels, the AC-11b, AC-11c and AC-11e fallbacks, 0012/AC-6c's switch to All channels, the edge case where the selected group disappears) is shown but not written.

### AC-10 Session written on every change
Given any section is shown on iPhone, iPad or Mac, with an in-memory store
When `select(section:)` or `select(group:)` is called
Then before the call returns the store's `SessionState` holds that `section` (`.live`, `.guide`, `.movies`, `.series`, `.search`, `.settings`) and that `group`.

### AC-11a Launch restores section and group
Given a saved session with section `.movies` and group `.named(S, "Sport")`, and S loaded before Live is first shown
When the app cold launches
Then Movies is the shown section; when the user opens Live the Sport group is selected (chip or sidebar row with the selected state) and `browse.filter` is empty.

### AC-11b Group fallbacks
Given a saved group that is nil, or `.named(S, "Kids")` with S loaded without "Kids", or `.recents` with nothing resolving
When Live is first shown
Then All channels is selected and `session()?.group` is unchanged.

### AC-11c Group whose source is still loading
Given a saved group `.named(S, "Sport")` and S not yet in a terminal state (0010/AC-16)
When Live is first shown
Then All channels is selected and `session()?.group` is still `.named(S, "Sport")`.

### AC-11d Movies or Series with no Xtream source
Given a saved section `.movies` or `.series` and no Xtream source (0011/AC-1)
When the app cold launches
Then Live is shown.

### AC-11e Group arrives after launch
Given AC-11c and no group selected by the user since launch
When S finishes loading with "Sport"
Then Sport becomes selected; when S finishes without it, All channels stays selected.

### AC-11f User selection wins
Given AC-11c and the user has selected News
When S finishes loading with "Sport"
Then News stays selected.

### AC-11g Series at compact width
Given a saved section `.series` and an Xtream source
When the app cold launches at compact width
Then Movies is shown with `movies.kind` on Series.

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
When the process is terminated without `applicationWillTerminate` running (`XCUIApplication.terminate()`) and launched again with the same suite and no seed
Then AC-11a shows Guide, and Live then shows Sport selected and Sport One playing per AC-12.

### AC-15 Sections that are not restored
Given a saved session with section `.search` or `.settings`
When the app cold launches
Then Live is shown and the saved group and channel restore per AC-11a and AC-12.

### AC-16a Swipe left returns to the previous channel (tvOS)
Given full-screen playback of B, bar visible or hidden, with no overlay, pill or guide visible, and recents [B, A] both resolving
When the user swipes left
Then `load(_:)` is called once with A's URL, A being the first resolving recent other than the playing channel, and `zapBar.name` shows A (0008/AC-1). Channels zapped past in under ten seconds are not in recents and are skipped.

### AC-16b Swipe left toggles
Given AC-16a has tuned A
When the user swipes left again, before or after A's dwell has passed
Then `load(_:)` is called once with B's URL.

### AC-16c Nothing to return to
Given full-screen playback with no resolving recent other than the playing channel
When the user swipes left
Then no `load(_:)` call is made and the engine state is unchanged.

### AC-16d Swipe left while loading or failed
Given AC-16a's state with the engine `.loading` for an in-flight tune (test a) or `.failed` (test b)
When the user swipes left
Then in test a the in-flight load is cancelled and `load(_:)` is called once with A's URL (0008/AC-9); in test b `load(_:)` is called once with A's URL.

### AC-17 Swipe right opens the overlay on Recents (tvOS)
Given full-screen playback, bar visible or hidden, with no overlay, pill or guide visible, and the current group G
When the user swipes right
Then the overlay is presented with `recents.overlayGroup` carrying the `.isSelected` trait and G's row not carrying it, focus on the first Recents row, and the engine state unchanged (0007/AC-1); the current group is still G (AC-9). When `.recents` is absent (AC-7) the overlay opens as 0007/AC-2 describes.

### AC-18a Malformed stored data
Given the suite holds bytes under `recents.list`, `recents.session` and `shell.lastChannel` that do not decode
When a `UserDefaultsRecentsStore` is opened
Then `recents()` is empty, `session()` is nil and `lastChannel()` is nil without throwing; the next save replaces the bytes and AC-3 holds.

### AC-18b Unknown section
Given the suite holds a valid `SessionState` whose `section` raw value is unknown and whose group is `.favorites`
When `session()` is read
Then it returns section `.live` and group `.favorites`.

### AC-19 First launch with an empty store
Given no `SourceRecord` and an empty suite
When onboarding completes and 0006/AC-15 plays the first channel
Then `lastChannel()` is that channel, the session's section is `.live` and its group is nil; the next launch follows AC-11b and AC-12.

### AC-20 Credential-bearing ids are refused
Given a `UserDefaultsRecentsStore` and a key whose `channelID` contains `://`
When `save(lastChannel:)` or a `RecentsList` containing it is saved
Then that key is not written (`lastChannel()` stays as before; the list is saved without that entry) and no error is thrown. Superseded when the 0001 follow-up in the header merges; the implementing PR of that follow-up removes the filter and this criterion moves to Dropped.

### AC-21 Source deletion reaches the store
Given an in-memory `ModelContainer` with sources S and T, a recording `RecentsStore` with entries for both, a `SessionTracker` whose playing channel is in S, and a `SourceObserver` on the container
When S's `SourceRecord` is deleted and saved through the main context (test a), or through a second `ModelContext` on the same container as a sync would (test b)
Then the store records `remove(sourceID: S)` once, the tracker's dwell is cancelled, and the catalogue rebuild is requested after the removal; T's entries are untouched.

## Dropped

- AC-2 split into AC-2a to AC-2f: the dwell rule contradicted the edge-case list for buffering streams, the last-channel write had no single seam a test could hit, the per-screen claim was not observable from a UI test and is now a lint plus a mirror file, a VOD play could complete a live dwell, and background cancellation had no test.
- AC-8 split into AC-8a and AC-8b: freezing and refreshing fail for different reasons on different platforms.
- AC-11 split into AC-11a to AC-11g: three Givens, no nil-group case, no rule for a section 0011/AC-1 has removed, and a When that did not match its Then for a source still loading.
- AC-13 split into AC-13a and AC-13b: fallback and pending restore are separate tests.
- AC-16 split into AC-16a to AC-16d: first swipe, toggle, nothing to return to, and the in-flight and failed cases.
- AC-18 split into AC-18a and AC-18b: undecodable bytes and an unknown raw value.
- AC-10's clause "no field is written only on termination or on entering the background" was an untestable universal; "before the call returns" carries it. Its `lastChannel` field moved out of `SessionState` so the last channel has one home.
- AC-17's "0.12 surface" and AC-20's "nothing derived from the key is logged": a colour and a universal, left to the impl-reviewer and the edge cases.

## Edge cases and failure modes

- Offline at launch: every source fails (0010/AC-20), the restore stays pending (AC-13b), Retry after reconnecting completes it.
- Slow or huge source: the restored channel and group wait for their source (AC-11e, AC-13b). Resolving 20 recents against 50 000 channels is two dictionary lookups per entry and is covered by 0013/AC-14's bound; `replacingRecents(_:)` runs on every completed dwell, so it must not rebuild the catalogue.
- Credential not yet synced: the key's source contributes no channels and is neither loaded nor failed (0010/AC-18), so the restore stays pending and the nothing-selected state shows with 0010/AC-24's row. When the credential arrives and the source loads, AC-12 applies.
- Source deleted on another device: the `SourceRecord` disappears from the synced container; `SourceObserver` handles that path and the local delete alike (AC-21).
- The selected group disappears while Live is shown (AC-4 after a sync delete, or a refresh that leaves every recent unresolved): All channels is selected but not written, the list re-renders, and the playing channel is unchanged (iPhone, iPad, Mac; tvOS per 0007's edge case on removed rows).
- Channel id changed by a provider refresh: the entry stops resolving and is not listed (AC-5); it stays in the store and ages out through AC-1's cap.
- Two channels with the same `id` in one source (0013/AC-11a): the entry does not resolve.
- Every M3U `channelID` embeds the stream URL until the 0001 follow-up lands, so M3U channels are neither restored nor listed until then (AC-20). The store is a local suite that is never synced; keys are never logged and never put in an identifier, label or error; `RecentChannel` has no `streamURL` field (ADR-0003).
- Previous channel (AC-16a) is the most recent entry that has completed its dwell. Zap A (12 s), B (3 s), C: swipe left from C goes to A.
- The dwell timer is cancelled by a tune, by `leaveLive()`, by `ScenePhase.background`, and by the engine leaving `.playing` before the deadline; a later `.playing` for the same tune restarts it (AC-2e, AC-2f).
- tvOS: AC-16a to AC-17 are ignored while the overlay, pill or guide is visible; while 0008's bar is visible the swipe is still handled (the bar is not focusable). Reduce Motion: no slide.
- VoiceOver: `recents.group` and `recents.overlayGroup` read "Recents, n channels"; `recents.chip` reads "Recents" as the other chips do; channel rows read as 0010 and 0007 define.
- Entitlement lapse (ADR-0006): the store is untouched and restores after the entitlement returns.

## Test plan

`RecentsList`, the store, the catalogue group and `SessionState` coding are swift-testing tests in AntennaCore over `UserDefaults(suiteName:)` with a fresh name per test. `SessionTracker` and `SourceObserver` live in Apps/Shared, so their integration tests run in the Antenna and AntennaTV test bundles under `xcodebuild test`, not `swift test`, with a fake engine, an injected clock, an in-memory `RecentsStore` and, for AC-21, an in-memory `ModelContainer`. UI tests launch with `-antenna.uiTest -antenna.recentsSuite <name>`; the app opens `UserDefaults(suiteName:)` with that name and, when `-antenna.seedRecents <base64 JSON>` is present, writes the seed into it once before the root appears. The app also mirrors every `shell.lastChannel` write to a file beside the fake engine's `load(_:)` log in the test's temp directory, because XCUITest cannot read the app's suite. The fixture catalogue uses hashed ids; nothing derived from `streamURL` appears in any accessibility attribute or file name (ADR-0003). AC-14's second `launch()` passes the suite name without the seed. Identifiers: `recents.chip`, `recents.group`, `recents.overlayGroup`.

| Criterion | Layer | Test |
|-----------|-------|------|
| AC-1 | core | TBD |
| AC-2a | integration (SessionTracker, in-memory store, fake engine) | TBD |
| AC-2b | integration (SessionTracker, injected clock, fake engine) | TBD |
| AC-2c | integration (SessionTracker, injected clock, fake engine) | TBD |
| AC-2d | lint (grep in check-specs) + ui (iPhone, iPad, macOS, tvOS; mirror file) | TBD |
| AC-2e | integration (SessionTracker, injected clock, fake engine) | TBD |
| AC-2f | integration (SessionTracker, injected clock, fake engine) | TBD |
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
| AC-11b | ui (iPhone, iPad, seeded suite, mirror file) | TBD |
| AC-11c | ui (iPad, stubbed slow source, mirror file) | TBD |
| AC-11d | ui (iPhone, iPad, stubbed sources) | TBD |
| AC-11e | ui (iPad, stubbed slow source) | TBD |
| AC-11f | ui (iPad, stubbed slow source) | TBD |
| AC-11g | ui (iPhone) | TBD |
| AC-12 | ui (iPhone, macOS, seeded suite, fake engine log) | TBD |
| AC-13a | ui (iPhone, seeded suite, stubbed sources) | TBD |
| AC-13b | ui (iPad, stubbed failures, fake credential store) | TBD |
| AC-14 | ui (iPhone, macOS, terminate and relaunch) | TBD |
| AC-15 | ui (iPhone, seeded suite) | TBD |
| AC-16a | ui (tvOS, fake engine log) | TBD |
| AC-16b | ui (tvOS, fake engine log) | TBD |
| AC-16c | ui (tvOS, fake engine log) | TBD |
| AC-16d | ui (tvOS, fake engine state by launch argument) | TBD |
| AC-17 | ui (tvOS) | TBD |
| AC-18a | core | TBD |
| AC-18b | core | TBD |
| AC-19 | ui (iPhone, onboarding fixture, mirror file) | TBD |
| AC-20 | core | TBD |
| AC-21 | integration (in-memory ModelContainer, recording store, two contexts) | TBD |

## Open questions

Decisions made without an interview; each can be overturned at review.

- Recents do not sync. Reasons: two Apple TVs in one home would overwrite each other (0015's reasoning), the M3U `channelID` edge above would push credential-bearing ids through CloudKit until the 0001 follow-up lands, and the research names sync of settings and favourites, not of recents. 0029 is moving recent searches to CloudKit; overturning this means a `RecentChannelRecord`, a migration like 0029/AC-11a and an ADR.
- Cap of 20 entries and a dwell of ten seconds of continuous playback. TiviMate's list is longer; ten seconds is a guess at "watched" versus "zapped past".
- Restore plays the channel at launch on iPhone, iPad and Mac, including on cellular. The alternative is to select it and show the panel with a play control.
- Search and Settings are not restored (AC-15); Guide, Movies and Series are.
- Tuning from Recents does not make it the current group (AC-9), so swipe up and down never step through a list that reorders itself. TiviMate does the opposite.
- The Recents group is hidden when empty (AC-7) rather than shown with an empty state as Favorites is.
- The order freezes while the list is on screen (AC-8a).
- Swipe left is "previous channel" and swipe right is "overlay on Recents" (AC-16a, AC-17). Either could instead be a long press, or left could step through recents rather than toggle between two. Previous channel skips channels zapped past in under ten seconds; a dwell-independent `previousChannel` key would not, at the cost of a fourth key.
- AC-20 means no M3U channel is restored or listed, and 0015/AC-2a stops working for M3U, until the 0001 follow-up merges. The alternative is to store `SHA256(channelID)` now and resolve by hashing loaded ids, which also changes 0015/AC-8's payload.
- `SourceObserver` is defined here because no spec owns source-change observation yet; the source refresh spec may take it over.
- tvOS still forgets the current group at cold launch (0008/AC-15c). Restoring it is one more field in `SessionState` and a change to 0008.
- Clearing recents is left to the Sources and Settings spec.
