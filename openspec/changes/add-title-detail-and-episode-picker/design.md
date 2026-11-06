# Design

## Context

Boards: `openspec/specs/design-system/boards/TV-Title.dc.html`, `TV-Series.dc.html`, `iPad-Title.dc.html`, `iPad-Series.dc.html`, `iPhone-Title.dc.html`, `iPhone-Series.dc.html`.

Design-system requirements that apply: "Focus is the lifted white card", "One accent color", "Text stays above the platform caption floor", "Targets are large enough to hit", "A current programme always shows its progress", "Accessibility identifiers follow the board", "Nothing fake and nothing bundled", "Text meets contrast minimums", "Loading shows real progress per step".

Not drawn yet: loading bars for the details, loading episode rows, the two error states, no episodes, the Apple TV full-description sheet, the expanded description, the focused episode row and season chip on Apple TV, the greyed-out Play button, and the Play error line.

Decisions this builds on: adr-0001 (hardware playback path for MPEG-TS), adr-0002 (SwiftData with private CloudKit for sync), adr-0003 (credentials in iCloud Keychain), adr-0005 (AntennaCore is UI-free), adr-0006 (no free tier, paid unlock only).

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
- Records follow `add-watch-progress-sync`, with episode positions under the episode's own title id. CloudKit can leave duplicates, so read the latest, and removing from My list deletes every match. Records hold ids, never URLs. Playable URLs are built on demand from the Keychain credential and never logged or stored (adr-0003). Art URLs may use the poster cache from movies and series browsing.
- Display rules: rating is `VODInfo.rating ?? VODItem.rating`, one decimal. Empty or whitespace fields count as missing. The seasons count follows the season groups once episodes load. The description clamps at four lines (movie on tvOS and iOS), five (movie on iPad and Mac) or two (series). Episode rows take one line. The container extension comes from `VODInfo`, else `VODItem`.
- Apple TV focus: Play first, My list to the right, More above when the description is clamped, season chip then up-next row below. The tab bar and clock are hidden and the shell's idle timer keeps running. On an error focus stays put or moves to Play, with Retry below the buttons. Season chips switch after 300 ms of focus on an injected clock (provisional).
- Board deviations: UP NEXT is a filled accent badge and the eyebrow is accent (deviates from "One accent color"); season chips are 34 pt (iPad, Mac) and 30 pt (iPhone) with a 44 pt tap area, and the More link has a 44 pt tap area (see "Targets are large enough to hit"); Play is styled as on the Movies banner (see "Focus is the lifted white card"); badges and eyebrow sit up to 2 pt under the caption floor (deviates from "Text stays above the platform caption floor"); progress is never shown without its bar ("A current programme always shows its progress").
- Leaving before a reply cancels the request as the Xtream client does, and a late reply changes nothing. A deleted source dismisses the page with no further request. Trailer opens through an injected `openURL`. Identifier prefixes `title.` and `episodes.`.
- Budgets: grouping and play target each under 50 ms for 5 000 episodes in 40 seasons with 1 000 progress values (debug `swift test`, `ANTENNA_BENCHMARKS=1`, the Xtream client's baseline). A 2 000-episode season scrolls with no hitch over 100 ms on Apple TV 4K (3rd generation) and iPhone 15, and image requests at the top stay within the visible rows plus one screen.

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
