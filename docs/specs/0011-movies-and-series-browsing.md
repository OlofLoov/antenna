# 0011. Movies and series browsing

- Status: Accepted
- Date: 2026-11-03
- Depends on ADRs: 0001, 0002, 0003, 0005
- Builds on specs: 0010, 0012, 0015, 0016, 0017 (jumping to a position, reporting the position, and leaving movie playback), 0029 (storing and syncing watch progress and My list)
- Overrides the Movies and Series entries in the sidebar and tab bar of 0010 and the tab list of 0015 (AC-1a).
- Blocked on: the ADR that 0029 names for storing watch progress and My list.
- Platforms: iOS, iPadOS, macOS, tvOS
- User stories: US-18, US-20

## Summary

For people whose IPTV subscription (Xtream, a common provider login) includes movies and series. Once this ships they get a Movies and a Series section laid out like a streaming app: a large banner of new titles, rows for Continue watching, My list, Recently added and each of the provider's categories, and a grid per genre. They can play a title, pick up where they stopped, start the next episode they have not seen, and keep a list of things to watch later. The detail page for a title and the episode picker come in 0026; downloads, outside metadata and playlist-based movies are not part of it.

## Design

Boards: `docs/design/boards/TV-Movies.dc.html`, `docs/design/boards/iPad-Movies.dc.html`, `docs/design/boards/iPhone-Movies.dc.html`, `docs/design/boards/TV-Movies-Rows.dc.html`, `docs/design/boards/iPad-Movies-Rows.dc.html`, `docs/design/boards/iPhone-Movies-Rows.dc.html`, `docs/design/boards/TV-Movies-Grid.dc.html`, `docs/design/boards/iPad-Movies-Grid.dc.html`, `docs/design/boards/iPhone-Movies-Grid.dc.html`. The Series section reuses the Movies boards with series data.
Design rules that apply: DR-2, DR-3, DR-4, DR-5, DR-9, DR-11, DR-12, DR-13, DR-15.
Not drawn: loading rows per source, empty, error, banner, alert, the poster menu, and the More info button that does nothing yet.

Layout, sizes, states and identifiers come from the boards and are settled in the implementation plan, not here.

## Problem

Xtream providers ship thousands of movies and series next to live TV. TiviMate shows them as a flat list, and its users call its movie section "not really very good". People know how Netflix and Disney+ present a catalogue, and Antenna has no movie screen at all.

## Scope

In:
- Movies and Series sections whenever an Xtream source exists. On iPhone the Movies tab has a Movies | Series switch, and Series never gets its own tab.
- A banner at the top that cycles through the newest titles.
- Rows: Continue watching (movies and series together), My list, Recently added, and one row per provider category.
- Genres, which are the provider's categories, open a grid: from the sidebar on iPad and Mac, chips on iPhone, a row of chips on Apple TV. All movies and Continue watching's See all open the same grid.
- Sorting by title or year on iPad and Mac. Apple TV and iPhone always show newest first.
- Playing from the banner and from posters, resuming, and the next unseen episode for a series.
- Adding to and removing from My list, on the banner and from a poster's menu.
- Saving the position while a movie or episode plays.
- A search button that opens Search (0012) set to movies or series.
- More info shows on the banner but does nothing until 0026.
- A stand-in for missing posters, and what the screen shows while loading, empty, failed or partly failed.

Out (explicitly):
- The title detail page, episode picker and series page (0026).
- Movies from M3U playlists.
- Ratings or artwork from outside databases.
- Downloads.
- Player controls for movies beyond starting at a position (0017, 0018).
- Parental controls and hiding categories.
- Keeping the catalogue between launches. Offline, the section shows its error message.

## User flow

Apple TV:
1. The user picks Movies in the tab bar. The banner fills the top and moves through up to four new titles while nothing in it is focused; swiping past its buttons pages it by hand.
2. Below: Continue watching, My list, Recently added, a row per category, then a row of genre chips.
3. Selecting a poster plays the movie, or the next episode not yet watched. A long press opens the poster's menu.
4. Series looks the same with series.

iPad and Mac:
1. Movies in the sidebar shows a toolbar with search and sort, the banner and the rows. Under Genres the sidebar lists My list, All movies and each category with its count.

iPhone:
1. The Movies tab shows the Movies | Series switch, a tall banner with genre chips over the artwork, then the rows. Swiping the banner pages it.

## Acceptance criteria

### AC-1a Movies and Series appear when your provider has them
Given the user has at least one Xtream source, whether or not its login has reached this device or it has answered yet
When the user looks at the tab bar or sidebar
Then Movies and Series are listed (on iPhone, Movies with its Movies | Series switch); with no Xtream source neither appears.

### AC-2a New titles up front
Given the provider's movies have dates they were added
When the user opens Movies
Then the banner shows the newest title with its name, category, year, length and description, moves through the four newest by itself while the user is not interacting with it, and can be paged by hand.

### AC-3b Keep a list for later
Given a title that is not in My list
When the user adds it with the banner's My list button or from the poster's menu
Then the button and menu offer to remove it instead, and the My list row appears or gains the title, latest additions first; removing it undoes both.

### AC-4 Continue watching
Given the user has stopped movies and episodes part-way through
When the user opens Movies or Series
Then Continue watching lists them together, most recent first, each with a progress bar and the minutes left (movie) or the season and episode (series); a movie watched to the end leaves the row, and a series whose episode was finished shows "Next episode" until no unwatched episode is left; with nothing in progress the row is not shown.

### AC-6 Rows in a predictable order
Given the provider's movies and categories
When the user opens Movies
Then after Continue watching and My list come Recently added, newest first, and one row per category that has titles, in the provider's order, each headed with its name and number of titles.

### AC-7 Browse a genre or sort the lot
Given the rows are showing
When the user picks a genre, My list, All movies, or See all on Continue watching, or on iPad and Mac picks Title or Year in the sort menu
Then a poster grid of those titles in the chosen order takes the rows' place with the count above it; on Apple TV it opens as its own screen that Menu closes; All (iPhone), the section in the sidebar (iPad, Mac) or "Recently added" in the sort menu brings the rows back.

### AC-9b Play a series from the next episode
Given a series poster
When the user selects it
Then the poster shows it is working while the episode list loads, then the first episode the user has not finished starts.

### AC-10a Resume where you left off
Given a movie the user stopped part-way through
When the user plays it from the banner, a poster, My list or a search result
Then it starts within five seconds of where they stopped; a movie barely started or already finished starts from the beginning.

### AC-13c When sources fail
Given at least one Xtream source failed to load
When the user opens the section
Then titles from the other sources still show under a banner naming each failed source, which the user can dismiss; when no source has titles, "Could not load movies" with a Retry that asks only the failed sources again takes their place.

### AC-15b Series work the same way
Given the provider has series
When the user opens Series
Then everything above holds for series, ordered by when each series last changed, with the banner showing the number of seasons instead of a length.

### AC-16 Your place is saved as you watch
Given a movie or episode is playing
When 30 seconds pass, or the user pauses or stops, the app goes to the background, or the title ends
Then the position is saved, and Continue watching and Resume show it from then on.

### AC-19 Search from the section
Given the Movies or Series section on iPhone, iPad or Mac
When the user taps the search button (iPhone) or types in the toolbar's search field (iPad, Mac)
Then Search opens set to movies or series with the field ready for typing and any text already typed carried over; Apple TV has no search button here and uses its Search tab (0015).

## Edge cases

- With Reduce Motion on, the banner never moves by itself. Paging wraps at either end.
- A series with no episodes says "No episodes available"; if the list fails to load, "Could not load episodes" with Retry.
- Offline, the failure message says so.
- When every source answered with no titles, the section says "Nothing here yet" with a line per source.
- A source whose login has not arrived from iCloud is named as waiting for it, and is tried again when the section opens and when the app returns to the foreground.
- A position or My list change from another device shows in the open section without reopening it.
- Two Xtream sources: their rows merge by category name, and the banner picks from both.
- Thousands of categories: rows load as they scroll into view, and only visible rows fetch posters.
- A missing or broken poster shows the title's name on a plain tile, never an empty frame.
- A title the provider lists as both a movie and a series shows once in each section.
- A saved position or list entry for a title that is not loaded is not shown or counted, and is kept.
- Provider entries without a name or id are skipped, as in 0016.
- Leaving a movie returns to the poster that started it; the last live channel starts again the next time the user opens Live.
- VoiceOver reads a poster as title, year and, when in progress, the minutes left.

## Test plan

| Criterion | Layer |
|-----------|-------|
| AC-1a | ui |
| AC-2a | core + ui |
| AC-3b | integration + ui |
| AC-4 | core + integration |
| AC-6 | core |
| AC-7 | ui |
| AC-9b | core + ui |
| AC-10a | integration |
| AC-13c | ui |
| AC-15b | core + ui |
| AC-16 | integration |
| AC-19 | ui |

## Open questions

- Where watch progress and My list are stored is 0029's ADR; no criterion here changes with it.
- Should Series get its own boards instead of reusing the Movies boards? Can be decided in the plan.
- Decided: the banner rotates every eight seconds; there is no setting for it.

## Notes for the plan

- Storage, duplicates and merge rules as 0029. Records hold title ids and `sourceID`, never URLs; removing from My list deletes every matching record.
- The poster cache keys on a hash of the URL and its disk entries never contain the URL. Playable URLs are built on demand from the Keychain credential and never logged (ADR-0003).
- In progress means 2% to under 95% of a known duration; records with no duration are left out. Resume seeks before the first frame. Series play picks the first episode in 0016's order below 95%.
- Banner: four newest by `added`, eight seconds, paused while focus, touch or pointer is inside, filled from provider order when fewer than four have dates. Length reads "2 h 08 min" or "<m> min". The 4K badge comes from "2160p", "4K" or "UHD" in the name; the age badge shows only for a known rating list (see the dropped AC-2c in git history).
- Recently added holds 50 items and its header counts items added in the last 30 days. Undated items follow dated ones; items with no category appear only in Recently added and the All grid.
- Budgets from the dropped AC-18a and AC-18b: with 20 000 items in 400 categories the banner and three rows are on screen within two seconds on Apple TV 4K (3rd generation) and iPhone 15; the poster cache stays under 50 MB in memory and 500 MB on disk.
- Board deviations: DR-2 for the banner's Play button and the focused poster shadow, DR-3 for the accent eyebrow, DR-4 for outlined badges and the eyebrow up to 2 pt under the caption floor, DR-15 for placeholder posters only until a source answers.
- Identifier prefixes are `movies.` and `series.` with the same element names.
- A position saved on another device updates Continue watching within five seconds of the local store change.

## Dropped

- Moved to the implementation plan: AC-2c, AC-3c, AC-8, AC-9a, AC-11, AC-13a, AC-18a, AC-18b. 0026 now owns the More info page; the poster fallback stays as an edge case.
- Merged into AC-1a: AC-1b.
- Merged into AC-2a: AC-2b, AC-2d.
- Merged into AC-3b: AC-14, AC-17.
- Merged into AC-4: AC-10b.
- Merged into AC-6: AC-5.
- Merged into AC-7: AC-12.
- Merged into AC-10a: AC-3a.
- Merged into AC-13c: AC-13b, AC-13d, AC-13e.
- Merged into AC-15b: AC-15a.
