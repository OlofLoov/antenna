# 0029. Sync of watch progress, My list and recent searches

- Status: Draft
- Date: 2026-11-04
- Depends on ADRs: 0002, 0003, 0005
- Blocked on: the ADR below, Accepted; specs 0011, 0012 and 0016 merged to main; 0004/AC-6 amended to call `removeSource(_:)`. Until 0016 merges, the title-id grammar in Interface is this spec's own and binding.
- ADR needed: one ADR, "Watch activity records in the CloudKit container", covering `WatchProgressRecord` (keyed by the 0016 title id and the source id, instead of `NSUbiquitousKeyValueStore`, the 0011 open question), `ListEntryRecord` (one row per title in My list) and `RecentSearchRecord` (replacing 0012's `UserDefaults` recents, which 0012 lists as out, "needs an ADR"), and the conflict policy: wall-clock last writer wins with the AC-20 step. The criteria assume this outcome.
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
    public var fraction: Double?        // position / duration clamped to 0...1, nil without a finite duration above zero
    public var isInProgress: Bool       // inProgressFraction <= fraction < watchedFraction, compared with tolerance 1e-9
    public var isWatched: Bool          // fraction >= watchedFraction, compared with tolerance 1e-9
    public var resumePosition: TimeInterval   // position when isInProgress, else 0
    public var remaining: TimeInterval?       // max(0, duration - position) when duration is non-nil, else nil
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
    public static let maxQueryLength = 100
    public static func fold(_ query: String) -> String
    public static func resolve(_ snapshots: [Self], limit: Int = limit) -> Resolution<Self>
    public static func recording(_ query: String, into snapshots: [Self], now: Date) -> Recording?
}

public struct Resolution<Snapshot: Sendable>: Sendable { public var kept: [Snapshot]; public var toDelete: [Snapshot] }
public struct Recording: Sendable { public var upsert: RecentSearchSnapshot; public var toDelete: [RecentSearchSnapshot] }

@MainActor public protocol RecentSearchesStore: AnyObject {
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
    init(context: ModelContext, defaults: UserDefaults = .standard, now: @escaping @Sendable () -> Date = { Date.now },
         save: @escaping (ModelContext) throws -> Void = { try $0.save() })

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

Snapshot rules:
- `isValid` is true when `titleID` is non-empty and `sourceID` is non-nil (progress, list entry), or when `fold(query)` is non-empty (recent search).
- Mapping a record to a snapshot turns a negative or non-finite position into 0, and a duration that is non-finite or not above zero into nil.
- `fold` trims, collapses runs of whitespace to one space, then applies `folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)`. A stored query is trimmed, whitespace-collapsed and cut to `maxQueryLength` characters, with casing and diacritics kept.
- `recording` returns nil when the folded query is empty.

Store rules:
- `progress(titleID:sourceID:)` and `isInList` fetch with a `FetchDescriptor` predicate on `titleID` and `sourceID` and resolve over that subset. `allProgress`, `progress(inSeries:)`, `listEntries(kind:)` and `recents` fetch every record of the type.
- `recordProgress` writes `updatedAt = max(now(), survivor.updatedAt + 0.001)`, so a write on this device always beats the survivor it read, even when that survivor came from a device whose clock runs ahead.
- `recordProgress` and `toggleList` write nothing when `titleID` contains `://` or `@`. 0016 builds title ids from the host only (0016/AC-13); this guard keeps a URL with userinfo out of the records if a caller gets that wrong.
- `ActivityStore` logs nothing.
- `changes` returns a new stream on each access. Every stream yields once after each save on the container: `ModelContext.didSave` for any context on it, and `.NSPersistentStoreRemoteChange` for CloudKit imports. A stream finishes when the store is deallocated. A stream does not yield on creation. `ActivityStore` and its `init` are `@MainActor`; `AntennaApp` passes `UserDefaults` from the main actor, so the non-`Sendable` value never crosses an isolation boundary.
- `recordProgress` and `toggleList` do not check `sourceID` against the `SourceRecord`s on this device (AC-7).
- Saves go through an injected `save: (ModelContext) throws -> Void`, default `{ try $0.save() }`. When it throws, the store calls `rollback()` on the context, the call returns normally, and the next read does not include the write (AC-23). The store does not trap.
- Public AntennaCore types carry `///` docs per `docs/conventions.md`, including the `resolve` merge contract.

Every read returns the `kept` side of the matching `resolve` call over all records of that type. Reads never insert, update or delete. Every write runs `resolve` first and deletes the `toDelete` side in the same save. A snapshot whose `isValid` is false is in neither side. "Key" below means (`titleID`, `sourceID`) for progress and list entries and `fold(query)` for recents. `AntennaApp` creates one `ActivityStore` on the container's main context, calls `migrateRecents()` once after the container opens, and injects the store into 0011's and 0012's views. `changes` yields after any save on the container, this store's own or a remote import.

### Migration note

Additive: three new entities, no change to `SourceRecord` or `FavoriteRecord`, lightweight migration. ADR-0002 asks for an ADR per schema change; the ADR in the header is that one.

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
- Writing the ADR (the `adr` skill, before implementation).
- Any UI, including a "mark as watched" or "clear history" action (a later Settings or title-detail spec).
- When positions are written and which events trigger them (0011/AC-16).
- Row building, ordering and the next-episode choice (0011/AC-4, AC-9b, AC-10b).
- Search matching and the recents UI (0012).
- Progress for live TV, catch-up or timeshift (playback spec).
- Progress for M3U, Stalker, Jellyfin or Channels DVR titles (their source specs; the records accept any string id).
- Trakt or any external history service.
- Merging progress across two `SourceRecord`s that point at the same panel (open question).
- Reconciling records after a source is deleted on another device (open question; this spec keeps them).
- Clearing watch history and removing a title from Continue watching. Follow-up spec needed: records are never pruned, so until it lands the user cannot erase watch history.

Required of other specs:
- 0011: AC-3b, AC-4, AC-9b, AC-10a, AC-10b, AC-14, AC-16 and AC-17 read and write through `ActivityStore` and the snapshot types rather than the records directly. 0011/AC-16's merge rule is AC-3a here; 0011's `2% ≤ p < 95%` is `isInProgress` and `≥ 95%` is `isWatched` (AC-4a). The "Blocked on" line of 0011 points at the ADR named in this header.
- 0012: AC-11's "and to no SwiftData record" is replaced by "through the injected `RecentSearchesStore`, whose production implementation is `ActivityStore`". The out item "Sync of recent searches" moves here. Any `UserDefaults` recents store 0012 ships uses key `search.recents` with a `[String]` newest first, so AC-11a here can migrate it. AC-11a to AC-11c hold whether or not such a build ever existed: with no key present, migration does nothing (AC-16). 0012's 100-character truncation for matching uses `RecentSearchSnapshot.maxQueryLength`.
- 0004: AC-6's delete path calls `ActivityStore.removeSource(_:)` after deleting the Keychain item and the `SourceRecord`, as 0014 requires `GuideStore.remove(sourceID:)` there. 0004/AC-6 does not say this yet; that edit to 0004 lands before this spec is implemented.

## User flow

None directly. Observable through 0011 and 0012:
1. The user watches half a film on the iPhone and stops. Within a minute the Apple TV's Continue watching row shows the film with its progress bar, when both devices are online.
2. The user adds a series to My list on the Mac. The iPad's My list row gains it.
3. The user searches "north" on the Apple TV. The iPhone lists "north" under recent searches.
4. The user deletes an Xtream source on the iPhone. Its progress and list entries are deleted on the iPhone, and the deletions reach the other devices when they are online; recent searches stay.

## Acceptance criteria

Each criterion is testable in isolation and has a stable id. Do not renumber.

### AC-1a Record entities and properties
Given the `Schema` of `AntennaApp`'s container
When the entities for the three records are read
Then their attribute names and types, read from `Schema.Entity.attributes` with `isOptional` giving the `?`, equal this table, no more and no fewer:

| Entity | Attributes |
|--------|-----------|
| `WatchProgressRecord` | `id: UUID`, `titleID: String`, `seriesID: String?`, `sourceID: UUID?`, `position: Double`, `duration: Double?`, `updatedAt: Date` |
| `ListEntryRecord` | `id: UUID`, `titleID: String`, `sourceID: UUID?`, `addedAt: Date` |
| `RecentSearchRecord` | `id: UUID`, `query: String`, `updatedAt: Date` |

### AC-1b Records follow ADR-0002
Given the same three entities
When each attribute and relationship is inspected
Then every attribute is optional or has a default value, no attribute is unique, no entity has a relationship, and no attribute is of type `URL`. A stream URL can carry credentials (ADR-0003), so no record has a column that could hold one.

### AC-1c Records open and insert
Given a `ModelContainer` with that schema and `cloudKitDatabase: .none`, in memory
When one instance of each record type is inserted with its parameterless defaults and the context saves
Then the save does not throw and a fetch returns one record of each type.

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
When `progress(titleID:sourceID:)` runs
Then it returns the AC-3a survivor's values and the record count for the key is still three.

### AC-3c Merge applied on write
Given the three records of AC-3b
When `recordProgress` runs for that key
Then the survivor is updated in place, the two others are deleted, one record remains for the key, and the write saves once (one `ModelContext.didSave`).

### AC-4a Thresholds
Given snapshots with duration 7200 and positions 100, 144, 6839, 6840 and 7300, parameterised
When `fraction`, `isInProgress`, `isWatched`, `resumePosition` and `remaining` are read
Then each row gives:

| Position | `fraction` | `isInProgress` | `isWatched` | `resumePosition` | `remaining` |
|----------|-----------|----------------|-------------|------------------|-------------|
| 100 | 100/7200 | false | false | 0 | 7100 |
| 144 | 0.02 | true | false | 144 | 7056 |
| 6839 | 6839/7200 | true | false | 6839 | 361 |
| 6840 | 0.95 | false | true | 0 | 360 |
| 7300 | 1 | false | true | 0 | 0 |

Fractions are compared with tolerance 1e-9, so 144 and 6840 land on their thresholds however the division rounds. `isInProgress` and `isWatched` are never both true.

### AC-4b Latest write decides, not the highest position
Given a key whose stored snapshot is watched (position 7000 of 7200)
When `recordProgress` runs with position 300 at a later time
Then the stored snapshot has position 300, `updatedAt` equal to the later time, and is in progress, not watched. Rewatching a title reopens it.

### AC-4c No duration
Given snapshots with position 600 and duration nil, 0, -1 and `.infinity`, parameterised
When the same properties are read
Then each gives fraction nil, not in progress, not watched, resume 0 and remaining nil.

### AC-5a Episode records carry their series
Given `recordProgress` for `xtream#h#vod#55` with `seriesID` nil at t0, then for `xtream#h#episode#901` at t1 and `xtream#h#episode#902` at t2 with `seriesID` `xtream#h#series#7`, t0 < t1 < t2
When `progress(inSeries: "xtream#h#series#7")` runs
Then it returns the snapshots for 902 then 901, each with that `seriesID`, and not the movie.

### AC-5b All progress
Given the store of AC-5a
When `allProgress()` runs
Then it returns three snapshots, one per title id.

### AC-6 Deleting a source removes its progress and list entries
Given progress and list records for sources S1 and S2 and three recent searches
When `removeSource(S1)` runs
Then every `WatchProgressRecord` and `ListEntryRecord` with `sourceID == S1` is gone, S2's records are untouched, and the recent searches are untouched; `removeSource` for an id with no records changes nothing and does not throw.

### AC-7 Records whose source is missing are kept
Given a store with zero `SourceRecord`s and progress and list records whose `sourceID` matches no source
When `allProgress()`, `listEntries(kind:)` and a `recordProgress` for a different key run
Then the orphaned snapshots are returned unchanged and no orphaned record is deleted, so a device whose `SourceRecord`s have not synced yet keeps the user's progress; the `recordProgress` call, whose `sourceID` also matches no source, inserts its record.

### AC-8a List toggle
Given an empty store, title `xtream#h#vod#55` and source S
When `toggleList(titleID:sourceID:)` runs once, then again
Then after the first call one `ListEntryRecord` exists with that key and `addedAt` equal to the injected clock, and `isInList` is true; after the second no record for the key exists and `isInList` is false. The same holds for `xtream#h#episode#901` and `not-an-id`: `toggleList` accepts any title id that passes the AC-21 guard.

### AC-8b List duplicates from a sync race
Given two `ListEntryRecord`s for the key (`xtream#h#vod#55`, S) with `addedAt` 10:00 and 10:02
When `listEntries(kind: .vod)` runs
Then it returns one snapshot for the key, the 10:00 one (`ListEntrySnapshot.resolve` keeps the earliest `addedAt`, ties by lower `id.uuidString`, and marks the rest `toDelete`), and both records still exist.

### AC-8f Toggle after a sync race
Given the two records of AC-8b
When `toggleList` runs for the key
Then both records are deleted and `isInList` is false.

### AC-8c List kind comes from the title id
Given list entries for `xtream#h#vod#55`, `xtream#h#series#7`, `xtream#h#episode#901`, `xtream#h#55` and `not-an-id`
When `listEntries(kind: .vod)` and `listEntries(kind: .series)` run
Then the first returns only the vod entry and the second only the series entry; the episode, live and unparseable entries have `kind` nil and appear in neither.

### AC-8d List order
Given vod entries `xtream#h#vod#1`, `#2` and `#3` added at t1 < t2 < t3
When `listEntries(kind: .vod)` runs
Then it returns 3, 2, 1.

### AC-8e Entries with no kind are kept
Given the store of AC-8c
When both reads of AC-8c run and `toggleList` runs for a new vod key
Then all five original records still exist.

### AC-9a Recording a search
Given an empty store
When `record("north")` runs at t0, `record("  Nörth  news ")` at t1 and `record("NÖRTH")` at t2
Then two `RecentSearchRecord`s exist: one with query "NÖRTH" and `updatedAt == t2`, which is the "north" record updated in place with its `id` kept, and one with query "Nörth news" and `updatedAt == t1`; `recents()` returns ["NÖRTH", "Nörth news"]. The fold itself is AC-9d.

### AC-9b Cap
Given twelve distinct queries recorded in sequence
When `recents()` runs
Then it returns the ten newest, newest first, and only ten `RecentSearchRecord`s exist: each `record` call deletes every record beyond the ten newest after folding.

### AC-9c Ignored queries
Given an empty store
When `record("")`, `record("   ")` and `record` with 150 characters run
Then the first two insert nothing; the third stores the query cut to `maxQueryLength` (100) characters.

### AC-9d Fold
Given the queries below, parameterised
When `RecentSearchSnapshot.fold` runs
Then it returns the value in the second column:

| Query | `fold` |
|-------|--------|
| `"north"` | `"north"` |
| `"  Nörth  news "` | `"north news"` |
| `"NÖRTH"` | `"north"` |
| `"İstanbul"` | `"istanbul"` |
| `"Straße"` | `"strasse"` |
| `"Москва"` | `"москва"` |
| `"   "` | `""` |

### AC-10 Recents after a merge
Given fourteen `RecentSearchRecord`s arrived through sync, two of which fold to the same key
When `recents()` runs
Then it returns ten strings, newest first by `updatedAt`, the folded pair collapsed to the one with the latest `updatedAt` and its casing, and fourteen records still exist.

### AC-10b Recents write after a merge
Given the fourteen records of AC-10
When `record` runs with a new query
Then exactly ten records exist, the new query first in `recents()`.

### AC-11a Migration from UserDefaults
Given `UserDefaults` key `search.recents` holding ["dune", "north", "1917"] (newest first) and zero `RecentSearchRecord`s
When `migrateRecents()` runs with the injected clock at t
Then three records exist with queries in that order and `updatedAt` t, t minus one second, t minus two seconds, so `recents()` returns ["dune", "north", "1917"]; the key is removed; a second `migrateRecents()` inserts nothing.

### AC-11b Migration merges with synced recents
Given the key of AC-11a and nine synced `RecentSearchRecord`s: "Dune" at t minus 1 h, then "alien", "brazil", "casablanca", "heat", "jaws", "memento", "psycho" and "rocky" at t minus 2 h through t minus 9 h
When `migrateRecents()` runs with the injected clock at t
Then the migration runs `resolve` with the cap in the same save: the existing "Dune" record is updated in place (`id` kept, query "dune", `updatedAt` t), "rocky" is deleted as the eleventh record after folding, ten records remain, `recents()` returns ["dune", "north", "1917", "alien", "brazil", "casablanca", "heat", "jaws", "memento", "psycho"], and the key is removed.

### AC-11c Migration survives an interrupted run
Given the records AC-11a inserted and the key `search.recents` still present, as after a process kill between the inserts and the key removal
When `migrateRecents()` runs again
Then `recents()` still returns ["dune", "north", "1917"], exactly three records exist, and the key is removed.

### AC-12 Writes succeed offline
Given a store on a container with `cloudKitDatabase: .none`, the configuration a device offline behaves like
When `recordProgress`, `toggleList` and `record` run
Then the next read reflects each write. The three calls are neither `throws` nor `async`; the test calls them without `try` or `await`, so that part is a compile check. Writing while a CloudKit-backed device is offline, and the upload once it is back, is a device check (AC-18).

### AC-13a Another context's save is observed
Given an `ActivityStore` on a temporary on-disk container, a stream from `changes`, and a second `ModelContext` on the same container
When the second context inserts a `WatchProgressRecord` and saves
Then the stream, which did not yield before the save, yields at least once, awaited with a five-second timeout. This is the `ModelContext.didSave` path; a CloudKit import posts `.NSPersistentStoreRemoteChange` instead, which only AC-18 covers. 0011's "Continue watching updates within five seconds of the store change" edge case relies on this seam.

### AC-13b The read after a tick sees the change
Given the stream of AC-13a has yielded
When `allProgress()` runs
Then it includes the snapshot the second context inserted.

### AC-14a Records without a key are invalid
Given `WatchProgressRecord`s with `titleID` "" and with `sourceID` nil, parameterised, plus one valid record
When `allProgress()` runs
Then the snapshot for each malformed record has `isValid` false and is not returned; the valid one is returned.

### AC-14b Negative and non-finite positions read as zero
Given valid-key records with duration 7200 and position -5, `.nan` and `.infinity`, parameterised
When `allProgress()` runs
Then each snapshot has position 0 and resume 0, and is neither in progress nor watched.

### AC-14c Bad durations read as nil
Given valid-key records with position 600 and duration -1, `.nan` and `.infinity`, parameterised
When `allProgress()` runs
Then each snapshot has duration nil, `fraction` nil and resume 0.

### AC-14d Malformed records survive reads and writes
Given every record of AC-14a, AC-14b and AC-14c in one store
When `resolve` runs over their snapshots, `allProgress()` runs, and `recordProgress` runs for another key
Then `resolve` returns without trapping and no malformed record is deleted.

### AC-15 Resolve is fast
Given 5 000 progress snapshots over 4 000 keys, 2 000 list snapshots and 30 recent snapshots generated in the test
When `resolve` runs for each type
Then each completes in under 500 ms in the CI `swift test` run. A 50 ms target on a developer Mac is measured separately behind `ANTENNA_BENCHMARKS=1`, as 0016/AC-9, and does not gate CI.

### AC-16 Empty store
Given a container with no records and `UserDefaults` without `search.recents`
When `allProgress()`, `listEntries(kind:)`, `recents()`, `isInList(titleID:sourceID:)`, `progress(titleID:sourceID:)` and `migrateRecents()` run
Then the list reads return empty arrays, `isInList` is false, `progress` is nil, and no record is inserted.

### AC-17 Snapshots and records carry no credentials or URLs
Given a store fed through AC-2, AC-8a and AC-9a with a source whose credential is username `alice-7f3e`, password `s3cr3t-9b2a`
When every stored string property of every record and snapshot is read through `Mirror`
Then none contains `alice-7f3e`, `s3cr3t-9b2a`, `player_api.php`, `/movie/` or `/series/`; title ids embed the host only (0016/AC-13). The URL guard on writes is AC-21.

### AC-18 Progress follows the account
Given a title half watched on device A, an iPhone, and devices B, an Apple TV, and C, a Mac, all signed into the same iCloud account, and device D signed out of iCloud
When B is online
Then B's and C's Continue watching show it within a minute, and My list and recents match. On D the three writes succeed and the next read reflects them, with nothing synced. With A offline, a position written on A reaches B within a minute of A coming back online. After the source is deleted on A, A's deletions remove its progress and list entries on B once both are online. CloudKit cannot run in CI; manual two-device check.

### AC-19 Point reads do not load the table
Given 20 000 `WatchProgressRecord`s and 5 000 `ListEntryRecord`s over distinct keys in an on-disk store
When `progress(titleID:sourceID:)` and `isInList(titleID:sourceID:)` run for one key
Then each returns the right value in under 500 ms in the CI integration run, and under 50 ms behind `ANTENNA_BENCHMARKS=1`.

### AC-24 Whole-table read bound
Given the 20 000 `WatchProgressRecord`s of AC-19
When `allProgress()` runs
Then it returns in under 250 ms in the CI integration run.

### AC-20 A local write beats a skewed remote record
Given a `WatchProgressRecord` for a key with `updatedAt` one hour ahead of the injected clock, as synced from a device whose clock runs fast
When `recordProgress` runs for that key at the injected time
Then the record is updated in place with the new position and `updatedAt` equal to the old value plus one millisecond, and `progress(titleID:sourceID:)` returns the new position.

### AC-21 URLs are refused as title ids
Given an empty store and source S
When `recordProgress` and `toggleList` run with titleID `http://alice:pw@h/movie/1.mp4` and with `xtream#alice@h#vod#55`, parameterised
Then no record is inserted.

### AC-22 Every subscriber sees every change
Given two streams taken from `changes` on one `ActivityStore`
When `recordProgress` runs once
Then each stream yields at least once, awaited with a five-second timeout.

### AC-23 A failed save leaves no write
Given an `ActivityStore` whose injected `save` throws
When `recordProgress`, `toggleList` and `record` run
Then none traps, and `allProgress()`, `isInList` and `recents()` show none of the writes.

## Edge cases and failure modes

- Offline: every write lands in the local store; CloudKit uploads when the device is back online, with no code in this spec involved (AC-12). Not signed into iCloud: the store works locally and nothing syncs, as 0004.
- Sync lag: a title's progress can arrive before the `SourceRecord` that owns it, or after the title list has loaded. The record is kept (AC-7) and 0011 lists it once its title is in the loaded set (0011 edge case).
- Credential not yet synced: nothing here reads the Keychain. Progress and list entries for a source whose credential is missing are stored and returned; 0011/AC-13e decides what the screen shows.
- Clock skew: `updatedAt` is the writing device's wall clock. A local write always beats the survivor it read (AC-20), so the user's last action on this device wins here. Two devices writing the same title without syncing in between still resolve by wall clock, and the one whose clock runs ahead wins; see open questions.
- Two `SourceRecord`s for the same panel (same host, two sources): title ids collide (0016/AC-13) but the key includes `sourceID`, so each source keeps its own progress. Re-adding a deleted source gives a new `SourceRecord.id`, so its old progress, if any survived on another device, is orphaned (AC-7) until a cleanup spec.
- Duration unknown: a stream the engine reports no duration for is never in progress or watched and always resumes from zero (AC-4c). Its record still exists, so `updatedAt` records when it was last played.
- A movie "ends" per 0011/AC-16 with position equal to duration: watched. Credits skipped at 94%: still in progress; see open questions.
- Huge history: thousands of titles over years of use. Point reads fetch by key (AC-19); list reads resolve over every record of the type in memory on the main actor (AC-15), and 0011 filters to loaded titles. Records are never pruned by age.
- tvOS runs as the current user, so each Apple TV profile has its own container and its own progress, list and recents (ADR-0002).
- tvOS can evict `UserDefaults` under storage pressure. A missing `search.recents` key means nothing to migrate (AC-16). On macOS the sandboxed app's `.standard` suite is the one 0012 wrote, so migration reads the same suite.
- Deleting a source on another device: that device's `removeSource` deletions sync here; this device deletes nothing on its own, because a store that has not yet received its `SourceRecord`s would otherwise delete everything (AC-7).
- Records from a newer app version with fields this build does not know: SwiftData ignores them; the snapshot maps the known fields.
- A `RecentSearchRecord` with an empty `query`: excluded from `recents()`, deleted on the next `record` call (it is surplus after folding).
- `String(reflecting:)` of a snapshot shows the title id, which includes the provider host. The host is not a secret (0016/AC-8 allows it); the port, path and credentials are never present (AC-17, AC-21).

## Test plan

Core tests are swift-testing over snapshots built in the test, no fixtures needed. Integration tests build an in-memory `ModelContainer` with `cloudKitDatabase: .none` and the three records, an `ActivityStore` with an injected clock and a `UserDefaults(suiteName:)` that the test clears; AC-13a, AC-19 and AC-24 use a temporary on-disk store, seeded with one batched save rather than a save per record. No criterion here is platform-specific: every integration test runs on the macOS test host and the iOS Simulator, and tvOS and macOS are covered by AC-18's Apple TV and Mac legs.

| Criterion | Layer | Test |
|-----------|-------|------|
| AC-1a | integration (schema inspection) | TBD |
| AC-1b | integration (schema inspection) | TBD |
| AC-1c | integration | TBD |
| AC-2 | integration | TBD |
| AC-3a | core | TBD |
| AC-3b | integration | TBD |
| AC-3c | integration | TBD |
| AC-4a | core (parameterised) | TBD |
| AC-4b | integration | TBD |
| AC-4c | core (parameterised) | TBD |
| AC-5a | integration | TBD |
| AC-5b | integration | TBD |
| AC-6 | integration | TBD |
| AC-7 | integration | TBD |
| AC-8a | integration | TBD |
| AC-8b | core (resolve) + integration | TBD |
| AC-8c | core (kind) + integration | TBD |
| AC-8d | integration | TBD |
| AC-8e | integration | TBD |
| AC-8f | integration | TBD |
| AC-9a | core (fold, recording) + integration | TBD |
| AC-9b | core (resolve cap) + integration | TBD |
| AC-9c | integration | TBD |
| AC-9d | core (parameterised) | TBD |
| AC-10 | core (resolve) + integration | TBD |
| AC-10b | integration | TBD |
| AC-11a | integration (injected defaults suite) | TBD |
| AC-11b | integration | TBD |
| AC-11c | integration | TBD |
| AC-12 | integration (read after write; compile check for `try`/`await`) | TBD |
| AC-13a | integration (two contexts, temporary on-disk store) | TBD |
| AC-13b | integration | TBD |
| AC-14a | core (parameterised) + integration | TBD |
| AC-14b | core (parameterised) + integration | TBD |
| AC-14c | core (parameterised) + integration | TBD |
| AC-14d | core + integration | TBD |
| AC-15 | core (timed, CI bound) | TBD |
| AC-16 | integration | TBD |
| AC-17 | integration | TBD |
| AC-18 | device | manual two-device check |
| AC-19 | integration (timed, on-disk store) | TBD |
| AC-20 | integration | TBD |
| AC-21 | integration (parameterised) | TBD |
| AC-22 | integration | TBD |
| AC-23 | integration (throwing `save`) | TBD |
| AC-24 | integration (timed, on-disk store) | TBD |

## Open questions

Decisions made without an interview; each can be overturned at review.

- Three records rather than one generic activity record with a kind field. Three keep each schema small. One ADR covers all three, since they share a container, rules and conflict policy.
- Each record gets `id: UUID = UUID()` as `SourceRecord` does, so the merge tie-break (AC-3a, AC-8b) is deterministic across devices and the app layer maps records to snapshots by it rather than by `PersistentIdentifier`.
- The list entry's kind is parsed from the title id (AC-8c) rather than stored. A stored `kindRaw` would be needed if a later source kind uses ids that do not encode it.
- Thresholds are 2% and 95% as 0011 wrote them, with no absolute floor. A two-hour film has six minutes of credits; a title left at 94% stays in Continue watching. An alternative is "watched when fewer than n minutes remain".
- A title with no known duration never resumes (AC-4c). The alternative, resume from the stored position, resumes at the end of a title the user finished.
- Progress and list entries are deleted only on this device's own source deletion (AC-6), never because a `SourceRecord` disappeared from the synced container (AC-7). Orphans from a deletion that never synced are not cleaned up here.
- The key includes `sourceID`, matching 0011/AC-16. Matching on the title id alone (which already embeds the host) would survive deleting and re-adding a source.
- Recents sync account-wide with a cap of ten records, 0012's display count. A per-device list would avoid an Apple TV showing what was typed on an iPhone.
- `updatedAt` is wall clock. The only skew correction is AC-20's step of one millisecond past the stored value on a local write. Concurrent writes on two devices still go to the faster clock, and a device whose clock runs a year ahead keeps its records on top of other devices' list order until a local write steps past them. No bound on remote `updatedAt` is applied; a 24-hour clamp is the alternative.
- Point reads use a predicate fetch; list reads load the whole table on the main actor. AC-24 bounds `allProgress()` at 250 ms in CI; if 0011's per-tick re-read still hitches focus on tvOS, reads move to a background `ModelActor`.
- AC-21 refuses title ids containing `://` or `@` instead of trusting 0016 alone. A source kind whose ids contain `@` would need the guard changed.
- Migration key `search.recents` with `[String]` newest first, and migrated timestamps spaced one second apart from the migration time so the order survives folding and the cap. 0012 has not fixed its key; the "Required of other specs" line asks it to adopt this one.
- `changes` is a bare `AsyncStream<Void>`, a new stream per access; 0011 re-reads on each tick rather than receiving diffs.
- Clearing watch history and removing one title from Continue watching are out, with no follow-up spec id yet. History syncs to iCloud and is never pruned, so the owner may want a minimal `clearAll()` in scope here.

## Dropped

- AC-1: split into AC-1a, AC-1b and AC-1c so a failure names the rule it broke.
- AC-5: split into AC-5a and AC-5b; AC-5a gives the episodes distinct timestamps so the order is defined.
- AC-13: split into AC-13a and AC-13b.
- AC-14: split into AC-14a to AC-14d, one per kind of malformed field.
- AC-12's 100 ms bound: a wall-clock assertion that flakes in CI and said nothing about offline CloudKit.
- AC-16's "`changes` yields nothing within one second": a negative timing assertion that cannot fail reliably.
- AC-3b: its write half moved to AC-3c.
- AC-8b: its toggle half moved to AC-8f.
- AC-8c: ordering moved to AC-8d, non-deletion to AC-8e, the episode toggle to AC-8a.
- AC-10: its write half moved to AC-10b; the read keeps the id AC-10.
- AC-22's "after the store is deallocated both streams finish": ARC timing on a `@MainActor` class makes it flaky. The Interface rule stays, untested.
