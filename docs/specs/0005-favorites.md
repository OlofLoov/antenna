# 0005. Favorites

- Status: Implemented
- Date: 2026-11-03
- Depends on ADRs: 0002
- Platforms: iOS, iPadOS, macOS, tvOS
- Retroactive: documents behaviour shipped in commit 082034b. Written so later
  changes have a spec to revise or supersede. No UI adds a favorite yet.
  AC-1 and AC-2 gained XCUITests with the AntennaUITests target; AC-3 has core
  tests; AC-4 is a manual device check.

## Problem

Users keep a short list of channels they actually watch out of thousands. That
list must survive source reloads and follow the user to every device. Today
only the storage and an empty tab exist.

## Scope

In:
- `FavoriteRecord` with `channelID`, `sourceID`, `addedAt`, `sortOrder`, synced through CloudKit.
- Favorites tab: empty state, or a list ordered by `sortOrder`.

Out (explicitly):
- Adding or removing a favorite from any screen.
- Resolving a favorite to a `Channel` to show name, logo or play it. The list shows the raw `channelID`.
- Reordering.
- Deduplicating favorites.
- Cleaning up favorites whose source was deleted.

## User flow

1. User opens the Favorites tab.
2. With no favorites, an empty state explains that favorites sync across devices.
3. With favorites, a list of entries appears in saved order.

tvOS: rows are plain text and not focusable, so a list longer than the screen
cannot be scrolled with the remote (known gap).

## Acceptance criteria

Each criterion is testable in isolation and has a stable id. Do not renumber.

### AC-1 Empty state
Given no `FavoriteRecord`s
When the Favorites tab is shown
Then the "No favorites" view is shown.

### AC-2 List order
Given favorites with `sortOrder` 2, 0, 1
When the Favorites tab is shown
Then three rows appear in the order 0, 1, 2, each showing its `channelID`.

### AC-3 Favorites reference stable channel ids
Given a favorite whose `channelID` came from an M3U entry with a non-empty `tvg-id`, or from an Xtream stream
When the same source is reloaded with unchanged content
Then the same channel id is produced, so the favorite still refers to it.

### AC-4 Favorites sync between devices
Given a favorite saved on device A
When device B, signed into the same iCloud account, is online
Then the favorite appears in device B's Favorites tab.

## Edge cases and failure modes

- Favorites for M3U entries without `tvg-id` dangle when the playlist order changes, because those ids are positional (spec 0001 edge cases).
- Two M3U entries with the same `tvg-id` and URL share an id, so a favorite for either is ambiguous.
- Equal `sortOrder` values yield an unspecified relative order.
- Duplicate favorites for the same channel are listed twice; nothing deduplicates (ADR-0002 forbids unique attributes).
- A favorite whose source was deleted stays in the list as a bare id.
- Schema rules per ADR-0002 apply to `FavoriteRecord`.

## Test plan

UI tests find the screen by the accessibility identifiers
`favorites.emptyState` and `favorites.list`. Debug builds launched with
`-ui-testing-favorites <sortOrders>` start on an in-memory store holding one
favorite per listed sort order, channel id `channel-<n>`; an empty value
gives an empty store. Nothing reaches iCloud.

The tests run on an iPhone simulator. The view is shared by every
platform, and `AntennaUITests` targets iOS only. They open the tab by
its "Favorites" label, an exception to the identifier rule in
`docs/conventions.md`: the tab bar belongs to the shell, which this spec
does not cover, and moves to an identifier when the shell spec adds one.

| Criterion | Layer | Test |
|-----------|-------|------|
| AC-1 | ui | `FavoritesUITests.testEmptyStateWhenThereAreNoFavorites` |
| AC-2 | ui | `FavoritesUITests.testRowsFollowSortOrder` |
| AC-3 | core | `FavoriteChannelIDTests.m3uReload`, `FavoriteChannelIDTests.xtreamReload` |
| AC-4 | device | CloudKit cannot run in CI; manual two-device check |

## Open questions

- Which screens get the add/remove action: channel row context menu, player overlay, both?
- Should a favorite store a display name snapshot so it renders before its source has loaded?
- How should favorites for positional M3U ids be made durable: store the stream URL as well, or require `tvg-id`?
