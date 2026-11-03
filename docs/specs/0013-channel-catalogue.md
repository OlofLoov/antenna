# 0013. Channel catalogue: groups, numbers, initials, favorites resolution

- Status: Draft (two spec-reviewer rounds; remaining findings listed in the PR)
- Date: 2026-11-03
- Depends on ADRs: 0002, 0005
- Platforms: iOS, iPadOS, macOS, tvOS (AntennaCore, shared by every screen)
- Builds on specs 0001, 0003 (channel parsing), 0004 (source loading), 0005 (favorite records). Fills 0005's gap "resolving a favorite to a `Channel`". 0010/AC-11 and 0007/AC-11 cite AC-9 and AC-10 for favorite identity.

## Design

Boards: none, no UI. Screens that render the catalogue cite this spec: 0007, 0008, 0009, 0010, 0012, 0015.
Design rules that apply: DR-8 (initials rule is defined here).

## Problem

Every screen needs the same answers: which groups exist and in what order, what number a channel has, what to draw when a logo is missing, which favorites can be shown. Today each view would derive these on its own and disagree. One pure `Catalogue` type in AntennaCore built from the loaded channels gives every platform the same list.

## Scope

In:
- `Channel.sourceID: UUID?` and `Channel.position: Int?` set by the loader to the `SourceRecord.id` the channel came from and its 0-based index within that source's list.
- `RowKey`: a `Hashable` value of (`sourceID`, `id`, `position`) with a lookup that degrades gracefully.
- `CatalogueGroup` identified by kind: `.favorites`, `.all`, `.named(sourceID, name)`, `.ungrouped(sourceID)`. The UI supplies labels for `.favorites`, `.all` and `.ungrouped`.
- `FavoriteSnapshot` value type (`channelID`, `sourceID`, `sortOrder`, opaque `recordToken`) that the app layer maps from and to `FavoriteRecord`. The catalogue never touches SwiftData (ADR-0005).
- `Catalogue` built from `[Channel]` in source `sortOrder` plus `[FavoriteSnapshot]`: groups, numbers, sort, initials, favorites resolution, digit prefix matching, position in group, row-key lookup.

Out (explicitly):
- Loading, refreshing or caching channels (spec 0004, source refresh spec).
- Inserting or deleting `FavoriteRecord`s (app layer, driven by AC-9 and AC-10's results).
- User-defined groups, hiding, renaming, locking, reordering.
- Group merging across sources.
- Anything that renders.

## User flow

None. Consumed by screens.

## Acceptance criteria

Each criterion is testable in isolation and has a stable id. Do not renumber.

### AC-1 Source tagging and position
Given channels loaded from a source with id S
When the loader returns them
Then every channel has `sourceID == S` and `position` equal to its 0-based index in that source's list (playlist order for M3U, stream list order for Xtream).

### AC-2 Group list and order
Given source A (`sortOrder` 0) with groups "Sport", "News" and two channels with `group` nil, and source B (`sortOrder` 1) with groups "Sport" and "Kids"
When the catalogue is built
Then `groups` is [`.favorites`, `.all`, `.named(A, "Sport")`, `.named(A, "News")`, `.ungrouped(A)`, `.named(B, "Sport")`, `.named(B, "Kids")`]; named groups keep first-appearance order within their source, which for Xtream is the order of `get_live_categories`; an Ungrouped group follows its source's named groups and is absent when the source has no such channels; a `group` that is empty or whitespace-only counts as nil.

### AC-3 Group counts
Given the catalogue of AC-2 with 3, 4, 2, 5, 6 channels in A Sport, A News, A Ungrouped, B Sport, B Kids and two resolved favorites
When counts are read
Then `.favorites` is 2, `.all` is 20, and each group's count equals its channel count.

### AC-4 Channel numbers from the provider
Given an M3U entry with `tvg-chno="104"` and an Xtream stream with `num: 7`
When numbers are assigned
Then those channels have numbers 104 and 7.

### AC-5 Number fallback
Given channels without a provider number, two channels with provider numbers 0 and -3, across sources whose highest positive provider number is 300
When numbers are assigned
Then the 0 and -3 channels count as unnumbered and all unnumbered channels receive 301, 302, ... in source `sortOrder` then `position`; with no positive provider number anywhere the fallback starts at 1; the function is deterministic for identical input.

### AC-6 Sort within a group
Given channels numbered 5 (source B), 5 (source A), 3 (source A)
When a group containing all three is listed
Then the order is 3 (A), 5 (A), 5 (B): number ascending, then source `sortOrder`, then `position`.

### AC-7 Initials
Given channel names
When `initials(for:)` runs
Then for each whitespace-separated word the first letter or digit is taken, uppercased, up to four, skipping words with none: "Sport One" → "SO", "Eurosport 1" → "E1", "BBC - One" → "BO", "Arena HD" → "AH", "a b c d e" → "ABCD"; a single word yields its first four letters or digits uppercased: "news24" → "NEWS", "24/7" → "247"; an empty or symbol-only name yields "?".

### AC-8 Favorites resolve to loaded channels
Given favorites X (`sortOrder` 1), Y (`sortOrder` 0) and Z (not loaded), and two loaded channels sharing X's `channelID` from different sources
When the Favorites group is listed
Then a favorite resolves to the channel whose `id` equals `channelID` and, when the snapshot's `sourceID` is non-nil, whose `sourceID` equals it; when more than one still matches, the first in All channels order; the list is Y then X; Z is neither listed nor counted and is not deleted.

### AC-9 Favorite identity and removal
Given two snapshots with the same `channelID`, one with `sourceID` nil and one equal to the channel's source
When the Favorites group is listed and `favoritesToRemove(for: channel)` runs
Then the channel appears once, and the result contains every snapshot whose `channelID == channel.id` and whose `sourceID` is nil or equals `channel.sourceID`; the app layer deletes exactly those records.

### AC-10 Adding a favorite
Given a channel with `sourceID` S and existing favorites with highest `sortOrder` 4
When `addFavorite(channel)` runs
Then it returns a `FavoriteSnapshot` with `channelID == channel.id`, `sourceID == S`, `sortOrder == 5`; with no existing favorites `sortOrder` is 0; the app layer inserts one `FavoriteRecord` from it.

### AC-11 Row key
Given two channels with equal `id` from the same or different sources
When rows are keyed
Then each has a distinct `RowKey(sourceID, id, position)` and both are listed.

### AC-12 Digit prefix match
Given channels numbered 1, 10, 104, 1040 (source A) and 104 (source B)
When `match(digits:)` runs with "1", "10", "104", "0104", "0"
Then the results are 1, 10, 104 (A), 104 (A), and nil; the match is the lowest number whose decimal form starts with the digits after leading zeros are stripped, ties broken by source `sortOrder` then `position`; matching runs over All channels regardless of the current group.

### AC-13 Position in group
Given a group with 42 channels and a row key that is fourth in that group's listed order (AC-6, or AC-8 for `.favorites`)
When `position(of: rowKey, in: group)` runs
Then it returns (4, 42), 1-based; for a row key not in the group it returns nil.

### AC-14 Catalogue build is fast
Given 20 000 channels in 400 groups and 100 favorites
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
Then `groups` is [`.favorites`, `.all`] with counts 0 and 0, `match(digits:)` returns nil, `position(of:in:)` returns nil and `channel(for:)` returns nil.

## Edge cases and failure modes

- The catalogue is rebuilt after each source finishes loading (0004 loads sequentially). Fallback numbers may shift until every source has loaded; screens show the current value and 0010/AC-16 shows per-source progress.
- Provider numbers that collide within one source: both keep the number; AC-6 orders them by `position`.
- A number present in two sources is reachable by digit entry only for the first (AC-12); the second is reachable through the overlay or search.
- Group names are not normalised beyond the empty and whitespace rule in AC-2.
- Favorites whose source is deleted resolve to nothing (AC-8) until a cleanup spec removes them.
- Channels with an empty name: initials "?", sort by number only.
- `Channel.streamURL` is never part of a key, identifier or log line (ADR-0003).

## Test plan

All criteria are swift-testing tests over fixtures in AntennaCore except AC-1, which needs the `SourceLoader` seam from 0004's test plan.

| Criterion | Layer | Test |
|-----------|-------|------|
| AC-1 | integration (loader with stubbed session, after the 0004 seam) | TBD |
| AC-2 | core | TBD |
| AC-3 | core | TBD |
| AC-4 | core | TBD |
| AC-5 | core | TBD |
| AC-6 | core | TBD |
| AC-7 | core | TBD |
| AC-8 | core | TBD |
| AC-9 | core + integration (app layer deletes the returned snapshots' records) | TBD |
| AC-10 | core + integration (app layer inserts from the snapshot) | TBD |
| AC-11 | core | TBD |
| AC-12 | core | TBD |
| AC-13 | core | TBD |
| AC-14 | core benchmark | TBD |
| AC-15 | core | TBD |
| AC-16 | core | TBD |
| AC-17 | core | TBD |

## Open questions

- Does the catalogue hide a group whose source has a missing credential, or does that source simply contribute nothing (current assumption, per 0004/AC-10)?
- Should fallback numbers be frozen once shown during a partial load, at the cost of a second numbering pass?
