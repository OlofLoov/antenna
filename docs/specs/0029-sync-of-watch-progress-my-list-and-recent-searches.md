# 0029. Sync of watch progress, My list and recent searches

- Status: Draft
- Date: 2026-11-04
- Depends on ADRs: 0002, 0003, 0005
- ADR needed: `WatchProgressRecord` as a CloudKit-synced SwiftData model in the ADR-0002 container, keyed by the 0016 title id and the source id, instead of `NSUbiquitousKeyValueStore` (0011 open question). The criteria assume the SwiftData outcome.
- ADR needed: `ListEntryRecord` as a CloudKit-synced SwiftData model in the same container, one row per title in My list. Same assumption.
- ADR needed: `RecentSearchRecord` as a CloudKit-synced SwiftData model in the same container, replacing 0012's `UserDefaults` recents (0012 lists sync as out "needs an ADR"). Same assumption.
- Platforms: iOS, iPadOS, macOS, tvOS (AntennaCore value types, `Apps/Shared/Persistence` records and store)
- Builds on specs 0016 (title ids), 0011 (position reporting, Continue watching, My list), 0012 (recent searches), 0004 (source deletion), 0013 (the `FavoriteSnapshot` pattern: a core value type mapped from a record by the app layer).

## Design

Boards: none, no UI. Rendered by 0011 (Continue watching, My list, resume) and 0012 (recents).
Design rules that apply: none.

### Interface

Names are binding; signatures show intent and may gain labels or `Sendable` constraints in the implementing PR. Value types and pure functions live in AntennaCore (ADR-0005). Records and the store live in `Apps/Shared/Persistence`, next to `SourceRecord` and `FavoriteRecord`.

```swift
// AntennaCore
public struct WatchProgressSnapshot: Hashable, Sendable {
    public var id: UUID
    public var titleID: String          // 0016 title id: xtream#<host>#vod#<id> or xtream#<host>#episode#<id>
    public var seriesID: String?        // xtream#<host>#series#<id> for an episode, nil for a movie
    public var sourceID: UUID?
    public var position: TimeInterval
    public var duration: TimeInterval?
    public var updatedAt: Date

    public static let inProgressFraction = 0.02
    public static let watchedFraction = 0.95
    public var fraction: Double?        // position / duration clamped to 0...1, nil without a duration above zero
    public var isInProgress: Bool       // inProgressFraction <= fraction < watchedFraction
    public var isWatched: Bool          // fraction >= watchedFraction
    public var resumePosition: TimeInterval
    public var remaining: TimeInterval?
    public var isValid: Bool

    public static func resolve(_ snapshots: [Self]) -> Resolution<Self>
}

public struct ListEntrySnapshot: Hashable, Sendable {
    public var id: UUID
    public var titleID: String
    public var sourceID: UUID?
    public var addedAt: Date
    public var kind: XtreamTitleID.Kind?   // parsed from titleID; nil when it does not parse
    public var isValid: Bool

    public static func resolve(_ snapshots: [Self]) -> Resolution<Self>
}

public struct RecentSearchSnapshot: Hashable, Sendable {
    public var id: UUID
    public var query: String
    public var updatedAt: Date

    public static let limit = 10
    public static func fold(_ query: String) -> String
    public static func resolve(_ snapshots: [Self], limit: Int = limit) -> Resolution<Self>
    public static func recording(_ query: String, into snapshots: [Self], now: Date) -> Recording?
}

public struct Resolution<Snapshot> { public var kept: [Snapshot]; public var toDelete: [Snapshot] }
public struct Recording { public var upsert: RecentSearchSnapshot; public var toDelete: [RecentSearchSnapshot] }

public protocol RecentSearchesStore: AnyObject {
    func recents() -> [String]
    func record(_ query: String)
}
```

```swift
// Apps/Shared/Persistence
@Model final class WatchProgressRecord { id: UUID = UUID(), titleID: String = "", seriesID: String?, sourceID: UUID?, position: Double = 0, duration: Double?, updatedAt: Date = Date.now }
@Model final class ListEntryRecord     { id: UUID = UUID(), titleID: String = "", sourceID: UUID?, addedAt: Date = Date.now }
@Model final class RecentSearchRecord  { id: UUID = UUID(), query: String = "", updatedAt: Date = Date.now }

@MainActor final class ActivityStore: RecentSearchesStore {
    init(context: ModelContext, defaults: UserDefaults = .standard, now: @escaping @Sendable () -> Date = { Date.now })

    func progress(titleID: String, sourceID: UUID) -> WatchProgressSnapshot?
    func allProgress() -> [WatchProgressSnapshot]
    func progress(inSeries seriesID: String) -> [WatchProgressSnapshot]
    func recordProgress(titleID: String, seriesID: String?, sourceID: UUID, position: TimeInterval, duration: TimeInterval?)

    func isInList(titleID: String, sourceID: UUID) -> Bool
    func toggleList(titleID: String, sourceID: UUID)
    func listEntries(kind: XtreamTitleID.Kind) -> [ListEntrySnapshot]

    func recents() -> [String]
    func record(_ query: String)
    func migrateRecents()

    func removeSource(_ sourceID: UUID)
    var changes: AsyncStream<Void> { get }
}
```

Every read returns the `kept` side of the matching `resolve` call over all records of that type. Reads never insert, update or delete. Every write runs `resolve` first and deletes the `toDelete` side in the same save. A snapshot whose `isValid` is false is in neither side. "Key" below means (`titleID`, `sourceID`) for progress and list entries and `fold(query)` for recents. `AntennaApp` creates one `ActivityStore` on the container's main context, calls `migrateRecents()` once after the container opens, and injects the store into 0011's and 0012's views. `changes` yields after any save on the container, this store's own or a remote import.

## Problem

0011 writes a VOD position every 30 seconds and toggles My list, and 0012 keeps recent searches, but no record exists for any of them, and 0012's recents stay on the device that typed them. Someone who stops a film on the iPad expects the Apple TV to offer to resume it, and cloud sync of favourites and settings tops the TiviMate wish list (`docs/research/tivimate-user-sentiment.md`). This spec defines the three records, their merge rules, and the value types the screens read, so that 0011 and 0012 can be implemented without inventing storage.

## Scope

In:
- Three CloudKit-synced SwiftData records under ADR-0002's rules: `WatchProgressRecord`, `ListEntryRecord`, `RecentSearchRecord`, added to the `Schema` in `AntennaApp`.
- Core value types `WatchProgressSnapshot`, `ListEntrySnapshot`, `RecentSearchSnapshot` with the pure merge, threshold, fold and cap rules; the `RecentSearchesStore` protocol 0012 injects.
- `ActivityStore` in the app layer: maps records to snapshots and back, applies the merge on every write, serves 0011 and 0012.
- Keys: 0016 title ids (`xtream#<host>#vod#<id>`, `xtream#<host>#episode#<id>` with the parent `xtream#<host>#series#<id>`) plus `SourceRecord.id`. Never a URL.
- The watched and in-progress thresholds that 0011/AC-4, AC-10a and AC-10b cite.
- Deleting a source's progress and list entries when the user deletes the source on this device.
- Recent searches capped at ten after folding, synced account-wide.
- Offline writes, remote arrival, and the one-time migration of 0012's `UserDefaults` recents.

Out (explicitly):
- Writing the three ADRs (the `adr` skill, before implementation).
- Any UI, including a "mark as watched" or "clear history" action (a later Settings or title-detail spec).
- When positions are written and which events trigger them (0011/AC-16).
- Row building, ordering and the next-episode choice (0011/AC-4, AC-9b, AC-10b).
- Search matching and the recents UI (0012).
- Progress for live TV, catch-up or timeshift (playback spec).
- Progress for M3U, Stalker, Jellyfin or Channels DVR titles (their source specs; the records accept any string id).
- Trakt or any external history service.
- Merging progress across two `SourceRecord`s that point at the same panel (open question).
- Reconciling records after a source is deleted on another device (open question; this spec keeps them).

Required of other specs:
- 0011: AC-3b, AC-4, AC-9b, AC-10a, AC-10b, AC-14, AC-16 and AC-17 read and write through `ActivityStore` and the snapshot types rather than the records directly. 0011/AC-16's merge rule is AC-3a here; 0011's `2% ≤ p < 95%` is `isInProgress` and `≥ 95%` is `isWatched` (AC-4a). The "Blocked on" line of 0011 points at the three ADRs named in this header.
- 0012: AC-11's "and to no SwiftData record" is replaced by "through the injected `RecentSearchesStore`, whose production implementation is `ActivityStore`". The out item "Sync of recent searches" moves here. If 0012 ships before this spec, its `UserDefaults` store uses key `search.recents` with a `[String]` newest first so AC-11a here can migrate it; if it ships after, 0012 never writes `UserDefaults` and AC-11a is kept for builds that did.
- 0004: AC-6's delete path calls `ActivityStore.removeSource(_:)` after deleting the Keychain item and the `SourceRecord`, as 0014 requires `GuideStore.remove(sourceID:)` there.

## User flow

None directly. Observable through 0011 and 0012:
1. The user watches half a film on the iPhone and stops. Within a minute the Apple TV's Continue watching row shows the film with its progress bar, when both devices are online.
2. The user adds a series to My list on the Mac. The iPad's My list row gains it.
3. The user searches "north" on the Apple TV. The iPhone lists "north" under recent searches.
4. The user deletes an Xtream source on the iPhone. Its titles leave Continue watching and My list on every device; recent searches stay.

## Acceptance criteria

Each criterion is testable in isolation and has a stable id. Do not renumber.

### AC-1 Record shapes follow ADR-0002
Given the `Schema` of `AntennaApp`'s container
When its entities are read
Then it holds `WatchProgressRecord`, `ListEntryRecord` and `RecentSearchRecord` with exactly the stored properties listed under Interface; every attribute is optional or has a default value, no attribute is unique, no entity has a relationship, and no attribute is of type `URL`; a `ModelContainer` with that schema and `cloudKitDatabase: .none` opens in memory and each record type inserts with its parameterless defaults.

### AC-2 Progress write inserts then updates in place
Given an empty store and source S
When `recordProgress(titleID: "xtream#h#vod#55", seriesID: nil, sourceID: S, position: 600, duration: 7200)` runs at t0 and again with position 1200 at t1
Then after the first call one `WatchProgressRecord` exists with those values and `updatedAt == t0`; after the second the same record (same `id`) has position 1200, duration 7200 and `updatedAt == t1`, and the count is still one; `progress(titleID:sourceID:)` returns the matching snapshot.

### AC-3a Merge rule
Given snapshots for one key with `updatedAt` 10:00 (position 600), 10:05 (position 300) and 10:05 (position 900, `id` sorting after the 300 one), and a snapshot for another key
When `WatchProgressSnapshot.resolve` runs
Then `kept` holds the 10:05 position 900 snapshot and the other key's snapshot, and `toDelete` holds the two others: per key the latest `updatedAt` wins, ties go to the higher `position`, then to the lower `id.uuidString`; `resolve` over the same snapshots in any input order returns the same `kept` set, so two devices never keep different survivors.

### AC-3b Merge applied on write
Given three `WatchProgressRecord`s for one key, as AC-3a, arrived through sync
When `progress(titleID:sourceID:)` runs, then `recordProgress` runs for that key
Then the read returns the AC-3a survivor's values and deletes nothing; the write updates the survivor in place and deletes the two others in the same save, leaving one record for the key.

### AC-4a Thresholds
Given snapshots with duration 7200 and positions 100, 144, 6839, 6840 and 7300, and snapshots with duration nil or 0 and position 600, parameterised
When `fraction`, `isInProgress`, `isWatched`, `resumePosition` and `remaining` are read
Then position 100 gives fraction 100/7200, not in progress, not watched, resume 0, remaining 7100; 144 gives 0.02, in progress, resume 144; 6839 gives in progress, resume 6839, remaining 361; 6840 gives 0.95, watched, not in progress, resume 0, remaining 360; 7300 gives fraction 1, watched, resume 0, remaining 0; nil or 0 duration gives fraction nil, neither flag, resume 0, remaining nil. `isInProgress` and `isWatched` are never both true.

### AC-4b Latest write decides, not the highest position
Given a key whose stored snapshot is watched (position 7000 of 7200)
When `recordProgress` runs with position 300 at a later time
Then the stored snapshot has position 300 and is in progress, not watched: rewatching a title reopens it.

### AC-5 Episode records carry their series
Given `recordProgress` for `xtream#h#episode#901` and `xtream#h#episode#902` with `seriesID` `xtream#h#series#7`, and for `xtream#h#vod#55` with `seriesID` nil, the second episode written last
When `progress(inSeries: "xtream#h#series#7")` runs
Then it returns the two episode snapshots ordered by `updatedAt` descending, each with that `seriesID`, and not the movie; `allProgress()` returns all three.

### AC-6 Deleting a source removes its progress and list entries
Given progress and list records for sources S1 and S2 and three recent searches
When `removeSource(S1)` runs
Then every `WatchProgressRecord` and `ListEntryRecord` with `sourceID == S1` is gone, S2's records are untouched, and the recent searches are untouched; `removeSource` for an id with no records changes nothing and does not throw.

### AC-7 Records whose source is missing are kept
Given a store with zero `SourceRecord`s and progress and list records whose `sourceID` matches no source
When `allProgress()`, `listEntries(kind:)` and a `recordProgress` for a different key run
Then the orphaned snapshots are returned unchanged and no orphaned record is deleted: a device whose `SourceRecord`s have not synced yet must not lose the user's progress.

### AC-8a List toggle
Given an empty store, title `xtream#h#vod#55` and source S
When `toggleList(titleID:sourceID:)` runs once, then again
Then after the first call one `ListEntryRecord` exists with that key and `addedAt` equal to the injected clock, and `isInList` is true; after the second no record for the key exists and `isInList` is false.

### AC-8b List duplicates from a sync race
Given two `ListEntryRecord`s for the key (`xtream#h#vod#55`, S) with `addedAt` 10:00 and 10:02
When `listEntries(kind: .vod)` runs, then `toggleList` runs for the key
Then the read returns one snapshot for the key, the 10:00 one (`ListEntrySnapshot.resolve` keeps the earliest `addedAt`, ties by lower `id.uuidString`, and marks the rest `toDelete`); the toggle deletes both records.

### AC-8c List kind comes from the title id
Given list entries for `xtream#h#vod#55`, `xtream#h#series#7`, `xtream#h#episode#901`, `xtream#h#55` and `not-an-id`
When `listEntries(kind: .vod)` and `listEntries(kind: .series)` run
Then they return the vod entry and the series entry respectively, ordered by `addedAt` descending when several; the episode, live and unparseable entries have `kind` nil, appear in neither list, and are not deleted.

### AC-9a Recording a search
Given an empty store
When `record("north")` runs at t0, `record("  Nörth  news ")` at t1 and `record("NÖRTH")` at t2
Then two `RecentSearchRecord`s exist: one with query "NÖRTH" and `updatedAt == t2` (the "north" record updated in place, keeping its `id`, because `fold` trims, collapses whitespace and folds case and diacritics so "north" and "NÖRTH" share a key) and one with query "Nörth news" and `updatedAt == t1` (the stored query is trimmed and whitespace-collapsed, casing and diacritics kept); `recents()` returns ["NÖRTH", "Nörth news"].

### AC-9b Cap
Given twelve distinct queries recorded in sequence
When `recents()` runs
Then it returns the ten newest, newest first, and only ten `RecentSearchRecord`s exist: each `record` call deletes every record beyond the ten newest after folding.

### AC-9c Ignored queries
Given an empty store
When `record("")`, `record("   ")` and `record` with 150 characters run
Then the first two insert nothing; the third stores the query truncated to 100 characters, as 0012 truncates queries for matching.

### AC-10 Recents after a merge
Given fourteen `RecentSearchRecord`s arrived through sync, two of which fold to the same key
When `recents()` runs, then `record` runs with a new query
Then the read returns ten strings, newest first by `updatedAt`, the folded pair collapsed to the one with the latest `updatedAt` and its casing, and deletes nothing; the write leaves exactly ten records.

### AC-11a Migration from UserDefaults
Given `UserDefaults` key `search.recents` holding ["dune", "north", "1917"] (newest first) and zero `RecentSearchRecord`s
When `migrateRecents()` runs with the injected clock at t
Then three records exist with queries in that order and `updatedAt` t, t minus one second, t minus two seconds, so `recents()` returns ["dune", "north", "1917"]; the key is removed; a second `migrateRecents()` inserts nothing.

### AC-11b Migration merges with synced recents
Given the key of AC-11a and nine synced `RecentSearchRecord`s, one of them "Dune" at t minus one hour
When `migrateRecents()` runs
Then the result holds ten records after folding and the cap: "dune" from the defaults replaces "Dune" (later `updatedAt`), the oldest surplus record is deleted, and the key is removed.

### AC-11c Migration survives an interrupted run
Given the records AC-11a inserted and the key `search.recents` still present, as after a process kill between the inserts and the key removal
When `migrateRecents()` runs again
Then `recents()` still returns ["dune", "north", "1917"], exactly three records exist, and the key is removed.

### AC-12 Writes succeed offline
Given a store on a container with `cloudKitDatabase: .none`, the configuration a device offline behaves like
When `recordProgress`, `toggleList` and `record` run
Then each is a synchronous, non-throwing call, returns within 100 ms, and the next read reflects the write; `ActivityStore` has no network type in its API and never waits for or reports CloudKit state. Sync of the queued writes once online is a device check (AC-18).

### AC-13 Remote arrival is observed
Given an `ActivityStore` on a container and a second `ModelContext` on the same container
When the second context inserts a `WatchProgressRecord` and saves
Then `changes` yields within five seconds and a subsequent `allProgress()` includes the new snapshot. This is the seam 0011's "Continue watching updates within five seconds of the store change" edge case relies on.

### AC-14 Malformed records are skipped, not deleted
Given `WatchProgressRecord`s with `titleID` "" and with `sourceID` nil, one with position -5, one with `duration` -1, and one whose position and duration are `.nan` and `.infinity`, plus one valid record
When `allProgress()` runs and `recordProgress` runs for another key
Then the "" and nil-source records have `isValid` false and are excluded from reads; the position -5 snapshot reads position 0; the duration -1 and `.nan` or `.infinity` snapshots read `fraction` nil and resume 0; `resolve` never traps; none of them is deleted by the read or by the write.

### AC-15 Resolve is fast
Given 5 000 progress snapshots over 4 000 keys, 2 000 list snapshots and 30 recent snapshots generated in the test
When `resolve` runs for each type
Then each completes in under 50 ms in a debug `swift test` run on the reference machine named in the test, behind `ANTENNA_BENCHMARKS=1` as 0016/AC-9; benchmark, not CI-gated.

### AC-16 Empty store
Given a container with no records and `UserDefaults` without `search.recents`
When `allProgress()`, `listEntries(kind:)`, `recents()` and `migrateRecents()` run
Then every read returns an empty array, no record is inserted, and `changes` yields nothing within one second.

### AC-17 Snapshots and records carry no credentials or URLs
Given a store fed through AC-2, AC-8a and AC-9a with a source whose credential is username `alice-7f3e`, password `s3cr3t-9b2a`
When `String(reflecting:)` is read for every snapshot and every record
Then none contains `alice-7f3e`, `s3cr3t-9b2a`, `player_api.php`, `/movie/` or `/series/`; title ids embed the host only (0016/AC-13).

### AC-18 Progress follows the account
Given a title half watched on device A
When device B, signed into the same iCloud account, is online
Then B's Continue watching shows it within a minute, My list and recents match, and deleting the source on A removes its titles on B. CloudKit cannot run in CI; manual two-device check.

## Edge cases and failure modes

- Offline: every write lands in the local store; CloudKit uploads when the device is back online, with no code in this spec involved (AC-12). Not signed into iCloud: the store works locally and nothing syncs, as 0004.
- Sync lag: a title's progress can arrive before the `SourceRecord` that owns it, or after the title list has loaded. The record is kept (AC-7) and 0011 lists it once its title is in the loaded set (0011 edge case).
- Credential not yet synced: nothing here reads the Keychain. Progress and list entries for a source whose credential is missing are stored and returned; 0011/AC-13e decides what the screen shows.
- Clock skew: `updatedAt` is the writing device's wall clock. A device with a clock set ahead wins every merge until the other device's clock passes it. Accepted; see open questions.
- Two `SourceRecord`s for the same panel (same host, two sources): title ids collide (0016/AC-13) but the key includes `sourceID`, so each source keeps its own progress. Re-adding a deleted source gives a new `SourceRecord.id`, so its old progress, if any survived on another device, is orphaned (AC-7) until a cleanup spec.
- Duration unknown: a stream the engine reports no duration for is never in progress or watched and always resumes from zero (AC-4a). Its record still exists, so `updatedAt` records when it was last played.
- A movie "ends" per 0011/AC-16 with position equal to duration: watched. Credits skipped at 94%: still in progress; see open questions.
- Huge history: thousands of titles over years of use. Reads resolve over every record of the type in memory (AC-15); 0011 filters to loaded titles. Records are never pruned by age.
- tvOS runs as the current user, so each Apple TV profile has its own container and its own progress, list and recents (ADR-0002).
- Deleting a source on another device: that device's `removeSource` deletions sync here; this device deletes nothing on its own, because a store that has not yet received its `SourceRecord`s would otherwise delete everything (AC-7).
- Records from a newer app version with fields this build does not know: SwiftData ignores them; the snapshot maps the known fields.
- A `RecentSearchRecord` with an empty `query`: excluded from `recents()`, deleted on the next `record` call (it is surplus after folding).
- Schema migration: additive, three new models, no change to existing ones; the three ADRs carry the migration note `docs/conventions.md` asks for.
- `String(reflecting:)` of a snapshot shows the title id, which includes the provider host. The host is not a secret (0016/AC-8 allows it); the port, path and credentials are never present (AC-17).

## Test plan

Core tests are swift-testing over snapshots built in the test, no fixtures needed. Integration tests build an in-memory `ModelContainer` with `cloudKitDatabase: .none` and the three records, an `ActivityStore` with an injected clock and a `UserDefaults(suiteName:)` that the test clears; AC-13 uses a temporary on-disk store because the change notification is a store-level event.

| Criterion | Layer | Test |
|-----------|-------|------|
| AC-1 | integration (schema inspection) | TBD |
| AC-2 | integration | TBD |
| AC-3a | core | TBD |
| AC-3b | integration | TBD |
| AC-4a | core (parameterised) | TBD |
| AC-4b | integration | TBD |
| AC-5 | integration | TBD |
| AC-6 | integration | TBD |
| AC-7 | integration | TBD |
| AC-8a | integration | TBD |
| AC-8b | core (resolve) + integration | TBD |
| AC-8c | core (kind) + integration | TBD |
| AC-9a | core (fold, recording) + integration | TBD |
| AC-9b | core (resolve cap) + integration | TBD |
| AC-9c | integration | TBD |
| AC-10 | core (resolve) + integration | TBD |
| AC-11a | integration (injected defaults suite) | TBD |
| AC-11b | integration | TBD |
| AC-11c | integration | TBD |
| AC-12 | integration (no network in the store's API) + device (AC-18) | TBD |
| AC-13 | integration (two contexts, temporary on-disk store) | TBD |
| AC-14 | core (parameterised) + integration | TBD |
| AC-15 | core benchmark, `ANTENNA_BENCHMARKS=1` | TBD |
| AC-16 | integration | TBD |
| AC-17 | integration | TBD |
| AC-18 | device | manual two-device check |

## Open questions

Decisions made without an interview; each can be overturned at review.

- Three records rather than one generic activity record with a kind field. Three keep each schema small and let a future ADR change one without the others.
- Each record gets `id: UUID = UUID()` as `SourceRecord` does, so the merge tie-break (AC-3a, AC-8b) is deterministic across devices and the app layer maps records to snapshots by it rather than by `PersistentIdentifier`.
- The list entry's kind is parsed from the title id (AC-8c) rather than stored. A stored `kindRaw` would be needed if a later source kind uses ids that do not encode it.
- Thresholds are 2% and 95% as 0011 wrote them, with no absolute floor. A two-hour film has six minutes of credits; a title left at 94% stays in Continue watching. An alternative is "watched when fewer than n minutes remain".
- A title with no known duration never resumes (AC-4a). The alternative, resume from the stored position, resumes at the end of a title the user finished.
- Progress and list entries are deleted only on this device's own source deletion (AC-6), never because a `SourceRecord` disappeared from the synced container (AC-7). Orphans from a deletion that never synced are not cleaned up here.
- The key includes `sourceID`, matching 0011/AC-16. Matching on the title id alone (which already embeds the host) would survive deleting and re-adding a source.
- Recents sync account-wide with a cap of ten records, 0012's display count. A per-device list would avoid an Apple TV showing what was typed on an iPhone.
- `updatedAt` is wall clock with no skew correction.
- Migration key `search.recents` with `[String]` newest first, and migrated timestamps spaced one second apart from the migration time so the order survives folding and the cap. 0012 has not fixed its key; the "Required of other specs" line asks it to adopt this one.
- `changes` is a bare `AsyncStream<Void>`; 0011 re-reads on each tick rather than receiving diffs.
