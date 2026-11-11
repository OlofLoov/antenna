# Design

## Context

Boards: `openspec/specs/design-system/boards/TV-Title.dc.html`, `TV-Series.dc.html`, `iPad-Title.dc.html`, `iPad-Series.dc.html`, `iPhone-Title.dc.html`, `iPhone-Series.dc.html`.

Design-system requirements that apply: "Focus is the lifted white card", "One accent color", "Text stays above the platform caption floor", "Targets are large enough to hit", "A current programme always shows its progress", "Accessibility identifiers follow the board", "Nothing fake and nothing bundled", "Text meets contrast minimums", "Loading shows real progress per step".

Not drawn yet: loading bars for the details, loading episode rows, the two error states, no episodes, the Apple TV full-description sheet, the expanded description, the focused episode row and season chip on Apple TV, the grayed-out Play button, and the Play error line.

## Goals / Non-Goals

**Goals:**
- Grouping, the play target and the details line are pure functions in AntennaCore, so the rules are tested without UI.
- One play-target rule for the page, the poster and Continue watching.

**Non-Goals:**
- Autoplaying the next episode.
- Caching title details between launches.

## Decisions

- Xtream client additions: `VODInfo` and `SeriesInfo` gain `cast`, `director`, `rating` (0 is nil) and `trailerURL` (a valid URL as is, an 11-character YouTube id becomes `https://www.youtube.com/watch?v=<id>`, else nil), and `Episode` gains `plot` and `thumbnailURL`.
- Movies and series browsing enables `movies.hero.info` and `series.hero.info`, adds "More info" before the list toggle in movie poster menus, and its Continue watching card uses `SeriesPlayTarget`. The shell's swipe-up does not apply on the page.
- Details line format: "2024 · 2 h 08 min · Thriller · ★ 7.4", then the 4K and age badges.
- Pure functions in AntennaCore: `TitleMetadata` (details line and labels), `SeasonGroup.group(_:)` (Season 1 to n, Specials for 0, Other for none, each in the Xtream client's order), and `SeriesPlayTarget.resolve(episodes:progress:)` returning the episode and whether it resumes, over a `WatchProgress` value (`titleID`, `position`, `duration`, `updatedAt`).
- Play target rules: below 2% is ignored everywhere. A missing record or one with no duration counts as 0%. In progress is 2% to under 95%, latest `updatedAt` wins, ties go to the earlier episode. Otherwise the first episode under 95% after the latest-updated record, wrapping. Label forms: "Play S2 E3", "Play E3", "Play S2", "Play", and the same with "Resume".
- Records follow `add-watch-progress-sync`, with episode positions under the episode's own title id. CloudKit can leave duplicates, so read the latest, and removing from My list deletes every match. Records hold ids, never URLs. Playable URLs are built on demand from the Keychain credential and never logged or stored. Art URLs may use the poster cache from movies and series browsing.
- Display rules: rating is `VODInfo.rating ?? VODItem.rating`, one decimal. Empty or whitespace fields count as missing. The seasons count follows the season groups once episodes load. The description clamps at four lines (movie on tvOS and iOS), five (movie on iPad and Mac) or two (series). Episode rows take one line. The container extension comes from `VODInfo`, else `VODItem`.
- Apple TV focus: Play first, My list to the right, More above when the description is clamped, season chip then up-next row below. The tab bar and clock are hidden and the shell's idle timer keeps running. On an error focus stays put or moves to Play, with Retry below the buttons. Season chips switch after 300 ms of focus on an injected clock (provisional).
- Board deviations: UP NEXT is a filled accent badge and the eyebrow is accent (deviates from "One accent color"); season chips are 34 pt (iPad, Mac) and 30 pt (iPhone) with a 44 pt tap area, and the More link has a 44 pt tap area (see "Targets are large enough to hit"); Play is styled as on the Movies banner (see "Focus is the lifted white card"); badges and eyebrow sit up to 2 pt under the caption floor (deviates from "Text stays above the platform caption floor"); progress is never shown without its bar ("A current programme always shows its progress").
- Leaving before a reply cancels the request as the Xtream client does, and a late reply changes nothing. A deleted source dismisses the page with no further request. Trailer opens through an injected `openURL`. Identifier prefixes `title.` and `episodes.`.
- Budgets: grouping and play target each under 50 ms for 5 000 episodes in 40 seasons with 1 000 progress values (debug `swift test`, `ANTENNA_BENCHMARKS=1`, the Xtream client's baseline). A 2 000-episode season scrolls with no hitch over 100 ms on Apple TV 4K (3rd generation) and iPhone 15, and image requests at the top stay within the visible rows plus one screen.

## Implementation decisions

Made while building the change, without the owner available. Each can be revisited in review.

- **Xtream keys.** Cast is `info.cast`, else `info.actors`. Director is `info.director`. Rating is `info.rating` as number or string, 0 counts as none. The trailer is `info.youtube_trailer`, else `info.trailer`; an 11-character id uses the YouTube id alphabet (letters, digits, `-`, `_`). An episode's description is `info.plot`, else `info.overview`, and its picture `info.movie_image`, else `info.cover_big`, under the poster URL rules.
- **Rating on the list row.** `ShelfTitle` keeps the list row's rating, so the page can fall back to it as the decision above asks. Series list rows carry none.
- **Season order and wrapping.** The play target walks episodes in the picker's order: seasons by number, then Specials, then Other. So finishing the last episode of the last season offers the first special before wrapping to Season 1. Ties between finished episodes go to the earlier one, as they do for episodes in progress.
- **Seasons count.** The details line counts numbered seasons only, so Specials and Other do not add a season.
- **Opening the page.** The page shows over its section instead of being pushed on a navigation stack. The section stays alive underneath, hidden and disabled, so going back finds the same rows at the same scroll position without reloading. iPhone keeps the tab bar and goes back with the Back button or a swipe in from the left edge; iPad and Mac keep the sidebar, with Back in the toolbar; Apple TV covers the screen and Menu goes back. Picking another section or list in the iPad and Mac sidebar closes the page.
- **Apple TV bar.** The shell leaves out the tab bar layer, clock included, while a page is open, so there is nothing to swipe up to. Menu on the page closes it before the shell sees the press.
- **One call for a series.** A series' details and episodes come from the same `get_series_info` call, so a failure shows "Could not load episodes" and the details keep the name and category.
- **No description.** A title without a description shows no description area. `iPhone-Title` draws "No description from your provider.", but the requirement says a missing field is simply missing, so the requirement wins.
- **More.** On iPhone, iPad and Mac, More shows the whole description in place. On Apple TV it opens a sheet (`title.plotSheet`), as `TV-Title` notes.
- **Continue watching.** A series card still plays at once, now picking its episode with `SeriesPlayTarget`, the page's rule. The banner's Play for a series also still plays at once; only More info opens the page. A movie card in Continue watching gets More info in its menu, as a poster does.
- **Trailer in UI tests.** A Debug build launched with `-ui-testing-shelf` records the links the page opens and shows the last one in `shelf.debug.opened`, so tests check Trailer without leaving the app.
- **Benchmark.** The 5 000-episode benchmark spreads episodes over 40 seasons and saves 1 000 positions, a third of them in progress. It runs with `ANTENNA_BENCHMARKS=1` on the CLT toolchain.

## Risks / Trade-offs

The owner answers each one that changes a requirement before the change is accepted.

- Open question: a series poster opens its page while a movie poster still plays. Open the page for both, as Netflix and the Apple TV app do? Changes "Open a movie's page" and "Open a series' page".
- Open question: the Apple TV page hides the tab bar, against the shell's "always visible" rule. Can be decided during implementation.
- Open question: seasons switch on Apple TV after resting on a chip for 300 ms, or on select (one more press each time)? Changes "Pick a season".
- Open question: Trailer opens outside the app and is missing on Apple TV. An in-app web view may read to App Review as linking third-party content (guideline 5.2.3). Changes "Trailer".
- Open question: UP NEXT as a filled accent badge or outlined. Can be decided during implementation.
- Open question: Play prefers the episode last in progress, then the one after the last finished. Movies and series browsing started at the first unwatched, which sends someone who skipped the pilot back to it. Changes "Play starts the right episode".
- Open question: "No description from your provider." or no description area at all? Changes "What the title is about".
- Open question: "Other" for episodes with no season, or "Extras" or "Episodes"? Can be decided during implementation.
