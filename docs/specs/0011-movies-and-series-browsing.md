# 0011. Movies and series browsing

- Status: Draft (two spec-reviewer rounds applied; undrawn states listed under Design)
- Date: 2026-11-03
- Depends on ADRs: 0001, 0002, 0003, 0005
- Platforms: iOS, iPadOS, macOS, tvOS
- Builds on specs 0016 (VOD and series client), 0015 (tvOS shell), 0010 (sidebar and tab bar), 0012 (Search with a preselected chip). Overrides 0010/AC-2 and AC-3 for the Movies and Series entries (AC-1).
- Blocked on: an ADR for two new SwiftData records with CloudKit, `WatchProgressRecord` and `ListEntryRecord` (AC-3b, AC-4, AC-10, AC-14, AC-16, AC-17; migration is additive, two new models, no change to existing ones); and the playback engine spec (not yet written) for `seek(to:)`, `duration`, a position stream, and leaving VOD playback (AC-10, AC-16, edge case on exit).

## Design

Boards: `docs/design/boards/TV-Movies.dc.html` (tvOS), `docs/design/boards/iPad-Movies.dc.html` (iPadOS, macOS), `docs/design/boards/iPhone-Movies.dc.html` (iOS). The same page scrolled past Recently added is `TV-Movies-Rows.dc.html`, `iPad-Movies-Rows.dc.html` and `iPhone-Movies-Rows.dc.html` in the same folder. The Series section reuses the Movies boards with series data and the `series.` identifier prefix.
Design rules that apply: DR-2, DR-3, DR-4, DR-5, DR-9, DR-11, DR-12, DR-13, DR-15. Deviations: DR-2, the hero's Play button is drawn white-filled as the focused element and uses the surface fill unfocused; the focused card shadow is 0 16 pt 40 pt black at 55%; DR-4, outlined badges (hero badges and the card SERIES badge: 17 pt tvOS, 11 pt iPad and Mac, 10 pt iPhone) and the uppercase eyebrow sit up to 2 pt under the caption floor because they are letter-spaced labels; DR-15, placeholder cards show only while no source has returned, then per-source loading rows.
States on the boards: hero with eyebrow, title, metadata, badges, description, Play, More info ("Info" on iPhone), My List, pager dots (tvOS, iPad, Mac; none on iPhone); Continue watching with 16:9 cards, progress, remaining time and "See all"; Recently added row; sidebar (0010/AC-3's sidebar with Search; under Genres: My list, All movies, categories with counts, none highlighted while the rows show); genre chips over the hero and the search button (iPhone); sort button and search field (iPad, Mac); SERIES badge on the Continue watching series cards (`movies.card.<id>.badge`, outlined, top left of the image, on the same 0.72 scrim as the remaining-time label); My List button checked state (`iPad-Movies.dc.html`: check glyph, label "Remove from my list"; the plus state is on the tvOS and iPhone boards); Movies | Series segmented control on iPhone (`movies.kind`, 44 pt tall in the top bar in place of the title); focused card title in primary bold (`TV-Movies.dc.html`, Continue watching). On the Rows boards: My list row (`movies.row.myList`, header "<n> titles"), one row per provider category (`movies.row.<categoryID>`, header is the category name and "<n> titles"), and on tvOS the Genres row of 64 pt chips after the last category row (`movies.genres`: My list, then one chip per category; none selected while the rows show), with focus on the first My list poster.
Not drawn, to be added before the implementing PR: per-source loading rows (`movies.loading.<sourceId>`); empty, error, banner and alert states (title at body size, muted detail); card context menu; All movies grid. Each is a whole-screen state that needs its own frame per platform and was outside the review findings closed in PR #13.

## Problem

Xtream providers ship thousands of movies and series next to live TV, and TiviMate users call its VOD "not really very good": a flat list. People know how Netflix and Disney+ present a catalogue. Antenna has no VOD screen at all.

## Scope

In:
- Movies and Series sections, present when an Xtream source exists. On iPhone the Movies tab carries a Movies | Series segmented control (`movies.kind`); the iPhone tab bar never lists Series.
- Hero with the newest titles, rotating.
- Continue watching (movies and series together), My list (current kind), Recently added, one row per provider category.
- Genres are the provider's VOD or series categories. Genre filter to a grid: sidebar (iPad, Mac), chips (iPhone), a Genres row of chips after the category rows (tvOS).
- Sort menu on iPad and Mac; tvOS and iPhone are always Recently added.
- Play from the hero and cards; resume; next unwatched episode for series.
- My List toggle on the hero and through a card context menu.
- Position reporting while a VOD item plays.
- Section search entry opening 0012 with the kind's chip preselected (AC-19).
- Poster fallback.
- Loading, empty, error, banner and alert states.
- Accessibility identifiers with prefix `movies.` (Movies) and `series.` (Series), same element names.

Out (explicitly):
- Title detail screen (More info). The button is present and disabled until that spec exists.
- Episode picker and series detail.
- M3U playlists as a VOD source.
- Metadata from third-party databases.
- Downloads.
- Player UI for VOD beyond starting at a position; leaving VOD playback returns to the section with focus on the card that started it (playback spec).
- Parental controls and hidden categories.
- Caching the catalogue across launches (follow-up; offline therefore yields AC-13c).

## User flow

tvOS:
1. From the tab bar the user selects Movies. The hero fills the top. Dots show up to four hero titles rotating every eight seconds while nothing inside the hero has focus. Swiping left from Play or right from My List moves to the adjacent hero title and resets the timer; swipes between the three buttons move focus only. Dots are not focusable.
2. Below: Continue watching (if any), My list (if any), Recently added, one row per category, then a Genres row of chips. Rows scroll horizontally; the page scrolls vertically.
3. Focus on a card lifts it with the white ring. Select plays a movie or the next unwatched episode. Long press opens the context menu.
4. Series shows the same layout with series data.

iPadOS, macOS:
1. Movies in the sidebar shows the toolbar (title, search field, sort menu), the hero card, and the rows. Under the Genres header the sidebar lists My list, All movies and one entry per category with counts. Selecting the Movies section entry again returns from a grid to the rows.

iOS:
1. The Movies tab shows the Movies | Series control, a tall portrait hero with genre chips laid over the art and the copy on a scrim at its foot (no dots, no description, "Info" button), then the rows. Swiping horizontally on the hero moves between titles.

## Acceptance criteria

Each criterion is testable in isolation and has a stable id. Do not renumber.

### AC-1 Sections present with an Xtream source
Given no `SourceRecord` of kind Xtream
When navigation is rendered
Then Movies and Series are absent from the tvOS tab bar and the sidebar, and Movies is absent from the iPhone tab bar; given at least one Xtream source they are present whether or not its VOD endpoints have answered, the iPhone Movies tab shows `movies.kind`, and the section body shows the AC-13 state.

### AC-2a Hero selection and rotation
Given VOD items, some with nil `added`
When the Movies section is shown
Then the hero shows the item with the latest `added`; the dots count min(4, items) on tvOS, iPad and Mac; the hero advances through the four newest every eight seconds on the injected clock while no element inside the hero has focus (tvOS), is being touched (iOS, iPadOS) or has the pointer over it (macOS), and not under Reduce Motion; when fewer than four items have an `added` date the candidates are filled in provider order.

### AC-2b Hero metadata line
Given a hero title
When rendered
Then before `VODInfo` arrives the hero shows name, eyebrow and Play only; when it arrives the eyebrow reads "Recently added · <category>", the line shows the year, and the duration as "<h> h <mm> min" ("2 h 08 min") or "<m> min" under an hour, omitting a missing part; on failure the line, badges and description stay absent.

### AC-2c Hero badges
Given a hero title with `VODInfo`
When rendered
Then "4K" appears when `name` contains "2160p", "4K" or "UHD" case-insensitively, and the age badge appears only when `ageRating` is one of: digits 0 to 21, "U", "PG", "12", "12A", "15", "18", "R18", "G", "PG-13", "R", "NC-17", "TV-Y", "TV-Y7", "TV-G", "TV-PG", "TV-14", "TV-MA"; anything else shows no age badge.

### AC-3a Hero Play
Given the hero for a movie
When the user activates `movies.hero.play`
Then playback starts per AC-10a.

### AC-3b Hero My List
Given the hero for a title not in My list
When the user activates `movies.hero.myList`
Then a `ListEntryRecord` for the title id and `sourceID` is inserted, the button shows the check state, and the My list row appears or gains the title; activating again removes every matching record and reverses both.

### AC-3c More info
Given the hero
When rendered
Then `movies.hero.info` is present and disabled.

### AC-4 Continue watching row
Given `WatchProgressRecord`s with position p where 2% ≤ p < 95% of a known duration
When the Movies or Series section is shown
Then `movies.row.continueWatching` lists movies and series together as 16:9 cards ordered by `updatedAt` descending, each with a progress bar along the bottom edge and "<n> min left" rounded up (movies; top right on the image on tvOS, after the title with " · " elsewhere) or "S<season> E<episode>" (series); `movies.row.continueWatching.seeAll` opens the full grid; records with nil or zero duration are omitted; the row is absent when empty.

### AC-5 Recently added row
Given VOD items
When the Movies section is shown
Then `movies.row.recentlyAdded` lists the 50 items with the latest `added` descending, items with nil `added` after dated ones in provider order, and the header count is the number of items added in the last 30 days.

### AC-6 Category rows
Given VOD categories in provider order
When the Movies section is shown
Then one row per non-empty category follows in that order (`movies.row.<categoryID>`), titled with the category name and "<n> titles", posters in the provider's order; items with nil `categoryID` appear only in Recently added and the All grid.

### AC-7 Genre filter
Given the sidebar genre list, the iPhone chips or the tvOS Genres row
When the user selects a genre
Then the content area shows a poster grid of that category's titles with the count in the header in the current sort, the selected entry is highlighted with the 0.12 surface (`movies.genres.<categoryID>`); All (chip) or the section's sidebar entry restores the rows and clears the selection; Menu (tvOS) returns to the rows.

### AC-8 Poster fallback
Given a title whose poster URL is nil or fails to load
When its card is rendered
Then the card shows the title text centred on the placeholder colour, never an empty frame.

### AC-9a Series badge
Given a series card
When rendered
Then `movies.card.<id>.badge` reads "SERIES".

### AC-9b Series play
Given a series card
When selected
Then `seriesInfo(seriesID:)` is requested and the card shows an activity indicator until it returns; then the first episode in 0016/AC-6 order whose saved position is below 95% (no record counts as 0%) plays per AC-10a; with zero episodes `movies.alert` reads "No episodes available"; on failure `movies.alert` reads "Could not load episodes" with Retry.

### AC-10a Resume
Given a movie whose last saved position is 42%
When it is played from the hero, a card, My list or a search result
Then playback starts within five seconds of that position; a saved position at or above 95% or below 2% starts from zero.

### AC-10b Completion
Given a saved position at or above 95%
When Continue watching is built
Then a movie is omitted; a series card shows the next episode per AC-9b and the series is omitted only when every episode is at or above 95%.

### AC-11 tvOS focus
Given a card on tvOS
When it receives focus
Then it shows the 5 pt white ring and the 0 16 pt 40 pt black 55% shadow, its title turns primary and bold, and the row scrolls so the card is fully visible.

### AC-12 Sort menu on iPad and Mac
Given the toolbar's sort menu with default "Recently added" and the rows showing
When the user picks Title or Year
Then the rows below the hero are replaced by an "All movies" grid with the count, sorted A to Z or by year descending; picking "Recently added" restores the rows; the sidebar's All movies entry shows the same grid in the current sort; the sort also orders the AC-7 grid; while the rows are shown no Genres entry is highlighted.

### AC-13a Loading
Given no source has returned a VOD list
When the section is shown
Then `movies.loading` shows placeholder cards in the hero and row positions; once any source returns, its rows render and `movies.loading.<sourceId>` reads "<name>: loading…" as a row header until that source completes.

### AC-13b Empty
Given every Xtream source with a credential loaded zero items and none is still loading
When the section is shown
Then `movies.empty` reads "Nothing here yet" with one line per source "<name>: no movies".

### AC-13c Every source failed
Given every source failed
When the section is shown
Then `movies.error` reads "Could not load movies", or "You're offline. Connect to the internet and try again." when every failure is a `URLError` of the 0006/AC-8 set, with `movies.retry` re-requesting only the failed sources.

### AC-13d Partial failure
Given one source failed and another loaded
When the section is shown
Then the loaded rows render and `movies.banner` reads "Could not load <name>" (comma-joined), dismissible, not shown again until the next load.

### AC-13e Credential missing
Given an Xtream source whose Keychain item is absent
When the section is shown
Then it contributes no titles (0004/AC-10), is listed in `movies.empty` or `movies.error` as "<name>: waiting for its login to sync from iCloud" (same copy as 0010/AC-18), and is re-requested when the section appears and when the app returns to the foreground.

### AC-14 My list row
Given at least one `ListEntryRecord` of the section's kind
When the section is shown
Then `movies.row.myList` follows Continue watching with the current kind's titles ordered by `addedAt` descending; "See all" (tvOS, iPhone) or the sidebar entry opens the full grid.

### AC-15a Series hero
Given a series with `SeriesInfo` loaded
When the Series hero is rendered
Then the eyebrow reads "Recently added · <category>" using `lastModified`, the line shows the year and "<n> seasons" from `seasonCount`, the description from `plot`, and no 4K or age badge.

### AC-15b Series rows
Given series data
When the Series section is shown
Then Recently added orders by `lastModified` with the AC-5 rules, and category rows follow AC-6 over series categories; AC-7, AC-8, AC-11 to AC-14 and AC-17 hold with the `series.` prefix.

### AC-16 Position reporting
Given a VOD item playing
When 30 seconds elapse on the injected clock, or playback pauses, stops, the app backgrounds, or the item ends
Then the local `WatchProgressRecord` whose `titleID` and `sourceID` match is updated in place (inserted if none) with position, duration and `updatedAt`; when several records match (CloudKit merge) the one with the latest `updatedAt` is read and the rest are deleted on the next write.

### AC-17 Card list toggle
Given a card
When the user opens the card menu (long press on tvOS, iOS, iPadOS; secondary click on macOS) and activates `movies.card.<id>.menu.toggleList`
Then a `ListEntryRecord` is inserted or every matching one deleted, the item's label flips between "Add to My List" and "Remove from My List", the My list row updates, and `movies.hero.myList` updates when the card is the hero title.

### AC-18a Large catalogue, first paint
Given 20 000 items in 400 categories already received
When the section is shown
Then the hero and first three rows are on screen within two seconds on Apple TV 4K (3rd generation) and iPhone 15 (manual).

### AC-18b Poster cache bounds
Given the poster cache
When it exceeds 50 MB in memory or 500 MB on disk
Then it evicts to below those bounds (integration).

### AC-19 Section search
Given the Movies or Series section
When the user activates `movies.search`
Then the Search section opens with the Movies or Series chip preselected (0012/AC-10) and the field focused.

## Edge cases and failure modes

- Two Xtream sources: rows merge by category name with source `sortOrder` as tiebreak; the hero picks across sources.
- Thousands of categories: rows render lazily; only visible rows load posters; decoding runs off the main actor.
- Records store title ids and `sourceID` only, never URLs. The poster cache keys on a hash of the URL and the on-disk entry never contains the URL string. Playable URLs are built on demand from the Keychain credential and are not logged (ADR-0003).
- A `WatchProgressRecord` or `ListEntryRecord` whose title is not in the loaded set is neither listed nor counted and is not deleted (as 0013/AC-8).
- A title in both the VOD and series lists: shown once per section.
- A position saved elsewhere arrives in the local store: Continue watching updates within five seconds of the store change (integration test); device sync is checked manually.
- Rows missing `name` or `stream_id` are skipped per 0016/AC-4.
- Exiting VOD playback (Menu on tvOS, done elsewhere) returns to the section with focus on the card that started it; the last live channel is re-tuned when the user next selects Live (0015/AC-4's "no tune" does not apply after VOD).
- VoiceOver: a card reads title, year and "in progress, n minutes left" when applicable.

## Test plan

Row building, hero selection, continue-watching filtering, next-episode selection, badge rules and sort are pure functions in AntennaCore over 0016's fixtures. Records need the ADR's models and an in-memory `ModelContainer`. Identifiers (Movies; Series uses `series.`): `movies.kind`, `movies.hero`, `movies.hero.play`, `movies.hero.info`, `movies.hero.myList`, `movies.hero.dots`, `movies.row.continueWatching`, `movies.row.continueWatching.seeAll`, `movies.row.myList`, `movies.row.recentlyAdded`, `movies.row.<categoryID>`, `movies.card.<id>`, `movies.card.<id>.badge`, `movies.card.<id>.menu.toggleList`, `movies.genres`, `movies.genres.<categoryID>`, `movies.genres.myList`, `movies.chips`, `movies.grid`, `movies.sort`, `movies.search`, `movies.loading`, `movies.loading.<sourceId>`, `movies.empty`, `movies.error`, `movies.retry`, `movies.banner`, `movies.alert`.

| Criterion | Layer | Test |
|-----------|-------|------|
| AC-1 | ui (three layouts) | TBD |
| AC-2a | core (selection) + ui (injected clock) | TBD |
| AC-2b | core (formatting) + ui (stubbed info) | TBD |
| AC-2c | core | TBD |
| AC-3a | ui + fake engine | TBD |
| AC-3b | integration + ui | TBD |
| AC-3c | ui | TBD |
| AC-4 | core + integration | TBD |
| AC-5 | core | TBD |
| AC-6 | core | TBD |
| AC-7 | ui (three layouts) | TBD |
| AC-8 | ui | TBD |
| AC-9a | ui | TBD |
| AC-9b | core (next episode) + ui (stubbed client) | TBD |
| AC-10a | integration (fake engine seek) | TBD |
| AC-10b | core | TBD |
| AC-11 | ui (tvOS) | TBD |
| AC-12 | ui (iPad) | TBD |
| AC-13a | ui (stubbed client) | TBD |
| AC-13b | ui | TBD |
| AC-13c | ui (stubbed failures per code) | TBD |
| AC-13d | ui | TBD |
| AC-13e | ui (fake credential store) | TBD |
| AC-14 | integration + ui | TBD |
| AC-15a | core + ui | TBD |
| AC-15b | core + ui | TBD |
| AC-16 | integration (fake engine position stream, injected clock) | TBD |
| AC-17 | ui | TBD |
| AC-18a | device | manual |
| AC-18b | integration | TBD |
| AC-19 | ui | TBD |

## Open questions

- ADR: `WatchProgressRecord` and `ListEntryRecord` in SwiftData with CloudKit under ADR-0002 rules, versus `NSUbiquitousKeyValueStore` with its 1 MB cap.
- Should Series get its own boards (series hero with season count) rather than reusing the Movies boards?
- Hero rotation interval fixed at eight seconds, or a setting?
