# 0013. Channel catalogue: groups, numbers, initials, favorites resolution

- Status: Implemented
- Date: 2026-11-03
- Depends on ADRs: 0002, 0003, 0005
- Blocked on: nothing; every criterion is core. Constraint on consumers (0007, 0010): no screen may insert the snapshot AC-10 returns until the 0001 follow-up that hashes `streamURL` out of `Channel.id` is merged, because `FavoriteRecord.channelID` would otherwise carry credentials for M3U sources (ADR-0003).
- Platforms: iOS, iPadOS, macOS, tvOS (AntennaCore, shared by every screen)
- Builds on specs 0001, 0003 (channel parsing), 0004 (source loading), 0005 (favorite records). Fills 0005's gap "resolving a favorite to a `Channel`". Specs 0007 to 0015 are in open PRs, not yet in this tree; 0010/AC-11 and 0007/AC-11 cite AC-9 (now AC-9a to AC-9c) and AC-10 for favorite identity.

## Design

Boards: none, no UI. Screens that render the catalogue cite this spec: 0007, 0008, 0009, 0010, 0012, 0015 (in open PRs).
Design rules that apply: DR-8 (initials; defined in `docs/design/README.md` on main, merged after this branch was cut).

### Interface

Every criterion below reads its result through one of these. Names are binding; signatures show intent and may gain labels or `Sendable` constraints in the implementing PR.

```swift
extension Channel {
    static func tagged(_ channels: [Channel], sourceID: UUID) -> [Channel]
    static func initials(for name: String) -> String
}

struct RowKey: Hashable, Sendable {
    let sourceID: UUID; let id: String; let position: Int
    init?(_ channel: Channel)   // nil when sourceID or position is nil
}

struct Catalogue<Token: Hashable & Sendable> {
    init(channels: [Channel], groupOrder: [UUID: [String]], favorites: [FavoriteSnapshot<Token>])

    var groups: [CatalogueGroup]
    func count(of group: CatalogueGroup) -> Int
    func rows(in group: CatalogueGroup) -> [RowKey]
    func channel(for key: RowKey) -> Channel?
    func number(for key: RowKey) -> Int?
    func sourceGroup(of channel: Channel) -> CatalogueGroup?
    func position(of key: RowKey, in group: CatalogueGroup) -> (Int, Int)?
    func match(digits: String) -> RowKey?

    func isFavorite(_ channel: Channel) -> Bool
    func favoritesToRemove(for channel: Channel) -> [FavoriteSnapshot<Token>]
    func addFavorite(_ channel: Channel) -> FavoriteSnapshot<Token>?
    var unresolvedFavorites: [FavoriteSnapshot<Token>]
    func replacingFavorites(_ favorites: [FavoriteSnapshot<Token>]) -> Catalogue
}
```

`tagged` and `initials` do not depend on `Token`, so they live on `Channel` rather than on the generic type. `groupOrder` maps a source id to its group names in provider order (`get_live_categories` for Xtream); a source with no entry uses first appearance. "All channels order" means `rows(in: .all)`.

## Problem

Every screen needs the same answers: which groups exist and in what order, what number a channel has, what to draw when a logo is missing, which favorites can be shown. Today each view would derive these on its own and disagree. One pure `Catalogue` type in AntennaCore built from the loaded channels gives every platform the same list.

## Scope

In:
- `Channel.sourceID: UUID?` and `Channel.position: Int?`, set by `Channel.tagged(_:sourceID:)`, which the loader calls on each source's list with that `SourceRecord.id`. `position` is the 0-based index within the source's list. `M3UParser`'s `fallbackIndex` is 1-based and is not reused for it.
- Source order is the order of first appearance of `sourceID` in the input array. The caller concatenates per-source lists in `SourceRecord.sortOrder`. A channel with `sourceID == nil` is dropped from the catalogue (AC-18).
- `RowKey`: a `Hashable` value of (`sourceID`, `id`, `position`) with a lookup that degrades gracefully.
- `CatalogueGroup` identified by kind: `.favorites`, `.all`, `.named(sourceID, name)`, `.ungrouped(sourceID)`. The UI supplies labels for `.favorites`, `.all` and `.ungrouped`.
- `FavoriteSnapshot<Token: Hashable & Sendable>` value type (`channelID`, `sourceID`, `sortOrder`, `recordToken: Token?`) that the app layer maps from and to `FavoriteRecord`, instantiating `Token` as `PersistentIdentifier`. Tests use `Int`. The catalogue never touches SwiftData (ADR-0005).
- `Catalogue` built from `[Channel]`, per-source group order and `[FavoriteSnapshot]`: groups, numbers, sort, initials, favorites resolution, digit prefix matching, position in group, row-key lookup.

Out (explicitly):
- Loading, refreshing or caching channels (spec 0004, source refresh spec).
- Inserting or deleting `FavoriteRecord`s. The app layer inserts the snapshot AC-10 returns and deletes the records AC-9b returns; the screen spec that owns the toggle says when.
- User-defined groups, hiding, renaming, locking, reordering.
- Group merging across sources.
- Anything that renders.

Required of other specs: the source-refresh spec (or a 0004 revision) must call `tagged`, pass each source's category order as `groupOrder` and rebuild the catalogue after each source loads; a 0005 revision must own the `FavoriteRecord` to `FavoriteSnapshot<PersistentIdentifier>` mapping. This spec is Implemented when a PR merges with a test per criterion; that wiring is owned by those specs and does not gate this one.

## User flow

None. Consumed by screens.

## Acceptance criteria

Each criterion is testable in isolation and has a stable id. Do not renumber.

### AC-1 Source tagging and position
Given a `[Channel]` parsed from a source with id S
When `Channel.tagged(_:sourceID: S)` runs
Then every returned channel has `sourceID == S` and `position` equal to its 0-based index in the input (playlist order for M3U, stream list order for Xtream), and nothing else changes.

### AC-2 Group list and order
Given source A (first in input) with groups "Sport", "News" and two channels with `group` nil, source B (second) with channels in groups "Kids" then "Sport"; source B additionally has a channel in group "Docs" and a channel whose `group` is "  ", and `groupOrder[B] == ["Sport", " ", "Kids", "Sport", "Radio"]`
When the catalogue is built
Then `groups` is [`.favorites`, `.all`, `.named(A, "Sport")`, `.named(A, "News")`, `.ungrouped(A)`, `.named(B, "Sport")`, `.named(B, "Kids")`, `.named(B, "Docs")`, `.ungrouped(B)`]; a source with a `groupOrder` entry lists its named groups in that order and omits names with no channels ("Radio"); a source without one lists them in first-appearance order; a named group whose source has a `groupOrder` entry that does not list it follows the listed groups in first-appearance order; a name that appears twice in an entry is used once, at its first position; an entry name that is empty or whitespace-only is ignored; an Ungrouped group follows its source's named groups and is absent when the source has no such channels; a `group` that is empty or whitespace-only counts as nil.

### AC-3 Group counts
Given the catalogue of AC-2 with 3, 4, 2, 5, 6, 1, 1 channels in A Sport, A News, A Ungrouped, B Sport, B Kids, B Docs, B Ungrouped and two favorites resolving to two distinct channels
When `count(of:)` runs for each group
Then `.favorites` is 2, `.all` is 22, each named or ungrouped group's count equals its channel count, and for every group `count(of:)` equals `rows(in:).count`.

### AC-4 Provider numbers pass through
Given channels whose `number` is 104 and 7
When the catalogue is built
Then `number(for:)` returns 104 and 7 for their row keys unchanged.

### AC-5a Number fallback
Given channels without a `number`, channels with `number` 0, -3 and 100 000, across sources whose highest `number` within 1...99 999 is 300
When the catalogue is built
Then the 0, -3 and 100 000 channels count as unnumbered, and `number(for:)` gives every unnumbered channel 301, 302, ... in source order then `position`; the function is deterministic for identical input. The 1...99 999 ceiling applies to provider numbers only; fallback numbers may exceed it.

### AC-5b Number fallback base case
Given channels none of which has a `number` within 1...99 999
When the catalogue is built
Then `number(for:)` gives them 1, 2, ... in source order then `position`.

### AC-6a Sort within a group
Given source A with channels numbered 3 (`position` 0), 5 (`position` 9) and 5 (`position` 2), all in group "Sport"
When `rows(in: .named(A, "Sport"))` runs
Then the order is 3, 5 (`position` 2), 5 (`position` 9): assigned number (AC-4, AC-5a) ascending, then `position`.

### AC-6b All channels order
Given the channels of AC-6a in source A (first in input) and source B (second) with a channel numbered 5 in any group
When `rows(in: .all)` runs
Then the order is 3 (A), 5 (A, 2), 5 (A, 9), 5 (B): assigned number ascending, then source order, then `position`.

### AC-7 Initials
Given channel names
When `initials(for:)` runs
Then the name is split on `Character.isWhitespace`; a character counts when `isLetter || isNumber`; when exactly one word has a counting character, the result is that word's first four counting characters; otherwise it is the first counting character of each such word, up to four; the result is `uppercased()` and truncated to four characters: "Sport One" → "SO", "Eurosport 1" → "E1", "BBC - One" → "BO", "Arena HD" → "AH", "a b c d e" → "ABCD", "news24" → "NEWS", "24/7" → "247", "** HD **" → "HD"; a name with no counting character yields "?".

### AC-8 Favorites resolve to loaded channels
Given favorites X (`sortOrder` 1, `sourceID` nil), Y (`sortOrder` 0, `sourceID` A), W (`sortOrder` 2, `sourceID` B) and Z (`channelID` not loaded); channels with X's `channelID` in sources A and B, both without a `number` so A's copy precedes B's in All channels order, Y's in A, and W's in A only
When `rows(in: .favorites)` runs
Then a favorite resolves to the channel whose `id` equals `channelID` and, when the snapshot's `sourceID` is non-nil, whose `sourceID` equals it; when more than one matches, the first in All channels order; X resolves to the A copy, Y to its A channel, W to nothing because the B copy does not exist; rows are ordered by `sortOrder` ascending, ties broken by All channels order, so the rows are Y then X; W and Z are neither listed nor counted and are the contents of `unresolvedFavorites`, ordered by `sortOrder` then `channelID`.

### AC-9a One row per favorite channel
Given any number of snapshots that resolve to the same channel (a nil and a non-nil `sourceID`, or two identical snapshots from a sync race per ADR-0002)
When `rows(in: .favorites)` runs
Then the channel appears once, at the position of the lowest `sortOrder` among those snapshots.

### AC-9b Removal set
Given the snapshots of AC-9a and a channel C
When `favoritesToRemove(for: C)` runs
Then it returns every snapshot whose `channelID == C.id` and whose `sourceID` is nil or equals `C.sourceID`, and nothing else.

### AC-9c Favorite predicate
Given the snapshots of AC-9a
When `isFavorite(C)` runs
Then it is true exactly when `favoritesToRemove(for: C)` is non-empty.

### AC-10 Adding a favorite
Given a channel C with `sourceID` S, `isFavorite(C)` false, and snapshots (resolved or not) whose highest `sortOrder` is 4
When `addFavorite(C)` runs
Then it returns a `FavoriteSnapshot` with `channelID == C.id`, `sourceID == S`, `sortOrder == 5`, `recordToken == nil`; with no snapshots `sortOrder` is 0; when `isFavorite(C)` is true it returns nil.

### AC-11a Distinct keys for equal ids
Given two channels with equal `id` from the same or different sources
When rows are keyed
Then each has a distinct `RowKey(sourceID, id, position)` and both are listed.

### AC-11b Build is deterministic
Given any input
When the catalogue is built twice from it
Then both builds have identical `groups` and identical `RowKey`s in every group.

### AC-12 Digit prefix match
Given channels numbered 1, 10, 104, 1040 (source A) and 104 (source B)
When `match(digits:)` runs with "1", "10", "104", "0104", "0" and ""
Then it returns the row keys of 1, 10, 104 (A), 104 (A), then nil and nil; the match is the lowest assigned number whose decimal form starts with the digits after leading zeros are stripped, ties broken by source order then `position`; digits empty after stripping return nil; matching runs over All channels regardless of the current group; a string containing any non-digit character returns nil.

### AC-13 Position in group
Given a group with 42 channels and a row key that is fourth in `rows(in:)` for that group
When `position(of: rowKey, in: group)` runs
Then it returns (4, 42), 1-based; for a row key not in the group it returns nil.

### AC-14 Catalogue build is fast
Given 50 000 channels in 400 groups and 100 favorites
When the catalogue is built
Then building groups, numbers, the All channels order, the digit index and the resolved Favorites group completes in under 200 ms in a debug `swift test` run on the reference machine named in the test; benchmark, not CI-gated, as 0001/AC-14.

### AC-15 Row-key lookup
Given a `RowKey` K held by a screen
When `channel(for: K)` runs
Then the channel with exactly K is returned; failing that, if exactly one loaded channel has K's `sourceID` and `id`, that channel; otherwise nil.

### AC-16 Source group of a channel
Given a channel from source A with `group` nil, and one with `group` "Sport"
When `sourceGroup(of:)` runs
Then it returns `.ungrouped(A)` and `.named(A, "Sport")`.

### AC-17 Empty catalogue
Given zero channels and any favorites
When the catalogue is built
Then `groups` is [`.favorites`, `.all`] with counts 0 and 0, `match(digits:)` returns nil, `position(of:in:)` returns nil, `channel(for:)` returns nil and `unresolvedFavorites` holds every snapshot.

### AC-18 Untagged channels are dropped
Given three channels, one with `sourceID` nil
When the catalogue is built
Then `count(of: .all)` is 2, no group lists the untagged channel, `RowKey(untagged)` is nil and `sourceGroup(of:)` returns nil for it.

### AC-19 Favorites replaced without rebuild
Given the AC-14 catalogue and a changed snapshot list
When `replacingFavorites` runs
Then `groups` other than `.favorites` contents, `rows(in:)` for every non-favorites group and `number(for:)` for every key are identical to the original, `rows(in: .favorites)`, `isFavorite`, `favoritesToRemove` and `unresolvedFavorites` reflect the new list, and the call completes in under 20 ms on the AC-14 machine.

### AC-20 Unknown group
Given a built catalogue and a group G not in `groups` (for example `.named(S, "X")` for an unknown S)
When `count(of: G)` and `rows(in: G)` run
Then they return 0 and [].

### AC-21 Channel without a position is dropped
Given a channel with `sourceID` S and `position` nil, alongside tagged channels of S
When the catalogue is built
Then `RowKey(channel)` is nil, `count(of: .all)` counts only the tagged channels, no group lists it and `match(digits:)` never returns it.

### AC-22 Duplicate row key
Given two input channels with the same `sourceID`, `id` and `position` (for example a source's list passed twice)
When the catalogue is built
Then only the first in input order is kept: `rows(in: .all)` lists the key once, and `channel(for:)`, `number(for:)` and the source groups come from the first copy.

### AC-23 Adding an untagged channel
Given a channel with `sourceID` nil
When `addFavorite(channel)` runs
Then it returns nil, because a snapshot with a nil `sourceID` would match every copy of the channel.

### AC-24 Source group of a channel from a source not loaded
Given a built catalogue and a tagged channel whose `sourceID` is not in the input
When `sourceGroup(of:)` runs
Then it returns the group derived from the channel's own `sourceID` and `group` as in AC-16; that group is absent from `groups` and `count(of:)` returns 0 for it (AC-20).

## Edge cases and failure modes

- The catalogue is rebuilt after each source finishes loading (0004 loads sequentially). Fallback numbers may shift until every source has loaded; screens show the current value and 0010/AC-16 shows per-source progress.
- Provider numbers that collide within one source: both keep the number; AC-6a orders them by `position`.
- A number present in two sources is reachable by digit entry only for the first (AC-12); the second is reachable through the overlay or search.
- Group names are not normalised beyond the empty and whitespace rule in AC-2.
- Favorites whose source is deleted land in `unresolvedFavorites` (AC-8) until a cleanup spec removes them. See the open question on orphaned favorites.
- A snapshot with `sourceID` nil resolves to the first copy in All channels order (AC-8) but matches every copy for `isFavorite` and `favoritesToRemove` (AC-9b, AC-9c). A channel can therefore show the favorite badge while another copy occupies the Favorites row; removing from either copy removes the snapshot.
- A source whose credential is missing contributes zero channels (0004/AC-10) and therefore no groups; the catalogue has no notion of a hidden source.
- Channels with an empty name: initials "?"; sort is unaffected, since AC-6a never reads `name`.
- `Channel.id` for M3U entries embeds the stream URL (spec 0001), which for many providers carries credentials, so `RowKey`, `FavoriteSnapshot` and `Channel` are never logged or put in error messages (ADR-0003). Hashing the URL out of the id is a 0001 follow-up; this spec adds no further field derived from `streamURL`. `RowKey` is held in memory by screens for the life of the process and is never written to SwiftData, UserDefaults or `@SceneStorage` until `Channel.id` no longer embeds the URL.

## Test plan

All criteria are swift-testing tests over fixtures in AntennaCore.

| Criterion | Layer | Test |
|-----------|-------|------|
| AC-1 | core | CatalogueTests.tagging |
| AC-2 | core | CatalogueTests.groupOrder |
| AC-3 | core | CatalogueTests.groupCounts |
| AC-4 | core | CatalogueTests.providerNumbers |
| AC-5a | core | CatalogueTests.numberFallback |
| AC-5b | core | CatalogueTests.numberFallbackBase |
| AC-6a | core | CatalogueTests.sortInGroup, .sortInGroupByNumber |
| AC-6b | core | CatalogueTests.allOrder |
| AC-7 | core | CatalogueTests.initials |
| AC-8 | core | CatalogueFavoritesTests.resolution, .unresolvedOrder |
| AC-9a | core | CatalogueFavoritesTests.oneRowPerChannel |
| AC-9b | core | CatalogueFavoritesTests.removalSet |
| AC-9c | core | CatalogueFavoritesTests.favoritePredicate |
| AC-10 | core | CatalogueFavoritesTests.addFavorite |
| AC-11a | core | CatalogueTests.equalIDs |
| AC-11b | core | CatalogueTests.deterministic |
| AC-12 | core | CatalogueTests.digitMatch, .digitMatchLonger |
| AC-13 | core | CatalogueTests.positionInGroup |
| AC-14 | core benchmark | CatalogueFavoritesTests.buildBenchmark (`ANTENNA_BENCHMARKS=1`) |
| AC-15 | core | CatalogueTests.rowKeyLookup |
| AC-16 | core | CatalogueTests.sourceGroup |
| AC-17 | core | CatalogueTests.emptyCatalogue |
| AC-18 | core | CatalogueTests.untaggedDropped |
| AC-19 | core | CatalogueFavoritesTests.replaceFavorites, .replaceBenchmark (`ANTENNA_BENCHMARKS=1`) |
| AC-20 | core | CatalogueTests.unknownGroup |
| AC-21 | core | CatalogueTests.noPositionDropped |
| AC-22 | core | CatalogueTests.duplicateKey |
| AC-23 | core | CatalogueFavoritesTests.addFavoriteUntagged |
| AC-24 | core | CatalogueTests.sourceGroupUnloadedSource |

## Open questions

- Should fallback numbers be frozen once shown during a partial load, at the cost of a second numbering pass?
- Orphaned favorites: AC-10 binds a favorite to a `SourceRecord.id`, and 0004 has no source edit, so deleting and re-adding a playlist orphans every favorite. Should a snapshot whose `sourceID` matches no loaded source fall back to `channelID`-only resolution? That needs the set of known source ids passed to the catalogue.

## Dropped

- AC-5 is split into AC-5a and AC-5b; one fixture could not exercise both fallback bases.
- AC-6 is split into AC-6a and AC-6b; group order and All channels order fail for different reasons.
- AC-9 is split into AC-9a, AC-9b and AC-9c; it had two Whens and no predicate for the favorite badge.
- AC-11 is split into AC-11a and AC-11b; key distinctness and build determinism are unrelated assertions.
- AC-1's integration layer: tagging is now a core function so the test does not wait on 0004's loader seam.
