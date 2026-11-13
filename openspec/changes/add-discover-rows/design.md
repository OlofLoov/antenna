# Design

## Context

See proposal.md for why. What exists on 2026-11-13:

- Movies and Series rows: Continue watching, My list, Recently added, then a row per category (`movies-and-series-browsing/rows-in-a-predictable-order`). The banner shows the four newest. Grids open for a genre, My list, All movies and See all on Continue watching.
- Watch progress is synced per profile in `ProgressRecord` with `updatedAt`, finished titles included. Continue watching drops finished movies.
- Channel Recents is per profile and per device in `UserDefaults` (`RecentsStore`, keys `recents.list.<profile>`), never synced.
- Channels have stable row keys that hold no link (`m3u-playlists` and `channel-catalogue`).
- `add-title-metadata` adds the lookup service, `TitleName.clean`, `TitleMatch.pick` and the lookups switch.

Boards, under `openspec/specs/design-system/boards/`:
- New: `iPhone-Movies-Discover.dc.html`, `iPad-Movies-Discover.dc.html` (iPad and Mac), `TV-Movies-Discover.dc.html`: the rows below the hero with Trending, Recently watched and Recently added with See all. `iPhone-Live-New.dc.html`, `iPad-Live-New.dc.html`, `TV-Overlay-New.dc.html`: the New group in the group chips, the sidebar and the overlay.
- Follows: `iPhone-Movies-Rows`, `iPad-Movies-Rows`, `TV-Movies-Rows`, `iPhone-Movies-Grid`, `iPad-Movies-Grid`, `TV-Movies-Grid` (See all opens the existing grid), `iPhone-Recents`, `iPad`, `Main`.
- Not drawn: the Series versions, which differ only in the kind switch and the tab; the See all grid, which is the existing grid titled "Recently added".

Design-system requirements that apply: "Movies and series open content first", "Focus is the lifted white card", "One accent color", "Accessibility identifiers follow the board", "Nothing fake and nothing bundled" (Trending shows only the user's own titles and their provider posters).

## Goals / Non-Goals

**Goals:**
- Each row is useful on its own, and the ones that need no external data ship first.
- Trending never shows a title the user cannot play. App Review guideline 5.2.3 and the design system's "Nothing fake and nothing bundled" both rule out a catalogue of things to go and find elsewhere.

**Non-Goals:**
- A new tab. Syncing channel Recents. Common genres.

## Decisions

### 1. Where Recents lives: rows in the existing sections

Options considered:
- **A new Home tab** mixing Recents (channels and titles), Continue watching, Trending and New. It is what the owner's list reads like, but it changes the shell on four platforms, the launch choices, the tab order on Apple TV and the reopen rules, and it would be a screen of rows that already exist elsewhere.
- **Rows in the existing sections (chosen).** Live keeps its Recents group for channels. Movies and Series each gain Recently watched for titles. The rows built here are the parts a Home would be made of, so a Home later costs a screen, not new data.

Recently watched comes from `ProgressRecord`, so it is per profile and synced, and needs no new record type. `RecentlyWatched.list(progress:titles:kind:limit:)` in AntennaCore groups episodes by series, takes the newest `updatedAt` per title, drops titles not loaded, and caps at 20. Identifier `movies.row.recentlyWatched`.

### 2. Trending: a list fetched, matched on the device

The app asks the lookup service for `/v1/trending?kind=movie|tv&window=week`. The service fetches TMDB's `/3/trending/{movie|tv}/week` pages 1 to 5 (100 titles) with `append_to_response` for release year and the IMDb id, and caches the answer for a day at CloudFront. Every user gets the same answer, so the request says nothing about anyone and the service makes about two TMDB calls a day.

The app matches the list against its loaded catalogue with `TrendingMatch.titles(trending:catalogue:sourceOrder:)`:
1. A title whose provider gave a TMDB id matches by id.
2. Else by `TitleName.clean` folded for case and accents, plus the year when the provider name holds one (within one year). A cleaned name that occurs more than once in a source without a year to tell them apart is skipped.
3. One tile per trending entry, from the first source in the user's order. Trending order kept. At most 20; below three the row hides.

The list is kept in `Caches/discover/trending-<kind>.json` with its fetch date and used for seven days offline. The row shows provider posters only. Identifier `movies.row.trending`.

Options considered for the list:
- TMDB trending (chosen): covered by the same agreement as `add-title-metadata`.
- Trakt trending: its commercial terms could not be read, and its free limits tightened in 2025.
- Most watched across Antenna users: would need the app to report what people watch, which ends "Data Not Collected".

### 3. New for movies and series: See all on Recently added

Recently added and the New titles banner already show new movies and series. The gap is that Recently added cannot be opened. See all opens the existing grid (`movies.grid`) sorted by date added, newest first, undated last in provider order. Identifier `movies.row.recentlyAdded.seeAll`. On Apple TV, See all is a focusable tile after the last poster, as on Continue watching.

### 4. New for channels: a seen-channels memory per device

Options considered:
- Provider dates. Xtream live rows have an `added` field on some panels, M3U has nothing. Not usable across sources.
- A synced record of known channels. Thousands of keys per source in the user's iCloud for a convenience, and a new synced record type.
- A per-device memory (chosen). `Caches/discover/channels-<source id>.json` maps a 64-bit hash of each channel's row key to the date first seen. The first load of a source on a device records every channel with a date of `distantPast`. Each later load adds unseen keys with the load time. Entries for keys gone for 30 days are pruned. Row keys hold no link (`m3u-playlists`), and hashing keeps even the key out of the file. Losing the file counts as a first load, so the worst case is an empty New group. Too large for `UserDefaults` under the rule in `openspec/config.yaml`.

`NewChannels.group(catalogue:seen:now:)` in AntennaCore builds the group: channels first seen in the last seven days, newest first, then in catalogue order. The group joins `Catalogue`'s special groups after Recents (`channel-catalogue/recents-replaced-without-rebuild` is the model: replaced without rebuilding). Identifiers: `groups.new` on iPhone, iPad and Mac, `overlay.group.new` on Apple TV.

### 5. Order of the rows

Continue watching, My list, Trending, Recently watched, Recently added, categories. What the user is in the middle of comes first, then what they chose to save, then what is popular, then their history, then the provider's order.

## Risks / Trade-offs

- Name matching for Trending will miss titles whose provider names are far from TMDB's (other languages). Missing is acceptable; a wrong match is not, so ambiguous names are skipped.
- A provider that rebuilds its channel ids makes every channel new. The group then shows many channels for a week; still better than a wrong empty state. The renamed-channel requirement holds only while ids are stable.

## Migration Plan

Additive. New cache files only.

## Open Questions

Open questions for the owner, each with a recommendation:

1. **A Home tab?** Recommend not in this change. Ship the rows, see which ones people use, then decide whether a Home that gathers them earns a tab on Apple TV, where the tab bar is already Live, Guide, Movies, Series, Search.
2. **Sync channel Recents between devices?** Recommend no: what someone flicks through on the living-room TV is not what they want on the phone on a train, and it adds a synced record type.
3. **Seven days for New channels?** Recommend seven, matching the weekly Trending window.
4. **Trending window: day or week?** Recommend week; a daily list jumps around and matches fewer titles in a provider's catalogue.
