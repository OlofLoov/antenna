# Design

## Context

See proposal.md for why. The sections read titles and categories through `xtream-vod-client` and store progress and My list as change `add-watch-progress-sync` decides.

Boards, under `openspec/specs/design-system/boards/`: `TV-Movies.dc.html`, `iPad-Movies.dc.html`, `iPhone-Movies.dc.html`, `TV-Movies-Rows.dc.html`, `iPad-Movies-Rows.dc.html`, `iPhone-Movies-Rows.dc.html`, `TV-Movies-Grid.dc.html`, `iPad-Movies-Grid.dc.html`, `iPhone-Movies-Grid.dc.html`. The Series section reuses the Movies boards with series data.

Not drawn: loading rows per source, empty, error, banner, alert, the poster menu, and the More info button that does nothing yet.

Design-system requirements that apply: “Focus is the lifted white card”, “One accent color”, “Text stays above the platform caption floor”, “Targets are large enough to hit”, “Movies and series open content first”, “Accessibility identifiers follow the board”, “Nothing fake and nothing bundled”, “Text meets contrast minimums”, “Loading shows real progress per step”.

On Apple TV the user picks Movies in the tab bar. The banner moves through up to four new titles while nothing in it is focused, and swiping past its buttons pages it. Below come Continue watching, My list, Recently added, a row per category and a row of genre chips. Selecting a poster plays the movie or the next unwatched episode; a long press opens the poster's menu.

On iPad and Mac, Movies in the sidebar shows a toolbar with search and sort, the banner and the rows. Under Genres the sidebar lists My list, All movies and each category with its count.

On iPhone the Movies tab shows the Movies | Series switch, a tall banner with genre chips over the artwork, then the rows. Swiping the banner pages it.

## Goals / Non-Goals

**Goals:**
- With 20 000 items in 400 categories, the banner and three rows on screen within two seconds on Apple TV 4K (3rd generation) and iPhone 15.
- The poster cache stays under 50 MB in memory and 500 MB on disk.

**Non-Goals:**
- A setting for the banner's rotation.
- A detail page. More info stays inert until change `add-title-detail-and-episode-picker`.

## Decisions

- Storage, duplicates and merge rules follow change `add-watch-progress-sync`. Records hold title ids and `sourceID`, never URLs. Removing from My list deletes every matching record.
- The poster cache keys on a hash of the URL and its disk entries never contain the URL. Playable URLs are built on demand from the Keychain credential and never logged.
- In progress means 2% to under 95% of a known duration. Records with no duration are left out. Resume seeks before the first frame. Series play picks the first episode in the Xtream client's order below 95%.
- Banner: four newest by `added`, eight seconds each, paused while focus, touch or pointer is inside, filled from provider order when fewer than four have dates. Length reads "2 h 08 min" or "<m> min". The 4K and age badges follow Badge rules below.
- Recently added holds 50 items and its header counts items added in the last 30 days. Undated items follow dated ones. Items with no category appear only in Recently added and the All grid.
- Board deviations: “Focus is the lifted white card” for the banner's Play button and the focused poster shadow, “One accent color” for the accent eyebrow, “Text stays above the platform caption floor” for outlined badges and the eyebrow up to 2 pt under the caption floor, “Loading shows real progress per step” for placeholder posters only until a source answers.
- Identifier prefixes are `movies.` and `series.` with the same element names.
- A position saved on another device updates Continue watching within five seconds of the local store change.
- The tvOS tab bar shows Movies and Series for any Xtream source, so the `tvos-shell` tab requirement changes with this.

## Badge rules

- "4K" shows when the movie's `name` contains "2160p", "4K" or "UHD", ignoring case.
- The age badge shows only when `ageRating` is one of: the digits 0 to 21, "U", "PG", "12", "12A", "15", "18", "R18", "G", "PG-13", "R", "NC-17", "TV-Y", "TV-Y7", "TV-G", "TV-PG", "TV-14", "TV-MA". Any other value shows no age badge.
- A series in the banner shows neither badge.

## Risks / Trade-offs

- [Storage for progress and My list is undecided] → the change is blocked on the storage decision in change `add-watch-progress-sync`. No requirement here changes with that choice.
- Open question: should Series get its own boards instead of reusing the Movies boards? Can be decided during implementation.
