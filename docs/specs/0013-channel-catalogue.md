# 0013. Channel catalogue: groups, numbers, initials, favorites resolution

- Status: Draft (two spec-reviewer rounds applied; see the PR's Review state)
- Date: 2026-11-03
- Depends on ADRs: 0002, 0003, 0005
- Platforms: iOS, iPadOS, macOS, tvOS (AntennaCore, shared by every screen)
- Builds on specs 0001, 0003 (channel parsing), 0004 (source loading), 0005 (favorite records). Fills 0005's gap "resolving a favorite to a `Channel`". Specs 0007 to 0015 are in open PRs, not yet in this tree; 0010/AC-11 and 0007/AC-11 cite AC-9 and AC-10 for favorite identity.

## Design

Boards: none, no UI. Screens that render the catalogue cite this spec: 0007, 0008, 0009, 0010, 0012, 0015 (in open PRs).
Design rules that apply: DR-8 (initials rule is defined here).

### Interface

Every criterion below reads its result through one of these. Names are binding; signatures show intent and may gain labels or `Sendable` constraints in the implementing PR.

```swift
struct Catalogue<Token: Hashable & Sendable> {
    init(channels: [Channel], groupOrder: [UUID: [String]], favorites: [FavoriteSnapshot<Token>])
    static func tag(_ channels: [Channel], sourceID: UUID) -> [Channel]

    var groups: [CatalogueGroup]
    func count(of group: CatalogueGroup) -> Int
    func rows(in group: CatalogueGroup) -> [RowKey]
    func channel(for key: RowKey) -> Channel?
    func number(for key: RowKey) -> Int
    func sourceGroup(of channel: Channel) -> CatalogueGroup
    func position(of key: RowKey, in group: CatalogueGroup) -> (Int, Int)?
    func match(digits: String) -> RowKey?

    func isFavorite(_ channel: Channel) -> Bool
    func favoritesToRemove(for channel: Channel) -> [FavoriteSnapshot<Token>]
    func addFavorite(_ channel: Channel) -> FavoriteSnapshot<Token>?
    var unresolvedFavorites: [FavoriteSnapshot<Token>]
}
static func initials(for name: String) -> String
```

`groupOrder` maps a source id to its group names in provider order (`get_live_categories` for Xtream); a source with no entry uses first appearance. "All channels order" means `rows(in: .all)`.

## Problem

Every screen needs the same answers: which groups exist and in what order, what number a channel has, what to draw when a logo is missing, which favorites can be shown. Today each view would derive these on its own and disagree. One pure `Catalogue` type in AntennaCore built from the loaded channels gives every platform the same list.

## Scope

In:
- `Channel.sourceID: UUID?` and `Channel.position: Int?`, set by `Catalogue.tag(_:sourceID:)`, which the loader calls on each source's list with that `SourceRecord.id`. `position` is the 0-based index within the source's list. `M3UParser`'s `fallbackIndex` is 1-based and is not reused for it.
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

## User flow

None. Consumed by screens.

## Acceptance criteria

Each criterion is testable in isolation and has a stable id. Do not renumber.

### AC-1 Source tagging and position
Given a `[Channel]` parsed from a source with id S
When `Catalogue.tag(_:sourceID: S)` runs
Then every returned channel has `sourceID == S` and `position` equal to its 0-based index in the input (playlist order for M3U, stream list order for Xtream), and nothing else changes.

### AC-2 Group list and order
Given source A (first in input) with groups "Sport", "News" and two channels with `group` nil, source B (second) with channels in groups "Kids" then "Sport", and `groupOrder[B] == ["Sport", "Kids", "Radio"]`
When the catalogue is built
Then `groups` is [`.favorites`, `.all`, `.named(A, "Sport")`, `.named(A, "News")`, `.ungrouped(A)`, `.named(B, "Sport")`, `.named(B, "Kids")`]; a source with a `groupOrder` entry lists its named groups in that order and omits names with no channels ("Radio"); a source without one lists them in first-appearance order; an Ungrouped group follows its source's named groups and is absent when the source has no such channels; a `group` that is empty or whitespace-only counts as nil.

### AC-3 Group counts
Given the catalogue of AC-2 with 3, 4, 2, 5, 6 channels in A Sport, A News, A Ungrouped, B Sport, B Kids and two resolved favorites
When `count(of:)` runs for each group
Then `.favorites` is 2, `.all` is 20, and each named or ungrouped group's count equals its channel count.

### AC-4 Provider numbers pass through
Given channels whose `number` is 104 and 7
When the catalogue is built
Then `number(for:)` returns 104 and 7 for their row keys unchanged.

### AC-5a Number fallback
Given channels without a `number`, channels with `number` 0, -3 and 100 000, across sources whose highest `number` within 1...99 999 is 300
When the catalogue is built
Then the 0, -3 and 100 000 channels count as unnumbered, and `number(for:)` gives every unnumbered channel 301, 302, ... in source order then `position`; the function is deterministic for identical input.

### AC-5b Number fallback base case
Given channels none of which has a `number` within 1...99 999
When the catalogue is built
Then `number(for:)` gives them 1, 2, ... in source order then `position`.

### AC-6 Sort within a group and All channels order
Given channels numbered 5 (source B), 5 (source A, `position` 9), 5 (source A, `position` 2), 3 (source A)
When `rows(in:)` runs for a group containing all four
Then the order is 3 (A), 5 (A, 2), 5 (A, 9), 5 (B): assigned number (AC-4, AC-5a) ascending, then source order, then `position`; `rows(in: .all)` lists every channel in this same order.

### AC-7 Initials
Given channel names
When `initials(for:)` runs
Then the name is split on `Character.isWhitespace`; a character counts when `isLetter || isNumber`; when exactly one word has a counting character, the result is that word's first four counting characters; otherwise it is the first counting character of each such word, up to four; the result is `uppercased()` and truncated to four characters: "Sport One" → "SO", "Eurosport 1" → "E1", "BBC - One" → "BO", "Arena HD" → "AH", "a b c d e" → "ABCD", "news24" → "NEWS", "24/7" → "247", "** HD **" → "HD"; a name with no counting character yields "?".

### AC-8 Favorites resolve to loaded channels
Given favorites X (`sortOrder` 1, `sourceID` nil), Y (`sortOrder` 0, `sourceID` A), W (`sortOrder` 2, `sourceID` B) and Z (`channelID` not loaded); channels with X's `channelID` in sources A and B, Y's in A, and W's in A only
When `rows(in: .favorites)` runs
Then a favorite resolves to the channel whose `id` equals `channelID` and, when the snapshot's `sourceID` is non-nil, whose `sourceID` equals it; when more than one matches, the first in All channels order; X resolves to the A copy, Y to its A channel, W to nothing because the B copy does not exist; the rows are Y then X; W and Z are neither listed nor counted and are the contents of `unresolvedFavorites`.

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

### AC-11 Row key and stability
Given two channels with equal `id` from the same or different sources
When rows are keyed
Then each has a distinct `RowKey(sourceID, id, position)` and both are listed; building twice from identical input yields identical `groups` and identical `RowKey`s in every group.

### AC-12 Digit prefix match
Given channels numbered 1, 10, 104, 1040 (source A) and 104 (source B)
When `match(digits:)` runs with "1", "10", "104", "0104", "0" and ""
Then it returns the row keys of 1, 10, 104 (A), 104 (A), then nil and nil; the match is the lowest assigned number whose decimal form starts with the digits after leading zeros are stripped, ties broken by source order then `position`; digits empty after stripping return nil; matching runs over All channels regardless of the current group.

### AC-13 Position in group
Given a group with 42 channels and a row key that is fourth in `rows(in:)` for that group
When `position(of: rowKey, in: group)` runs
Then it returns (4, 42), 1-based; for a row key not in the group it returns nil.

### AC-14 Catalogue build is fast
Given 50 000 channels in 400 groups and 100 favorites
When the catalogue is built
Then building groups, numbers, the All channels order, the digit index and the resolved Favorites group completes in under 200 ms in a debug `swift test` run on the reference machine named in the test; benchmark, not CI-gated, as 0001/AC-14.

### AC-15 Row-key lookup
Given a stored `RowKey` K
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
Then `count(of: .all)` is 2, no group lists the untagged channel and `channel(for:)` returns nil for any key built from it.

## Edge cases and failure modes

- The catalogue is rebuilt after each source finishes loading (0004 loads sequentially). Fallback numbers may shift until every source has loaded; screens show the current value and 0010/AC-16 shows per-source progress.
- Provider numbers that collide within one source: both keep the number; AC-6 orders them by `position`.
- A number present in two sources is reachable by digit entry only for the first (AC-12); the second is reachable through the overlay or search.
- Group names are not normalised beyond the empty and whitespace rule in AC-2.
- Favorites whose source is deleted land in `unresolvedFavorites` (AC-8) until a cleanup spec removes them. See the open question on orphaned favorites.
- Channels with an empty name: initials "?", sort by number only.
- `Channel.id` for M3U entries embeds the stream URL (spec 0001), which for many providers carries credentials, so `RowKey`, `FavoriteSnapshot` and `Channel` are never logged or put in error messages (ADR-0003). Hashing the URL out of the id is a 0001 follow-up; this spec adds no further field derived from `streamURL`.

## Test plan

All criteria are swift-testing tests over fixtures in AntennaCore.

| Criterion | Layer | Test |
|-----------|-------|------|
| AC-1 | core | TBD |
| AC-2 | core | TBD |
| AC-3 | core | TBD |
| AC-4 | core | TBD |
| AC-5a | core | TBD |
| AC-5b | core | TBD |
| AC-6 | core | TBD |
| AC-7 | core | TBD |
| AC-8 | core | TBD |
| AC-9a | core | TBD |
| AC-9b | core | TBD |
| AC-9c | core | TBD |
| AC-10 | core | TBD |
| AC-11 | core | TBD |
| AC-12 | core | TBD |
| AC-13 | core | TBD |
| AC-14 | core benchmark | TBD |
| AC-15 | core | TBD |
| AC-16 | core | TBD |
| AC-17 | core | TBD |
| AC-18 | core | TBD |

## Open questions

- Does the catalogue hide a group whose source has a missing credential, or does that source simply contribute nothing (current assumption, per 0004/AC-10)?
- Should fallback numbers be frozen once shown during a partial load, at the cost of a second numbering pass?
- Orphaned favorites: AC-10 binds a favorite to a `SourceRecord.id`, and 0004 has no source edit, so deleting and re-adding a playlist orphans every favorite. Should a snapshot whose `sourceID` matches no loaded source fall back to `channelID`-only resolution? That needs the set of known source ids passed to the catalogue.
- `Channel.id` carries the stream URL for M3U (see Edge cases). A 0001 follow-up should hash it so `FavoriteRecord.channelID` stops storing credentials in CloudKit.

## Dropped

- AC-5 is split into AC-5a and AC-5b; one fixture could not exercise both fallback bases.
- AC-9 is split into AC-9a, AC-9b and AC-9c; it had two Whens and no predicate for the favorite badge.
- AC-1's integration layer: tagging is now a core function so the test does not wait on 0004's loader seam.
