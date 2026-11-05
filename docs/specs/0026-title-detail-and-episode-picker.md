# 0026. Title detail and episode picker for movies and series

- Status: Draft
- Date: 2026-11-04
- Depends on ADRs: 0001, 0002, 0003, 0005, 0006
- Builds on specs: 0010, 0011, 0012, 0015, 0016, 0017 (leaving playback; tests use a stand-in player until it ships), 0029 (storing and syncing watch progress and My list)
- Needs from other specs: 0011: a series poster outside Continue watching, and More info, open this page instead of playing, and Play's next-episode rule, Continue watching's included, becomes AC-16a here (if this spec is accepted first, 0011's series play and Continue watching follow AC-16a); 0012: a series result opens this page; 0015: the tab bar is hidden on this page; 0016: adds cast, director, rating, trailer link, and each episode's description and picture; 0017: leaving playback that started here returns to this page.
- Blocked on: the ADR that 0029 names for storing watch progress and My list.
- Platforms: iOS, iPadOS, macOS, tvOS
- User stories: US-18, US-19, US-20

## Summary

For people who watch their provider's movies and series. Once this ships, More info and a tap on a series open a detail page: the artwork, what the title is about, year, length, genre, rating, cast and director, with Play or Resume and My list. For a series it adds a season picker and the episode list, each episode with its picture, description and how much of it has been watched, and Play picks the episode the user most likely wants next. It does not play the next episode by itself, play trailers inside the app, show related titles, or let the user mark episodes watched by hand.

## Design

Boards: `docs/design/boards/TV-Title.dc.html`, `docs/design/boards/TV-Series.dc.html`, `docs/design/boards/iPad-Title.dc.html`, `docs/design/boards/iPad-Series.dc.html`, `docs/design/boards/iPhone-Title.dc.html`, `docs/design/boards/iPhone-Series.dc.html`.
Design rules that apply: DR-2, DR-3, DR-4, DR-5, DR-7, DR-11, DR-12, DR-13, DR-15.
Not drawn: loading bars for the details, loading episode rows, the two error states, no episodes, the Apple TV full-description sheet, the expanded description, the focused episode row and season chip on Apple TV, the greyed-out Play button, and the Play error line.

Layout, sizes, states and identifiers come from the boards and are settled in the implementation plan, not here.

## Problem

0011 gives Movies and Series a More info button that does nothing, and plays a series from its poster without ever showing its episodes. The user cannot read what a movie is about, choose an episode, or see which episodes they have watched. TiviMate users name this gap: episodes show "only the episode number with no description".

## Scope

In:
- Movie page: artwork, kind and category, name, year, length, genre, rating and badges, description with More, cast and director, Play or Resume with progress, My list, and Trailer where the provider gives a link.
- Series page: the same top part with the number of seasons, Play or Resume naming the episode, a season picker, and the episode list with picture, number, title, length, description, progress, Watched and an UP NEXT mark.
- Ways in: More info on the Movies and Series banner, More info in a movie poster's menu, and selecting a series poster outside Continue watching or a series in search results.
- Sensible gaps when the provider leaves fields out, artwork included.
- Loading and error states with Retry and the offline message.
- Playing a movie or an episode from the page, resuming, and coming back to the page afterwards.
- Going back to the section with the poster the user started from in place.
- Apple TV remote navigation; Escape on Mac and iPad keyboards.
- Arrow keys and Return in the season picker and episode list on Mac and iPad keyboards.

Out (explicitly):
- Playing the next episode automatically, and any player controls (0017, 0018).
- "More like this" and related titles.
- Ratings or artwork from outside databases.
- Playing a trailer inside the app.
- Movies from M3U playlists, downloads, parental controls and hidden categories (as 0011).
- Keeping title details between launches.
- Marking an episode watched or unwatched by hand.
- Reading an episode's full description on Apple TV; rows show one line.
- What happens when the purchase lapses while the page is open (0024). The page is only reachable from sections that are already paid for.

## User flow

Apple TV:
1. The user picks More info on the Movies banner, or long-presses a poster and picks More info. The page fills the screen with Play or Resume focused; the tab bar is hidden.
2. The user reads the description, opens More for the rest, moves to My list, or plays. Leaving playback comes back here with the progress updated.
3. Selecting a series poster opens its page with "Play S1 E1" or "Resume S2 E4" focused. Swiping down reaches the seasons, then the up-next episode. Selecting an episode plays it.
4. Menu goes back to the poster or button the user started from.

iPad and Mac:
1. More info, or a click on a series poster, shows the page in place of the rows, with the sidebar kept and a back link in the toolbar.
2. Back, or Escape, returns to the rows with the poster in view.

iPhone:
1. Info, More info or a tap on a series poster opens the page inside the Movies tab, with a round back button over the artwork.
2. Back, or a swipe from the left edge, returns to the rows.

## Acceptance criteria

### AC-1 Open a movie's page
Given a movie on the Movies banner and as a poster
When the user picks More info on the banner or in the poster's menu
Then the movie's page opens at once with its name, "Movie · <category>" and its poster, shows that the rest is loading, and asks the provider for the details once.

### AC-2 Open a series' page
Given a series poster outside Continue watching, the Series banner, or a series in search results
When the user selects the poster or result, or picks More info on the banner
Then the series' page opens at once with its name, "Series · <category>" and poster, the episode list shows it is loading, Play waits until the episodes arrive, and nothing starts playing; a series in Continue watching still plays straight away, picking its episode by the same rule as AC-16a.

### AC-3 What the title is about
Given a movie whose details include year 2024, a length of 2 h 08 min, genre Thriller, rating 7.4, age rating 15, a "2160p" name, a description, cast and a director
When the details arrive
Then the backdrop replaces the poster and the page shows year, length, genre, rating and the age and 4K badges, the description cut to a few lines with More, and the cast and director; a field the provider leaves out is simply missing, never "Unknown"; a series shows its number of seasons instead of a length.

### AC-7 Play or Resume a movie
Given a movie the user stopped part-way through, and one they have not started or have finished
When they open its page and press the button
Then the first reads "Resume" with a progress bar and the minutes left, and plays from where they stopped; the second reads "Play" and plays from the start; when the movie ends or the user leaves playback, they are back on the page with the button and bar up to date.

### AC-9a My list from the page
Given a title not in My list
When the user presses My list on its page, and presses it again
Then the first press adds it, the button shows a check and "Remove from my list", and the banner's My list button agrees; the second removes it and both go back; however fast the user presses, the list ends up matching the button.

### AC-10 Trailer
Given the provider gives a trailer link for the title, on iPhone, iPad or Mac
When the user presses Trailer
Then the link opens outside the app; on Apple TV, or without a link, there is no Trailer button.

### AC-11 When details or episodes do not load
Given the provider fails to answer for the details or the episodes
When the page is showing
Then the part that failed reads "Could not load details" or "Could not load episodes" (or the offline message when that is the cause) with Retry, and a movie whose details failed can still be played and added to My list.

### AC-13 Pick a season
Given a series with seasons 1, 2 and 3, specials (season 0) and episodes with no season
When the user opens its page and picks Season 3 by tap, click, the arrow keys, or (on Apple TV) by resting on it
Then the picker lists "Season 1", "Season 2", "Season 3", "Specials" and "Other", opens on the season that holds the episode Play would start, and shows only Season 3's episodes in order with its episode count after the pick; with only one group there is no picker.

### AC-15 What each episode shows
Given episodes watched to the end, part-way, barely or not at all, some without a picture, title or description
When the user looks at the episode list
Then each row shows a picture (or a tile with the episode number), the number, the title, the length and one line of description; a finished episode shows a full bar and "Watched" instead of its length, one in progress shows its bar and the minutes left, and one barely started looks unwatched; missing fields are left out.

### AC-16a Play starts the right episode
Given a series the user has partly watched
When they open its page
Then Play resumes the episode they were last part-way through; if none is in progress, it plays the first unwatched episode after the last one they finished, wrapping to the start when that was the last; if nothing is started it plays Season 1 Episode 1 rather than a special; if everything is watched it plays the first episode; that episode carries the UP NEXT mark and the button names it, for example "Resume S2 E4"; with no episodes Play is disabled.

### AC-18 Play an episode and come back
Given the episode list
When the user selects an episode, or presses Play for the up-next one
Then it plays from where they stopped, its progress is saved as it plays, and when it ends or they leave playback they are back on the page with that episode's season showing, the episode in view, and its bar, the UP NEXT mark and the Play button up to date.

### AC-21 Back to where you were
Given the page was opened from a poster deep in a row, from the banner, or from search results
When the user goes back with Menu (Apple TV), the back button or Escape (iPad, Mac), or the back button or an edge swipe (iPhone)
Then the section shows the same rows at the same scroll position without reloading, with the poster or button they started from focused on Apple TV and in view elsewhere; from search, Search shows with the query still there.

## Edge cases

- A slow provider: the name and poster show at once; only the details and episodes wait.
- Leaving before the details arrive cancels the request; opening the page again asks again.
- A source deleted while its page is open closes the page and returns to the section.
- Two sources with the same title: each poster opens its own page and keeps its own progress.
- An episode watched outside Antenna shows as unwatched until played here.
- A provider whose season count disagrees with its episodes is shown by what the episodes say.
- Large text sizes wrap the details line and grow the episode rows.
- VoiceOver reads the page as name, details, then description; an episode as number, title, length, minutes left or watched, and "up next" when marked.
- A series with no episodes says "No episodes available".
- Episodes the provider listed but could not describe are counted under the list: "<n> episodes could not be read from the provider's list."
- A login not on this device shows "<source>: waiting for its login to sync from iCloud" with Retry; Play shows the same line and plays nothing.
- A position or My list change arriving from another device updates the button, the bars and the UP NEXT mark while the page is open.

## Test plan

| Criterion | Layer |
|-----------|-------|
| AC-1 | ui |
| AC-2 | ui |
| AC-3 | core + ui |
| AC-7 | core + integration + ui |
| AC-9a | integration + ui |
| AC-10 | ui |
| AC-11 | integration + ui |
| AC-13 | core + ui |
| AC-15 | ui |
| AC-16a | core + ui |
| AC-18 | integration + ui |
| AC-21 | ui |

## Open questions

The owner answers each one that changes a criterion before this spec is Accepted.

- A series poster opens its page while a movie poster still plays. Open the page for both, as Netflix and the Apple TV app do? Changes AC-1 and AC-2.
- The Apple TV page hides the tab bar, against 0015's "always visible" rule. Can be decided in the plan.
- Seasons switch on Apple TV after resting on a chip for 300 ms, or on select (one more press each time)? Changes AC-13.
- Trailer opens outside the app and is missing on Apple TV; an in-app web view may read to App Review as linking third-party content (guideline 5.2.3). Changes AC-10.
- UP NEXT as a filled accent badge (a DR-3 deviation) or outlined. Can be decided in the plan.
- Play prefers the episode last in progress, then the one after the last finished (AC-16a); 0011 started at the first unwatched, which sends someone who skipped the pilot back to it. Changes AC-16a.
- "No description from your provider." or no description area at all? Changes AC-3.
- "Other" for episodes with no season, or "Extras" or "Episodes"? Can be decided in the plan.

## Notes for the plan

- Detail of the Needs line: 0016's `VODInfo` and `SeriesInfo` gain `cast`, `director`, `rating` (0 is nil) and `trailerURL` (a valid URL as is, an 11-character YouTube id becomes `https://www.youtube.com/watch?v=<id>`, else nil), and `Episode` gains `plot` and `thumbnailURL`; 0011 enables `movies.hero.info` and `series.hero.info`, adds "More info" before the list toggle in movie poster menus, and its Continue watching card uses `SeriesPlayTarget`; 0015's swipe-up does not apply on the page.
- Details line format: "2024 · 2 h 08 min · Thriller · ★ 7.4", then the 4K and age badges; a missing description reads "No description from your provider." (still an open question).
- Pure functions in AntennaCore: `TitleMetadata` (details line and labels), `SeasonGroup.group(_:)` (Season 1 to n, Specials for 0, Other for none, each in 0016's order), `SeriesPlayTarget.resolve(episodes:progress:)` returning the episode and whether it resumes, over a `WatchProgress` value (`titleID`, `position`, `duration`, `updatedAt`).
- Play target rules: below 2% is ignored everywhere; a missing record or one with no duration counts as 0%; in progress is 2% to under 95%, latest `updatedAt` wins, ties go to the earlier episode; otherwise the first episode under 95% after the latest-updated record, wrapping. Label forms: "Play S2 E3", "Play E3", "Play S2", "Play", and the same with "Resume".
- Records as in 0029, with episode positions under the episode's own title id. CloudKit can leave duplicates: read the latest, and removing from My list deletes every match. Records hold ids, never URLs; playable URLs are built on demand from the Keychain credential and never logged or stored (ADR-0003). Art URLs may use 0011's poster cache.
- Display rules: rating is `VODInfo.rating ?? VODItem.rating`, one decimal; empty or whitespace fields count as missing; the seasons count follows the season groups once episodes load; description clamps at four lines (movie on tvOS and iOS), five (movie on iPad and Mac), two (series); episode rows one line; container extension from `VODInfo`, else `VODItem`.
- Apple TV focus: Play first, My list to the right, More above when the description is clamped, season chip then up-next row below; the tab bar and clock are hidden and 0015's idle timer keeps running; on an error focus stays put or moves to Play, with Retry below the buttons. Season chips switch after 300 ms of focus on an injected clock (provisional).
- Board deviations: DR-3, UP NEXT is a filled accent badge and the eyebrow is accent; DR-5, season chips 34 pt (iPad, Mac) and 30 pt (iPhone) with a 44 pt tap area, and the More link has a 44 pt tap area; DR-2, Play as on the Movies banner; DR-4, badges and eyebrow up to 2 pt under the caption floor; DR-7, progress is never shown without its bar.
- Leaving before a reply cancels the request as in 0016 and a late reply changes nothing. A deleted source dismisses the page with no further request. Trailer opens through an injected `openURL`. Identifier prefixes `title.` and `episodes.`.
- Budgets from the dropped AC-24 and AC-25: grouping and play target each under 50 ms for 5 000 episodes in 40 seasons with 1 000 progress values (debug `swift test`, `ANTENNA_BENCHMARKS=1`, 0016 baseline); a 2 000-episode season scrolls with no hitch over 100 ms on Apple TV 4K (3rd generation) and iPhone 15, and image requests at the top stay within the visible rows plus one screen.

## Dropped

- Split earlier (kept for history): AC-4 into AC-4a, AC-4b and AC-4c, since it bundled three scenarios; AC-9 into AC-9a and AC-9b; AC-14 into AC-14a and AC-14c, AC-14b being the keyboard criterion; AC-16 into AC-16a, AC-16b, AC-16c, AC-16d and AC-16e; AC-23 into AC-23a and AC-23b, since a login not yet synced is not a removed source.
- Moved to the implementation plan: AC-4c, AC-20, AC-22, AC-22b, AC-22c, AC-23a, AC-24, AC-25. AC-23a stays as an edge case.
- Merged into AC-3: AC-4a, AC-4b, AC-5, AC-6, AC-12.
- Merged into AC-7: AC-8.
- Merged into AC-9a: AC-9b.
- Merged into AC-11: AC-19, AC-23b, AC-23c.
- Merged into AC-13: AC-13b, AC-14a, AC-14b, AC-14c.
- Merged into AC-15: AC-17.
- Merged into AC-16a: AC-16b, AC-16c, AC-16d, AC-16e.

Retired ids are never reused.
