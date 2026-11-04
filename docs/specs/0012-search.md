# 0012. Search across channels, guide, movies and series

- Status: Accepted
- Date: 2026-11-03
- Depends on ADRs: 0002, 0003, 0005
- Platforms: iOS, iPadOS, macOS, tvOS
- Builds on specs 0013 (catalogue, digit matching), 0014 (guide queries), 0016 (titles), 0007 and 0010 (tuning and inline playback), 0009 (AC-21, open at a programme), 0011 (playing a title), 0015 (tvOS shell). Amends 0010 with `browse.laterProgramme` and a "Later:" fragment (AC-8). The matcher of AC-2 also serves 0010/AC-7, which calls it without a debounce.
- `SearchIndex(channels:, programmes:, titles:)` is built from whatever is loaded; `results(for query: String, now: Date)` evaluates on-air state and the horizon at query time. With 0014 or 0016 not yet delivering data the corresponding section is absent and its criteria are blocked, not failed.

## Design

Boards: `docs/design/boards/TV-Search.dc.html` (tvOS), `docs/design/boards/iPad-Search.dc.html` (iPadOS, macOS), `docs/design/boards/iPhone-Search.dc.html` (iOS). State boards in the same folder: `TV-Search-Recents.dc.html`, `iPhone-Search-Recents.dc.html`, `iPhone-Search-Empty.dc.html`, `iPad-Search-OneCharacter.dc.html`, `iPad-Search-Loading.dc.html`, `iPad-Search-GuideLoading.dc.html`, `iPad-Search-Capped.dc.html`.
Design rules that apply: DR-1 (tvOS, video keeps playing behind Search for the first 30 seconds, then 0015/AC-5a), DR-2, DR-3, DR-4, DR-5, DR-8, DR-10, DR-11, DR-13. Deviations: DR-6 and DR-7 do not apply to result rows (compact variant, number after the name, no progress bar); DR-4, badge text ("NOW", "SERIES") sits 2 to 4 pt under the caption floor because it is letter-spaced label text; DR-5, chips and recents rows extend their hit area to 44 pt.
States on the boards: field with a query, results in three sections with highlighted matches, NOW badge with the catch-up glyph at the trailing edge, SERIES badge, focused channel card (tvOS), scope chips with counts and recent searches in the sidebar (iPad, Mac), Cancel and clear (iPhone), "See all n" as the guide header's trailing control, the "Next 7 days" header prefix, the iPhone channel row chevron. tvOS uses the system search UI: the board's field row and keyboard are illustrative only.
States on the state boards, each drawn on one platform and reused on the others at that platform's type scale: recents with an empty field (`TV-Search-Recents.dc.html`, rows 64 pt at 29 pt body; `iPhone-Search-Recents.dc.html`, rows 44 pt at 17 pt body; both on the 0.06 surface with a muted clock glyph, header "Recent searches" on tvOS and the "Recent" eyebrow on iPhone); one character with an empty results area and no chips (`iPad-Search-OneCharacter.dc.html`; the same board stands for the empty-field results area on iPad and Mac, AC-12a); no results (`iPhone-Search-Empty.dc.html`: title at body size, hint in the muted caption, centred; the second caption line "Some sources are still loading." is present only in the AC-21 case); nothing loaded (`iPad-Search-Loading.dc.html`: "Channels are still loading" at body size, centred, no hint); guide loading with zero guide rows (`iPad-Search-GuideLoading.dc.html`: header "In the guide · loading" with "· loading" in the muted colour, no rows, Guide chip disabled); channel section cap (`iPad-Search-Capped.dc.html`: Channels chip selected, header count before the cap, last row "Showing 500 of 612" in the muted caption at 44 pt, number-prefix matches highlighted in the secondary line); disabled zero-count chip (`iPad-Search-Capped.dc.html` Series, `iPad-Search-GuideLoading.dc.html` Guide: muted text on the 0.04 surface, no bold); hardware-keyboard focused row on the 0.12 surface (first channel row of `iPad-Search.dc.html`, marked in a comment); focused poster card on tvOS as drawn on `TV-Movies.dc.html` (0011), reused here.
Not drawn: `browse.laterProgramme` on `iPad.dc.html` (one row under the 'Up next' list, same 13 pt muted secondary style as the up-next rows, text '<Today | Tomorrow | weekday> <time> · <title>') and the 'Later:' fragment of `browse.nowPlaying` on `iPhone.dc.html` (replaces the 'Next:' fragment in the 13 pt muted line). Both are drawn on the 0010 boards before the implementing PR opens.

## Problem

With hundreds of channels and thousands of titles, typing is faster than browsing, and TiviMate users list better search among their wishes. Antenna has no search. One field must find a channel, a programme later tonight and a movie, without the user choosing where to look first.

## Scope

In:
- One search field per platform: tvOS Search tab with the system search UI, iPad and Mac Search section with a toolbar field, iPhone Search tab.
- `SearchIndex` in AntennaCore over channel name, number and group; programme titles and subtitles within the horizon; movie and series titles.
- Results as you type in three sections with counts, matched text highlighted.
- Selecting a result: tune or play inline, open the guide at the programme, or play the title.
- Amends 0010: a 'later programme' row and fragment on the browse screens, set by AC-8 and cleared as AC-8 states.
- Scope chips on iPad, Mac and iPhone: All, Channels, Guide, Movies, Series. tvOS has no chips; the sections are always shown.
- Recent searches, local to the device, through an injected recents store (production: standard `UserDefaults`).
- No-results, loading and capped states.
- Hardware keyboard navigation on macOS and iPadOS.
- Accessibility identifiers with prefix `search.`.
- With no `SourceRecord`, 0006/AC-1 applies and Search is not reachable.

Out (explicitly):
- Searching descriptions, cast or genre.
- Voice search beyond the system keyboard's dictation (device check only).
- Reminders from a future programme result.
- Sync of recent searches (a record under ADR-0002; needs an ADR).
- Fuzzy matching beyond case and diacritic folding.

## User flow

1. The user opens Search. The field has focus with the keyboard (tvOS: the system search field and linear keyboard at the top, results below). Recent searches are listed when the field is empty.
2. From the second character on, results appear beneath: Channels, In the guide, Movies & series, each with a count, matched text highlighted.
3. tvOS: one downward swipe from the keyboard focuses the first result row of the first non-empty section. iPad, Mac, iPhone: chips under the field narrow to one section. iPhone: Cancel returns to the previous tab.
4. Selecting a channel tunes (tvOS) or plays inline (others). Selecting an on-air programme does the same for its channel. Selecting a future programme opens the Guide positioned on it (tvOS, 0009/AC-21); on other platforms the channel plays and the programme is shown as a later row. Selecting a title behaves as 0011.

## Acceptance criteria

Each criterion is testable in isolation and has a stable id. Do not renumber.

### AC-1 One character shows nothing
Given the field holds one non-whitespace character
When rendered
Then the results area shows neither results, counts, chips nor `search.empty`; on iOS and tvOS it also shows no `search.recents`; on iPadOS and macOS the sidebar `search.recents` stays visible.

### AC-2 Matching rules
Given channels "Northern News", "Nordic One" (group "Northern Report"), a programme "True North", a movie "Northbound"
When the query is "north", "NÖRTH" or "north news"
Then the query is trimmed, collapsed to single spaces, folded (case- and diacritic-insensitive) and split on spaces; a text matches when every token is a substring of its folded text; "north" and "NÖRTH" return all four (channels by name or group, programmes and titles by title or subtitle), "north news" returns "Northern News" only; highlight ranges (AC-5) cover each token's first occurrence; tokens are tested against one field at a time: a channel matches when its folded name alone or its folded group alone contains every token; "nordic report" matches nothing in the fixture.

### AC-3 Digit queries
Given channel 104, a movie "1917" and a programme titled "104"
When the query is "19"
Then Movies & series contains "1917" by text and Channels does not contain 104; when the query is "104", Channels contains 104 by number prefix and Movies & series is absent; leading zeros are stripped as in 0013/AC-12 and every channel whose number starts with the digits is returned; a programme titled "104" is matched by text only.

### AC-4a Section order
Given results in all three kinds
When rendered
Then sections appear as Channels, In the guide, Movies & series; a section with zero results is absent except as AC-21. Counts are shown before any display cap: on tvOS in every header (guide header "Next 7 days · <count>"); on iOS, iPadOS and macOS in the chips (AC-10), and in a section header only while that section's chip is active (AC-22). The guide header's trailing text is "Next 7 days · See all n" on iPadOS and macOS and "See all n" on iOS, in the accent colour as a link (DR-3).

### AC-4b Channel bands
Given channel results
When ordered
Then they are placed in their best band: (1) folded name starts with the full folded query, (2) a word of the name starts with the first token, (3) other name substring, (4) number prefix, (5) group-only; within a band alphabetical by name, then number, then source `sortOrder`.

### AC-4c Guide order
Given programme results
When ordered
Then they are by start time ascending so on-air rows come first, ties by channel number.

### AC-4d Title order
Given movie and series results
When ordered
Then title-prefix matches (full folded query) first, then the rest; alphabetical within each group, movies and series interleaved.

### AC-5 Highlight
Given a result whose text contains the query tokens
When rendered
Then each matched range is drawn with the accent colour at 35% opacity as its background with 3 pt radius, and no other text run in the row has a background tint; a highlighted run in a muted line is drawn in the primary text colour.

### AC-6a Channel result row
Given a channel result
When rendered
Then the row shows the logo or initials tile (0013/AC-7), the name, and a secondary line "<number> · Now: <title>" or "<number>" when no current programme exists; on iPhone a disclosure chevron at the trailing edge.

### AC-6b Select a channel on tvOS
Given focus on a channel result
When the user presses select
Then playback switches (0007/AC-9's `load` rule), Search dismisses to full screen (0015/AC-14) and a channel-change event is emitted (0008/AC-1).

### AC-6c Select a channel on iOS, iPadOS, macOS
Given a channel result
When the user selects it
Then the Live section is selected with All channels as the group when the channel is not in the current group, the channel plays inline (0010/AC-6), and the query is retained when the user returns to Search.

### AC-7 Guide result row
Given a programme result
When rendered
Then it shows "NOW" in the accent badge when on air at the query's `now`, else the start as locale short time if today or "<short weekday> <time>" otherwise, or "<short weekday> <d MMM>" when more than six days out; the title followed by " · <subtitle>" when non-empty; a secondary line "<channel> · <start> – <stop>" for on-air rows or "<channel> · Today | Tomorrow | <weekday>" for later ones; the catch-up glyph at the trailing edge when `hasCatchup` is true; labels use the user's calendar and time zone, injected in tests.

### AC-8 Selecting a guide result
Given a programme result
When the user selects an on-air programme
Then AC-6b or AC-6c applies to its channel; when the user selects a future programme on tvOS, 0009/AC-21 opens the Guide at it; on iPadOS and macOS at regular width the channel plays and `browse.laterProgramme` beneath up next reads "<Today | Tomorrow | weekday> <time> · <title>"; at compact width the "Next:" fragment of `browse.nowPlaying` becomes "Later: <time> · <title>"; both are removed when another channel is selected or the programme's stop passes.

### AC-9a Title result row
Given a movie or series result
When rendered
Then it shows the poster or the 0011/AC-8 fallback, the title, and a "SERIES" badge for series; on tvOS a focused poster card uses the 0011/AC-11 ring and focused rows use the Focus token.

### AC-9b Select a title
Given a title result
When selected
Then 0011/AC-3a (movie) or 0011/AC-9b (series) applies.

### AC-10 Scope chips
Given results on iPad, Mac or iPhone
When the user activates `search.chip.guide`
Then only the guide section is shown with every row and no cap control; `search.chip.movies` and `search.chip.series` show the titles section filtered to that kind with the header reading "Movies" or "Series"; `search.chip.channels` shows Channels only, still capped as AC-22; `search.chip.all` restores all sections; each chip's count equals the results in its section before any display cap and All equals their sum; a chip whose count is zero is disabled and reads "· 0"; Movies and Series chips are present only under 0011/AC-1.

### AC-11 Recent searches
Given twelve searches run by selecting a result, two differing only in case
When the field is empty on iOS and tvOS, or at any time on iPadOS and macOS
Then ten entries are listed newest first with the oldest unique entry dropped and folded duplicates collapsed to the most recent with its casing, written through the injected recents store and to no SwiftData record; shown in `search.recents` in the sidebar on iPad and Mac and in the results area on iPhone and tvOS; selecting one fills the field and runs the query; on tvOS the header "Recent searches" carries the entry count in the muted caption.

### AC-12a Clear
Given a query with results on iOS, iPadOS or macOS
When the user activates `search.clear`
Then the field empties and keeps focus; on iOS the results area shows `search.recents`; on iPadOS and macOS the results area is empty as `iPad-Search-OneCharacter.dc.html`.

### AC-12b Menu on tvOS
Given results on tvOS
When the user presses Menu from a result
Then focus returns to the system keyboard; Menu from the keyboard shows the tab bar (0015/AC-6); tvOS has no clear control and the keyboard's delete key edits the query.

### AC-12c Escape on iPad and Mac
Given a hardware keyboard on iPadOS or macOS and focus in the field
When the user presses Escape
Then with a non-empty field the field clears and keeps focus (results are replaced as AC-12a); with an empty field focus moves to `search.recent.0`, or stays in the field when there are no recents.

### AC-12d Cancel on iPhone
Given the Search tab
When the user activates `search.cancel`
Then the keyboard dismisses and the tab selected before Search is shown, or Live when there was none.

### AC-13 No results
Given a query that matches nothing and every source has finished loading
When rendered
Then `search.empty` reads "No results for “<query>”" and "Check the spelling or try a channel number." and no section headers are shown.

### AC-14 Index performance
Given 20 000 channels, seven days of guide for 2 000 channels and 10 000 titles generated in the test
When the index is built and a query runs
Then the build completes within 1 500 ms and the query within 300 ms in a debug `swift test` run on the reference machine named in the test (same baseline as 0013/AC-14), and the folded index holds at most 150 MB resident; benchmark, not CI-gated.

### AC-15 tvOS search UI
Given the Search tab on tvOS
When shown
Then the system search field and its linear keyboard are at the top with results below, and one downward swipe from the keyboard focuses the first result row of the first non-empty section; with an empty field the swipe focuses `search.recent.0`, or nothing when there are no recents.

### AC-16 Group-only match
Given a channel whose group matched but whose name did not
When rendered
Then the secondary line reads "<number> · Matches <group>" with the group match highlighted, replacing the "Now:" text; the name is not highlighted.

### AC-17 Debounce
Given two or more characters
When 300 ms pass on the injected clock after the last keystroke
Then results reflect the full query; a keystroke within 300 ms cancels the pending query.

### AC-18 Guide horizon
Given programmes that ended before `now`, within seven days, and beyond seven days
When `results(for:now:)` runs
Then only programmes with stop after `now` and start before `now` plus seven days are returned, or up to the guide's horizon end if sooner.

### AC-19 Guide section cap
Given more than four guide results
When rendered in the All view on iOS, iPadOS or macOS
Then four rows are shown and the header's trailing control `search.section.guide.seeAll` reads "See all n"; activating it shows every guide row in place (same as the Guide chip). On tvOS the guide section is not capped: every row is shown, the header reads "Next 7 days · n" and there is no `search.section.guide.seeAll`.

### AC-20a Down arrow
Given a hardware keyboard on macOS or iPadOS and focus in the field
When the user presses the down arrow
Then focus moves to the first result row, which shows the 0.12 surface and the `isSelected` trait; Up from the first result returns to the field; Left and Right move across poster cells. Left and Right also move across columns of the channel and guide grids; Down from a section's last row moves to the next section's first row.

### AC-20b Return
Given a focused result
When the user presses Return
Then the result is selected as AC-6c, AC-8 or AC-9b.

### AC-20c Command-F
Given focus anywhere in the Search section
When the user presses Command-F
Then the field has focus.

### AC-21 Loading
Given no source has finished loading and the field holds two or more characters
When results would render
Then `search.empty` reads "Channels are still loading" instead of AC-13's text; with some sources loaded and no results, AC-13's text is followed by "Some sources are still loading."; while any source's guide `loadingState` is `.loading` and the guide section has zero rows, its header reads "In the guide · loading".

### AC-22 Section cap
Given 600 channel results
When rendered
Then 500 rows are shown, the header count reads 600, and `search.section.channels` ends with a row reading "Showing 500 of 600".

## Edge cases and failure modes

- Programme boundary while results are shown: NOW badge and ordering update on the next query or within five seconds via the injected clock.
- Sources with a missing credential contribute no channels or titles (0004/AC-10).
- A programme on air on one channel and later on another: two rows, NOW first.
- Whitespace-only queries are empty. Queries are truncated to 100 characters for matching.
- Diacritic folding uses `String.folding(options:)` with `.diacriticInsensitive` and `.caseInsensitive`.
- Channels or programmes with an empty name or title are not indexed.
- Same number or name from two sources: both rows appear, source `sortOrder` as tiebreak.
- Index rebuild after a source or guide refresh runs off the main actor in the app layer; results reflect it on the next keystroke.
- Offline: search runs over the loaded index; nothing is fetched; logo and poster fallbacks apply.
- Dynamic Type at accessibility sizes: rows grow, highlights follow the glyph bounds.
- `search.result.<id>` uses `Channel.rowKey`, the programme's `GuideKey` plus start, or the 0016 title id, never a stream URL (ADR-0003).
- Reduce Motion: results appear without animation.
- VoiceOver: section headers are headings; a result reads its section, name and secondary line.

## Test plan

`SearchIndex`, matching, bands, highlight ranges, date labels, horizon, cap counts and the AC-14 benchmark are swift-testing tests in AntennaCore over generated fixtures with an injected calendar and time zone. Recents use the injected store. Identifiers: `search.field`, `search.clear`, `search.cancel`, `search.chips`, `search.chip.all`, `search.chip.channels`, `search.chip.guide`, `search.chip.movies`, `search.chip.series`, `search.section.channels`, `search.section.guide`, `search.section.guide.seeAll`, `search.section.titles`, `search.result.<id>`, `search.recents`, `search.recent.<index>`, `search.empty`.

| Criterion | Layer | Test |
|-----------|-------|------|
| AC-1 | ui | TBD |
| AC-2 | core | TBD |
| AC-3 | core | TBD |
| AC-4a | ui | TBD |
| AC-4b | core | TBD |
| AC-4c | core | TBD |
| AC-4d | core | TBD |
| AC-5 | core (ranges) + ui | TBD |
| AC-6a | ui | TBD |
| AC-6b | ui (tvOS, fake engine) | TBD |
| AC-6c | ui (iPad) | TBD |
| AC-7 | core (labels) + ui | TBD |
| AC-8 | ui (tvOS and iPad and iPhone) | TBD |
| AC-9a | ui | TBD |
| AC-9b | ui | TBD |
| AC-10 | ui | TBD |
| AC-11 | integration (fake store) + ui | TBD |
| AC-12a | ui (iOS) | TBD |
| AC-12b | ui (tvOS) | TBD |
| AC-12c | ui (macOS) | TBD |
| AC-12d | ui (iOS) | TBD |
| AC-13 | ui | TBD |
| AC-14 | core benchmark | TBD |
| AC-15 | ui (tvOS) | TBD |
| AC-16 | core (match field) + ui | TBD |
| AC-17 | ui (injected clock) | TBD |
| AC-18 | core | TBD |
| AC-19 | ui | TBD |
| AC-20a | ui (macOS; iPad `typeKey`) | TBD |
| AC-20b | ui | TBD |
| AC-20c | ui | TBD |
| AC-21 | ui (stubbed sources) | TBD |
| AC-22 | core (cap) + ui | TBD |

## Open questions

- Programme descriptions behind a toggle, given index size?
- Rank channels the user watches often above alphabetical?
