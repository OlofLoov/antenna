# 0026. Title detail and episode picker for movies and series

- Status: Draft
- Date: 2026-11-04
- Depends on ADRs: 0001, 0002, 0003, 0005, 0006
- ADR needed: `WatchProgressRecord` and `ListEntryRecord` as CloudKit-synced SwiftData models, the same decision 0011 waits on. The criteria below assume both exist as 0011 describes them (title id plus `sourceID`, position, duration, `updatedAt`; list entries with `addedAt`), with episode positions stored under the episode's own title id. Because the records follow ADR-0002 (every property optional or defaulted, `kind` stored as a raw string, no unique constraint), two records can exist for one title; AC-9b deletes every match for that reason. The ADR carries the migration note.
- Blocked on: specs 0006, 0010, 0011, 0012, 0015 and 0016 merged to main (they are open PRs; every cross-reference below points into them); the ADR above; the playback engine spec (not yet written) for leaving VOD playback and returning to the presenting screen (AC-8, AC-18), tested with a fake engine until then; the Not drawn boards before the implementing PR.
- Platforms: iOS, iPadOS, macOS, tvOS
- Supersedes 0011/AC-3c (info enabled), 0011/AC-9b and 0012/AC-9b (series select opens the detail outside Continue watching). Amends 0011/AC-10b (target via `SeriesPlayTarget`, AC-16a to AC-16d), 0011/AC-17 (`menu.info` item), 0015's Design section (tab bar hidden on the detail) and 0016 (new fields, listed under "Required of other specs"). On acceptance those specs' status lines and README rows say so.
- Builds on specs 0016 (`VODItem`, `VODInfo`, `Series`, `SeriesInfo`, `Episode`, playable URLs), 0011 (sections, cards, hero, records, resume rules), 0012 (title results), 0015 (tvOS shell, Menu), 0010 (sidebar and tab bar). Takes over the items 0011 lists as out: title detail, episode picker, series detail. Changes it needs in those specs are under "Required of other specs".

## Design

Boards: `docs/design/boards/TV-Title.dc.html` (tvOS movie), `TV-Series.dc.html` (tvOS series with season chips and episodes), `iPad-Title.dc.html` (iPadOS and macOS movie), `iPad-Series.dc.html` (iPadOS and macOS series), `iPhone-Title.dc.html` (iOS movie in the missing-metadata state), `iPhone-Series.dc.html` (iOS series). The movie and series layouts share the header; a platform that has only one of the two drawn uses the other platform's board for the missing variant at its own type scale.
Design rules that apply: DR-2, DR-3, DR-4, DR-5, DR-7, DR-11, DR-12, DR-13, DR-15. Deviations: DR-3, `UP NEXT` is a third filled accent badge because it marks the one episode the Play button would start, the series equivalent of `NOW`; section 3 of the design README lists it. DR-3, the eyebrow is accent-coloured as on the 0011 hero, the one label that names the kind. DR-5, season chips are 34 pt (iPadOS, macOS) and 30 pt (iOS) visually with a 44 pt hit area, and `title.more` on iPadOS and macOS is a text link with a 44 pt hit area. DR-2, the Play button is drawn white-filled as the focused element and takes the 0.14 surface when another element has focus, as on the Movies hero. DR-4, the outlined badges and the `UP NEXT` badge (17 pt tvOS, 11 pt iPad and Mac, 10 pt iPhone) and the uppercase eyebrow sit up to 2 pt under the caption floor because they are letter-spaced labels, as 0011 already allows. DR-7 applies to episode rows and to the Resume state: a position in progress is never shown without its bar.
What the art shows before a backdrop loads, and the poster geometry of AC-4a, are the impl-reviewer's checks against the boards. States on the boards: full metadata with Resume, progress bar and remaining time, cast, director, More and the unchecked My list button (`TV-Title.dc.html`, `iPad-Title.dc.html`; the iPad board adds `title.trailer`); series header with "3 seasons", the checked My list button and "Resume S2 E4" (`TV-Series.dc.html`, `iPad-Series.dc.html`, `iPhone-Series.dc.html`); season chips with the selected one on the 0.12 surface and the count at the trailing edge; episode rows in four states on every series board: watched (bar full, "Watched" in place of the duration), up next (`UP NEXT` badge, bar at 52%, "44 min · 21 min left"), no plot (title and duration only), no title and no thumbnail ("Episode 6" from 0016/AC-6d and a number tile in the logo placeholder colour); `episodes.skipped` caption (`iPad-Series.dc.html`); missing metadata for a movie, with the poster centred on the placeholder colour in place of the backdrop, the metadata line reduced to the duration, `title.noPlot`, no badges, no cast, no trailer (`iPhone-Title.dc.html`; with a URL, iPhone shows `title.trailer` after `title.myList` as on the iPad board); back control (`title.back`, accent link in the toolbar on iPad and Mac, 44 pt round button over the art on iPhone; none on tvOS, where Menu pops).
Not drawn, to be added before the implementing PR: `title.loading`, placeholder bars on the 0.08 surface where the metadata line, plot and cast will be, 24 pt tall on tvOS, 14 pt on iPad and Mac, 13 pt on iPhone, under the already rendered name and art; `episodes.loading`, three rows at the list's row height on the 0.08 surface with "Loading episodes" in the muted caption as the header count; `title.error` and `episodes.error`, title at body size (29 tvOS, 17 iPad and Mac, 17 iPhone) with a muted detail line and a 44 pt (64 pt on tvOS) Retry button, in place of the metadata block or the episode list; `episodes.empty`, "No episodes available" in the muted body in place of the list; `title.plotSheet` on tvOS, the full plot at 29 pt on a full-frame scrim, Menu to dismiss; the expanded plot on touch and pointer platforms, the same text block without the clamp and without More; a focused episode row and a focused season chip on tvOS, both the Focus token with muted text in `#4B5563` and the progress bar unchanged; `title.play` disabled (AC-16d with zero episodes, AC-19), the 0.14 surface with the label in the muted colour. `title.playError`, one line in the muted caption under the button row (AC-23c).

## Problem

0011 gives the Movies and Series sections a disabled More info button and plays a series from its card without ever showing its episodes. The user cannot read what a movie is about before playing it, cannot choose an episode, and cannot see which episodes they have watched. TiviMate users name exactly this gap: episodes show "only the episode number with no description", and VOD is "not really very good".

## Scope

In:
- Movie detail: art, eyebrow, name, metadata line (year, duration, genre, rating, badges), plot with More, cast and director, Play or Resume with progress, My list, Trailer where the provider gives a URL.
- Series detail: the same header with "<n> seasons" in place of the duration, Play or Resume naming the up-next episode, season picker, episode list with thumbnail, number, title, duration, plot, progress, Watched, and the `UP NEXT` marker.
- Entry points: `movies.hero.info` and `series.hero.info` (enabled by this spec), the card menu item `movies.card.<id>.menu.info`, and select on a series card outside Continue watching or on a series search result.
- Missing-metadata fallbacks for every field, including art.
- Loading and error states for `vodInfo(streamID:)` and `seriesInfo(seriesID:)`, with Retry and the offline wording.
- Playing a movie or an episode from the detail, resuming per 0011/AC-10a, and returning to the detail afterwards.
- Return to the section with the originating card in place.
- tvOS focus order and Menu behaviour; hardware keyboard Escape on iPadOS and macOS.
- Pure functions in AntennaCore: `TitleMetadata` (metadata line and labels), `SeasonGroup` (grouping and picker labels; `group(_:)` returns groups in AC-13 order, each in 0016/AC-6b order), `SeriesPlayTarget` (which episode Play starts and whether it resumes, iterating the groups in that order), over 0016's models and a `WatchProgress` value (`titleID`, `position`, `duration`, `updatedAt`).
- Accessibility identifiers with prefixes `title.` (header) and `episodes.` (season picker and list).

Out (explicitly):
- Autoplay of the next episode when one ends, and any player UI (playback engine spec, not yet written).
- "More like this" rows and related titles (later spec).
- Metadata from third-party databases, and any lookup by `tmdb_id` (0011 lists it out; a later spec).
- Playing a trailer inside the app; the Trailer control opens the provider's URL outside the app (open question).
- M3U playlists as a VOD source (0011).
- Downloads, parental controls, hidden categories (0011).
- Caching `VODInfo` and `SeriesInfo` across launches (the catalogue caching follow-up 0011 names).
- Marking an episode watched or unwatched by hand (later spec).
- Reading an episode's full plot on tvOS; rows show one line (later spec, likely long-press into `title.plotSheet`).
- Sync conflict rules for `WatchProgressRecord` beyond 0011/AC-16.
- Entitlement checks. The detail is reachable only from sections that ADR-0006 already gates; what a lapse while the detail is open does belongs to the paywall spec (not yet written). This spec adds no other feature gate.

## User flow

tvOS:
1. On a Movies hero the user selects More info; on a card they long-press and select More info. The detail covers the screen: art full bleed, copy in the left column, focus on Play or Resume. The tab bar is not shown.
2. The user reads the plot, selects More for the full text, swipes to My list. Select on Play starts the movie. Leaving playback returns here with the button and bar updated.
3. On a Series card the user presses select. The series detail opens with focus on "Play S1 E1" or "Resume S2 E4". Swiping down reaches the season chips; moving across them changes the list below; swiping down again lands on the up-next row. Select on a row plays that episode.
4. Menu returns to the section with focus on the card or hero button that opened the detail.

iPadOS, macOS (regular width; an iPad at compact width uses the iOS flow and boards):
1. More info on the hero, More info in a card's menu, or a click on a series card replaces the content column with the detail. The sidebar stays. The toolbar's back link names the section.
2. Buttons sit under the art: Play or Resume, My list, Trailer. The plot and cast follow; for a series, season chips and the episode list follow.
3. Back, or Escape on a hardware keyboard, returns to the rows with the originating card scrolled into view.

iOS:
1. Info on the hero, More info in a card's menu, or a tap on a series card pushes the detail inside the Movies tab. The tab bar stays.
2. A round back button sits over the art. Buttons, plot, then seasons and episodes follow.
3. Back or a swipe from the left edge returns to the rows.

## Acceptance criteria

Each criterion is testable in isolation and has a stable id. Do not renumber.

### AC-1 Opening a movie detail
Given the Movies section with a `VODItem` as the hero and the same item as a card
When the user activates `movies.hero.info`, or opens the card menu and activates `movies.card.<id>.menu.info`
Then `title.root` exists with `title.name` equal to `VODItem.name`, `title.eyebrow` reads "Movie · <category name>" ("Movie" alone when `categoryID` is nil or matches no category), `title.poster` exists (the 0011/AC-8 text tile when `posterURL` is nil) and `title.backdrop` does not, `title.meta` does not exist, `title.loading` is present, `vodInfo(streamID:)` has been requested exactly once with the item's `streamID`, and `movies.hero` is no longer in the accessibility hierarchy.

### AC-2 Opening a series detail
Given a `Series` shown as a card in a Series section row other than Continue watching, in a grid, or as a 0012 title result
When the user selects it, or activates `series.hero.info` for the hero
Then `title.root` exists with `title.name` equal to `Series.name`, `title.eyebrow` reads "Series · <category name>" with the AC-1 nil rule, `title.poster` is shown as in AC-1, `title.loading` and `episodes.loading` are present, `title.play` reads "Play" and is disabled until `SeriesInfo` arrives, `seriesInfo(seriesID:)` has been requested exactly once, and no playback call (`load(_:)`) has been made. A Continue watching card keeps 0011/AC-10b's behaviour and plays the play target (AC-16a to AC-16d) directly.

### AC-3 Movie metadata line
Given `VODInfo` with `year` 2024, `duration` 7680, `genre` "Thriller", `rating` 7.4, `ageRating` "15" and a `name` containing "2160p"
When it arrives
Then `title.loading` is gone, `title.backdrop` replaces `title.poster` when `backdropURLs` is non-empty, and `title.meta` reads, in order, "2024", "2 h 08 min" (0011/AC-2b format), "Thriller", "7.4" with a star glyph, separated by dots, followed by `title.badges` "4K" and "15" per 0011/AC-2c; the shown rating is `VODInfo.rating ?? VODItem.rating`, formatted with one decimal ("8.0" for 8).

### AC-4a Missing metadata leaves gaps, not placeholders
Given `VODInfo` where `year`, `genre`, `rating`, `ageRating`, `plot`, `cast`, `director`, `trailerURL` are nil, `backdropURLs` is empty, `duration` is 5520, and `VODItem.rating` is nil
When it arrives
Then `title.meta` reads "1 h 32 min" only, with no dots, dashes or "Unknown"; `title.badges`, `title.cast`, `title.director` and `title.trailer` do not exist; `title.noPlot` reads "No description from your provider."; `title.backdrop` does not exist and `title.poster` exists.

### AC-4b Every field missing
Given the AC-4a `VODInfo` with `duration` nil as well
When it arrives
Then `title.meta` does not exist and the AC-4a assertions hold.

### AC-4c No poster either
Given the AC-4a `VODInfo` and a `VODItem` whose `posterURL` is nil
When rendered
Then `title.poster` does not exist and the 0011/AC-8 text tile is shown in the art area.

### AC-5 Plot clamp and More
Given the fixture plots of 1 200 characters (more than the clamp on every platform at the default text size) and 60 characters (fits on every platform), the clamp being more than four lines (movie on tvOS and iOS), five lines (movie on iPadOS and macOS) or two lines (series, every platform) at the platform's body size
When the detail is rendered
Then `title.plot` is clamped to that many lines and `title.more` exists; a plot that fits has no `title.more`. Activating `title.more` on tvOS presents `title.plotSheet` with the full text and Menu dismisses it with focus back on `title.more`; on iOS, iPadOS and macOS it removes the clamp in place and `title.more` disappears.

### AC-6 Cast and director
Given `VODInfo.cast` "Mira Holt, Jonas Reeve" and `director` "Sanna Weiss"
When rendered
Then `title.cast` reads "Cast" in the muted colour followed by the string as the provider gave it, clamped to two lines, and `title.director` reads "Director" followed by its value; an empty or whitespace-only value counts as nil (AC-4).

### AC-7 Play or Resume label for a movie
Given a `WatchProgressRecord` for the movie's title id with position p and duration d
When the detail is rendered
Then `title.play` reads "Resume" when 2% ≤ p/d < 95%, with `title.progress` at p/d and `title.remaining` reading "<n> min left" rounded up (0011/AC-4); otherwise, including no record, nil or zero duration, `title.play` reads "Play" and `title.progress` and `title.remaining` do not exist.

### AC-8 Playing a movie from the detail
Given the movie detail, `VODInfo` arrived or not
When the user activates `title.play`
Then playback starts per 0011/AC-10a with `movieURL(streamID:extension:)` using `VODInfo.containerExtension` when it has arrived and is non-nil, else `VODItem.containerExtension`; 0011/AC-16 position reporting applies; when the fake engine reports the item ended, or the test invokes the playback spec's leave action (a `stop()` on the fake until that spec exists), `title.root` is shown again with `title.play`, `title.progress` and `title.remaining` reflecting the record once the test observes the `ModelContext` save, and focus on `title.play` (tvOS). The return assertion is tested against the fake engine until the playback spec exists.

### AC-9a Add to My list from the detail
Given a title not in My list
When the user activates `title.myList`
Then a `ListEntryRecord` for the title id and `sourceID` with `kind` matching the title (movie or series) is inserted, the button shows the check glyph with label "Remove from my list", and `movies.hero.myList` or `series.hero.myList` for the same title shows the check state when the user returns; this is 0011/AC-3b from a second control. Two activations in quick succession leave the store in the state the button shows: zero records after an even count, one after an odd count.

### AC-9b Remove from My list from the detail
Given a title with one or more matching `ListEntryRecord`s
When the user activates `title.myList`
Then every matching record is deleted, the button shows the plus glyph with label "Add to my list", and the hero button reverses when the user returns.

### AC-10 Trailer
Given `VODInfo.trailerURL` or `SeriesInfo.trailerURL` non-nil on iOS, iPadOS or macOS
When rendered
Then `title.trailer` exists after `title.myList` and activating it calls the injected `openURL` with that URL exactly once; on tvOS, and whenever the URL is nil, `title.trailer` does not exist.

### AC-11 Info failure
Given `vodInfo(streamID:)` throws
When the detail is rendered
Then `title.loading` is replaced by `title.error` reading "Could not load details", or "You're offline. Connect to the internet and try again." when the error is `XtreamError.transport` with a code in the spec 0006/AC-8 set (`.notConnectedToInternet`, `.networkConnectionLost`, `.dataNotAllowed`), with `title.retry` requesting `vodInfo(streamID:)` once more; `title.play` stays enabled and AC-8 holds with `VODItem.containerExtension`; `title.myList` stays enabled.

### AC-12 Series metadata and seasons count
Given `SeriesInfo` with `year` 2019, `seasonCount` 3, `genre` "Drama", `rating` 8.1, `ageRating` "15", and `Series.name` "Northern Lights 2160p"
When it arrives
Then `title.meta` reads "2019", "3 seasons", "Drama", "8.1" with the star glyph, then the badge "15"; `seasonCount` 1 reads "1 season"; `seasonCount` 0 omits the seasons part; once the episode list has loaded, the seasons part counts the numbered season groups of AC-13 instead of `seasonCount`, so the header never disagrees with the chips; no "4K" badge is shown for a series (0011/AC-15a).

### AC-13 Season picker
Given episodes with `season` values 1, 2, 3, 0 and nil
When the list is rendered
Then `episodes.seasons` lists chips in the order "Season 1", "Season 2", "Season 3", "Specials" (season 0), "Other" (nil), each `episodes.season.<n>` with `episodes.season.specials` and `episodes.season.other` for the last two; the selected chip is the group containing the play target (AC-16a to AC-16d), on the 0.12 surface; `episodes.count` reads "<n> episodes" ("1 episode") for the selected group; with exactly one group `episodes.seasons` does not exist and `episodes.count` covers every episode.

### AC-13b Many seasons
Given 40 season groups
When the picker is rendered
Then `episodes.seasons` scrolls horizontally, the selected chip is within its visible bounds on open and after each switch, and on tvOS moving past the last chip leaves focus on it (no wrap).

### AC-14a Switching seasons by tap or click
Given the picker with Season 2 selected on iOS, iPadOS or macOS
When the user taps or clicks `episodes.season.3`
Then `episodes.list` shows only Season 3's episodes in 0016/AC-6b order, `episodes.count` updates, the list scrolls to its top, and the chip is selected.

### AC-14c Switching seasons by focus on tvOS
Given the picker with Season 2 selected on tvOS
When focus moves onto `episodes.season.3` and 300 ms pass on the injected clock
Then the AC-14a outcome holds; focus that leaves the chip before 300 ms does not switch. Provisional until the owner settles the open question on focus versus select.

### AC-14b Hardware keyboard on iPadOS and macOS
Given a hardware keyboard and focus on a season chip
When Left or Right is pressed
Then the adjacent chip is selected as AC-14a; Down moves focus to the first row, which shows the 0.12 surface and the `isSelected` trait as 0012/AC-20a; Return on a focused row plays it as AC-18; Up from the first row returns to the selected chip.

### AC-15 Episode row anatomy
Given an episode with `number` 4, `title` "Low Water", `duration` 2640, `plot` and `thumbnailURL` set
When rendered in `episodes.list`
Then `episodes.row.<episodeID>` shows the thumbnail at 16:9, the number in the muted tabular style, the title, "44 min" (0011/AC-2b format), and the plot clamped to one line on every platform; a nil `thumbnailURL` or a failed load (injected image loader) shows a tile in the logo placeholder colour with the number, or blank when `number` is nil; nil `plot` omits the line; nil `duration` omits the duration; nil `number` leaves the number column empty and the title comes from 0016/AC-6d.

Rules shared by AC-16a to AC-16e: a missing record, and a record with nil or zero duration, counts as 0%; records below 2% are ignored for every rule, including recency; an episode in progress wins over a later finished one even when the finished record is newer (rule AC-16a runs first); the `UP NEXT` badge marks the target whenever one exists, including AC-16d (a).

### AC-16a Play target: an episode in progress
Given episodes e1 to e6 in AC-13 group order (Season 1 to n, then Specials, then Other, each group in 0016/AC-6b order) with records e1 and e2 at 100%, e4 at 52% updated most recently, e5 at 30% updated earlier, e3 and e6 untouched
When `SeriesPlayTarget.resolve(episodes:progress:)` runs and the detail is rendered
Then the target is e4 with `resumes` true, `title.play` reads "Resume S<season> E<number>" of e4, and `episodes.row.<e4>.upNext` is the only `UP NEXT` badge in the list. The rule: among episodes with 2% ≤ p/d < 95%, the one whose record has the latest `updatedAt`; a tie on `updatedAt` goes to the episode earlier in group order.

### AC-16b Play target: after the last finished episode
Given episodes e1 to e6 in AC-13 group order with only e3 at 100% and e1, e2 untouched (test a), and with e6 at 100% updated most recently, e1 untouched and e2 to e5 at 100% (test b)
When `SeriesPlayTarget.resolve(episodes:progress:)` runs
Then (a) the target is e4, the first episode below 95% after the most recently updated record, not e1; (b) the order wraps and the target is e1; `resumes` is false in both.

### AC-16c Play target: nothing started
Given episodes with no records, the first group being Season 1 and a Specials group present
When `SeriesPlayTarget.resolve(episodes:progress:)` runs
Then the target is S1 E1, not a Special, with `resumes` false; records below 2% count as nothing started.

### AC-16d Play target: everything watched or nothing to play
Given every episode at or above 95% (test a), or zero episodes (test b)
When `SeriesPlayTarget.resolve(episodes:progress:)` runs and the detail is rendered
Then (a) the target is the first episode in group order with `resumes` false; (b) the target is nil, `title.play` is disabled and no `UP NEXT` badge exists.

### AC-16e Play label
Given a target with `resumes` false and `season` 2, `number` 3 (test a), `season` nil (test b), `number` nil (test c), both nil (test d)
When the detail is rendered
Then `title.play` reads "Play S2 E3", "Play E3", "Play S2" and "Play"; with `resumes` true the word is "Resume" with the same rules.

### AC-17 Episode progress and Watched
Given records for episodes at exactly 95%, 94.9%, 96%, 52% and 1%, one with no record, and one with a record whose duration is nil
When rendered
Then a record with p/d at or above 95% shows `episodes.row.<id>.progress` full and "Watched" in place of the duration; the 94.9% row shows the bar and its remaining minutes; the 52% row shows the bar at 52% and "<duration> · <n> min left"; the 1% row and the row with no record show no bar and the duration only; a record with nil or zero duration is treated as no record.

### AC-18 Playing an episode from the detail
Given a focused or tapped `episodes.row.<episodeID>`
When the user selects it, or activates `title.play` for the play target (AC-16a to AC-16d)
Then playback starts with `episodeURL(episodeID:extension:)` using the episode's `containerExtension` at the saved position per 0011/AC-10a, 0011/AC-16 reporting runs under the episode's title id, and when the fake engine reports the item ended or the AC-8 leave action is invoked, `title.root` is shown with the season containing the played episode selected, that row scrolled into view and focused (tvOS), and the row's bar, the `UP NEXT` marker and `title.play` updated once the test observes the `ModelContext` save.

### AC-19 Episodes failed, empty or partly skipped
Given `seriesInfo(seriesID:)` throws (test a), returns zero episodes (test b), or returns `skippedEpisodes` 1 (test c)
When the detail is rendered
Then (a) `title.loading` is removed with no `title.meta`, `title.plot` or `title.error` (AC-4a applies to the header), and `episodes.loading` is replaced by `episodes.error` reading "Could not load episodes", or the AC-11 offline wording for a `transport` error in the 0006/AC-8 set, with `episodes.retry` requesting once more and restoring both loading states, `title.play` disabled and `title.myList` enabled; (b) `episodes.empty` reads "No episodes available" and `title.play` is disabled; (c) `episodes.skipped` after the last row reads "1 episode could not be read from the provider's list." ("<n> episodes" for more than one) and is absent when `skippedEpisodes` is 0.

### AC-20 Leaving before the response
Given the detail opened and `vodInfo` or `seriesInfo` in flight
When the user leaves the detail
Then the stubbed client's awaited request observes `Task` cancellation (0016/AC-10a) before the dismissal completes, and resolving the stubbed request afterwards changes nothing a reopened detail for the same title shows: it requests again and shows `title.loading` until its own response.

### AC-21 Return to the originating card
Given the detail opened from a card in `movies.row.<categoryID>` scrolled to its 30th item, from the hero, or from a search result
When the user presses Menu (tvOS), activates `title.back` or presses Escape (iPadOS, macOS), or activates `title.back` or swipes from the left edge (iOS)
Then the section is shown with the same rows and scroll offsets, no `vodStreams` or `series` request is repeated, focus is on the card or hero button that opened the detail (tvOS), and the card is within the visible bounds (iOS, iPadOS, macOS); from a search result the Search section shows with its query retained (0012/AC-6c).

### AC-22 tvOS focus order and Menu on the series detail
Given the series detail on tvOS after `SeriesInfo` arrived with at least two season groups
When the view appears
Then focus is on `title.play`; swiping right reaches `title.myList`; swiping down from the button row lands on the selected season chip, and down again on the `UP NEXT` row when it is in the shown season, else the first row (with one group, down from the button row lands on that row directly); a focused chip or row has the Focus token; `shell.tabBar` and `shell.clock` do not exist; Menu from any element returns per AC-21 and does not move focus to the tab bar (0015/AC-6a applies to the section root only); the 0015/AC-5a timer keeps running while the detail is shown.

### AC-22b tvOS focus order on the movie detail
Given the movie detail on tvOS after `VODInfo` arrived with a plot that is clamped
When the view appears
Then focus is on `title.play`; swiping right reaches `title.myList`; swiping up from the button row reaches `title.more`; with a plot that fits, swiping up moves focus nowhere; `title.trailer` does not exist (AC-10); Menu returns per AC-21.

### AC-22c tvOS focus on an error
Given the detail on tvOS showing `title.error` or `episodes.error`
When the error appears
Then focus stays where it was if that element still exists, else moves to `title.play` when enabled; swiping down from the button row reaches `title.retry` or `episodes.retry`, and select on it requests again as AC-11 or AC-19.

### AC-23a Source removed while open
Given the detail open for a title of source S
When S's `SourceRecord` is deleted from the store
Then the detail is dismissed to the section, which applies 0011/AC-1, and no further request is made for S.

### AC-23b Credential gone while open
Given the detail open for a title of source S whose `SourceRecord` still exists
When the `vodInfo` or `seriesInfo` call for S finds no readable Keychain item
Then the detail stays open, `title.error` (or `episodes.error` for the episode list) reads "<source name>: waiting for its login to sync from iCloud" (0011/AC-13e copy) with Retry, `title.play` is disabled, and Retry or the app returning to the foreground reads the Keychain again.

### AC-23c Credential gone at Play
Given the detail open with its metadata loaded
When the user activates `title.play` or an episode row and `movieURL` or `episodeURL` finds no readable Keychain item, or the Keychain read fails with any other error
Then no playback starts, the loaded metadata stays, `title.playError` under the button row shows the AC-23b copy, and `title.play` stays enabled so the next activation reads the Keychain again.

### AC-24 Grouping and target are fast
Given 5 000 episodes across 40 seasons generated in the test with 1 000 progress values
When `SeasonGroup.group(_:)` and `SeriesPlayTarget.resolve(episodes:progress:)` run
Then each completes in under 50 ms in a debug `swift test` run on the reference machine named in the test (0016/AC-9 baseline); benchmark, not CI-gated, behind `ANTENNA_BENCHMARKS=1`.

### AC-25 Large season on device
Given a season of 2 000 episodes with thumbnails
When the list is scrolled end to end on Apple TV 4K (3rd generation) and iPhone 15
Then the Instruments Animation Hitches template records no hitch above 100 ms over the scroll, and the injected image loader's request count at the top of the list is at most the visible rows plus one screen (manual).

## Edge cases and failure modes

- Offline when the detail opens: AC-11 or AC-19 (a) with the offline wording; a movie's Play stays available and the player reports the failure (playback spec).
- Slow provider: the header renders from the list row at once (AC-1, AC-2); only the metadata block or episode list waits. No timeout of our own; `URLSession`'s applies.
- Huge catalogue: nothing here loads a list; the detail issues one info request per open.
- Malformed info: 0016/AC-12 yields nil fields, so AC-4 applies; `XtreamError.decoding` is a non-offline failure (AC-11).
- Credential not yet synced: a source without a readable Keychain item contributes no titles (0011/AC-13e), so no detail can open for it; a credential that becomes unreadable while the detail is open is AC-23b. A My list or progress record for such a title is neither listed nor deleted (0011 edge case).
- First launch, empty store: Movies and Series are absent (0011/AC-1); the detail is unreachable.
- Two sources with the same title: the detail is per `VODItem` or `Series`, so each card opens its own; records key on the full title id, which includes the host.
- An episode's record exists but the episode is no longer in the response: the record is ignored, not deleted (0011 edge case); the play target skips it.
- Records store title ids only, never URLs. Playable URLs are built on demand from the Keychain credential and never logged or stored (ADR-0003). Thumbnail, poster and backdrop URLs are provider art URLs and may be cached by the 0011/AC-18b cache.
- `WatchProgressRecord` duplicates from a CloudKit merge: 0011/AC-16's latest-wins rule feeds `WatchProgress`.
- Season labels use the group rules of AC-13 regardless of `seasonCount`, so a provider whose `seasons` array disagrees with its episodes is shown by what the episodes say.
- Source or credential changed during playback: on return AC-23a or AC-23b applies to the detail as if it had stayed open.
- Watched elsewhere: "Watched" and `UP NEXT` come only from progress records, so an episode seen outside the app shows as unwatched until it is played here; marking by hand is out (later spec).
- Duplicate episode ids: 0016/AC-6d skips them and counts them in `skippedEpisodes`, so AC-19 (c) reports them and `episodes.row.<episodeID>` is unique.
- Reduce Motion: the detail appears and the season switch happens without animation.
- VoiceOver: `title.root` reads name, then the metadata line, then the plot; an episode row reads "Episode <n>, <title>, <duration>, <n> minutes left" or "watched", and "up next" when marked; the season picker is a tab group.
- Dynamic Type at accessibility sizes: the metadata line wraps, episode rows grow, the clamp counts lines not points.

## Test plan

`TitleMetadata`, `SeasonGroup`, `SeriesPlayTarget` and the label rules are swift-testing tests in AntennaCore over 0016's fixtures and generated episodes. Records need the ADR's models and an in-memory `ModelContainer`. UI tests launch with `-antenna.uiTest`, a stubbed `XtreamClient` answering fixtures or throwing per code, a fake engine, an injected clock, an injected `openURL`, and an injected image loader that fails URLs whose path ends in `/fail.jpg`. Identifiers: `title.root`, `title.backdrop`, `title.poster`, `title.eyebrow`, `title.name`, `title.meta`, `title.badges`, `title.plot`, `title.more`, `title.plotSheet`, `title.noPlot`, `title.cast`, `title.director`, `title.play`, `title.myList`, `title.trailer`, `title.progress`, `title.remaining`, `title.back`, `title.playError`, `title.loading`, `title.error`, `title.retry`, `episodes.seasons`, `episodes.season.<n>`, `episodes.season.specials`, `episodes.season.other`, `episodes.count`, `episodes.list`, `episodes.row.<episodeID>`, `episodes.row.<episodeID>.progress`, `episodes.row.<episodeID>.upNext`, `episodes.loading`, `episodes.error`, `episodes.retry`, `episodes.empty`, `episodes.skipped`.

| Criterion | Layer | Test |
|-----------|-------|------|
| AC-1 | ui (stubbed client, both entry points) | TBD |
| AC-2 | ui (card, Continue watching card, search result, hero) | TBD |
| AC-3 | core (`TitleMetadata`) + ui | TBD |
| AC-4a | core (`TitleMetadata`) + ui | TBD |
| AC-4b | core (`TitleMetadata`) + ui | TBD |
| AC-4c | ui (fixture with nil poster) | TBD |
| AC-5 | ui (tvOS and iPad) | TBD |
| AC-6 | core (nil rules) + ui | TBD |
| AC-7 | core (label rule) + integration (records) | TBD |
| AC-8 | integration (fake engine, records) + ui (tvOS focus) | TBD |
| AC-9a | integration + ui | TBD |
| AC-9b | integration + ui | TBD |
| AC-10 | ui (injected `openURL`, iPad and tvOS) | TBD |
| AC-11 | ui (stubbed failures per code) | TBD |
| AC-12 | core (`TitleMetadata`) + ui | TBD |
| AC-13 | core (`SeasonGroup`) + ui | TBD |
| AC-13b | ui (iPad and tvOS, 40 groups) | TBD |
| AC-14a | ui (iPad tap, macOS click) | TBD |
| AC-14c | ui (tvOS, injected clock) | TBD |
| AC-14b | ui (macOS; iPad `typeKey`) | TBD |
| AC-15 | ui (fixture with nil fields) | TBD |
| AC-16a | core (`SeriesPlayTarget`) + ui (label and badge) | TBD |
| AC-16b | core (`SeriesPlayTarget`, tests a and b) | TBD |
| AC-16c | core (`SeriesPlayTarget`) | TBD |
| AC-16d | core (`SeriesPlayTarget`) + ui (disabled Play) | TBD |
| AC-16e | core (label rule, parameterised) | TBD |
| AC-17 | ui (records) | TBD |
| AC-18 | integration (fake engine, records) + ui (tvOS focus) | TBD |
| AC-19 | ui (tests a, b, c) | TBD |
| AC-20 | integration (stubbed client with a never-resolving request, recorded cancellation) | TBD |
| AC-21 | ui (three platforms, three origins) | TBD |
| AC-22 | ui (tvOS) | TBD |
| AC-22b | ui (tvOS) | TBD |
| AC-22c | ui (tvOS, stubbed failure) | TBD |
| AC-23a | integration (in-memory container) | TBD |
| AC-23b | integration (fake credential store) + ui | TBD |
| AC-23c | integration (fake credential store) + ui | TBD |
| AC-24 | core benchmark, `ANTENNA_BENCHMARKS=1` | TBD |
| AC-25 | device | manual |

## Dropped

- AC-4 (missing metadata): split into AC-4a, AC-4b and AC-4c; it bundled three scenarios and asserted geometry no identifier exposes.
- AC-9 (My list on the detail): split into AC-9a and AC-9b; add and remove are separate tests and the record `kind` was unstated.
- AC-14 (switching seasons): split into AC-14a (tap or click) and AC-14c (tvOS focus dwell); AC-14b was already taken by the keyboard criterion.
- AC-16 (play target and UP NEXT): split into AC-16a to AC-16e, one per rule plus the label; the single criterion held four rules and its fixture exercised only the first.
- AC-23 (source removed while open): split into AC-23a (record deleted, dismiss) and AC-23b (credential not readable, stay open and wait for sync); a credential that has not synced yet is not a removed source.

Retired ids are never reused.

## Required of other specs

- 0016: `VODInfo` and `SeriesInfo` gain `cast: String?`, `director: String?`, `rating: Double?` and `trailerURL: URL?` from `info.cast`, `info.director`, `info.rating` (0016/AC-2a loose number rule, 0 is nil) and `info.youtube_trailer`, where a value that passes the 0016/AC-2b URL rule is used as is, an 11-character YouTube id becomes `https://www.youtube.com/watch?v=<id>`, and anything else is nil. `Episode` gains `plot: String?` from `info.plot` and `thumbnailURL: URL?` from `info.movie_image` (AC-2b rule). Fixtures and AC-5 and AC-6a tests cover the new fields.
- 0011/AC-3c: `movies.hero.info` and `series.hero.info` are enabled and open the detail (AC-1, AC-2). The Out list drops title detail, episode picker and series detail.
- 0011/AC-9b and 0012/AC-9b: select on a series card outside Continue watching, or on a series result, opens the series detail (AC-2) instead of playing; the next-episode rule moves to `SeriesPlayTarget` (AC-16a to AC-16d), which 0011/AC-10b's Continue watching card uses to pick what it plays and for its "S<season> E<episode>" label.
- 0011/AC-17: the card menu gains `movies.card.<id>.menu.info` reading "More info" before the list toggle (AC-1); series cards omit it because select already opens the detail.
- 0015 Design section: "always visible there" becomes "always visible there, except on the title detail (0026/AC-22)". 0015/AC-17's swipe up does not apply on the detail.
- Playback engine spec (not yet written): leaving VOD playback that started from the detail returns to the detail (AC-8, AC-18), not to the section as 0011's edge case says for playback started from a card.

## Open questions

- Select on a series card opens the detail while select on a movie card still plays (0011/AC-3a). The alternative is detail for both, which is what Netflix and the Apple TV app do and would drop `movies.card.<id>.menu.info`.
- The tvOS detail hides the shell tab bar. Keeping it would match 0015's "always visible" rule but costs 104 pt of art and makes Menu ambiguous.
- Season chips switch on focus after 300 ms on tvOS (AC-14c, provisional). The alternative is select, one more press per switch.
- Trailer opens the provider's URL outside the app and is absent on tvOS. The alternative is an in-app web view, which App Review may read as linking to third-party content.
- `UP NEXT` as a filled accent badge (DR-3 deviation). An outlined badge keeps DR-3 intact but reads weaker among six outlined badges.
- Resume prefers the most recently updated in-progress episode, then the first unwatched episode after the most recently finished one (AC-16a, AC-16b). 0011/AC-9b had the simpler first-below-95% rule, which sends a user who skipped the pilot back to it.
- "No description from your provider." versus omitting the plot area entirely; the sentence tells the user where the gap comes from, which the research note asks for.
- "Other" as the label for episodes with no season. "Extras" or "Episodes" are alternatives.
