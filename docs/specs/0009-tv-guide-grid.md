# 0009. Apple TV guide grid

- Status: Draft (two spec-reviewer rounds, every finding applied)
- Date: 2026-11-03
- Depends on ADRs: 0001, 0002, 0003, 0005
- Platforms: tvOS
- Builds on specs 0013 (channel order, initials), 0014 (guide queries, horizon, loading state, overlap resolution), 0015 (shell, Menu, pause behind tabs), 0008 (current group, bar after tuning, remaining-time formatter, resolution mapping), 0012 (requests AC-21).
- Blocked on the playback engine spec (not yet written) for an observable state, `play()` on resume (AC-1b) and presentation height (AC-8).

## Design

Boards: `docs/design/boards/TV-Guide.dc.html` for the playing state, `TV-Guide-Placeholders.dc.html`, `TV-Guide-Future.dc.html` and `TV-Guide-Empty.dc.html` for the other states. Same frame, tokens and type on all four; the state boards show Watch alone, as AC-8c requires.
Design rules that apply: DR-1, DR-2, DR-3, DR-4, DR-5, DR-8, DR-11, DR-12, DR-13. Deviations: DR-6 does not apply (the 296 pt channel cell is number, logo and name); DR-7, in the grid the now line stands in for the progress bar and the panel shows the bar; DR-2, Watch is drawn white on the board for emphasis but ships on the 0.12 surface and takes the Focus token only when focused; DR-3, the panel eyebrow is accent for "Now" only, muted otherwise; DR-4, initials in the 64 by 42 logo tile are 14 pt because the tile is 42 pt tall.
States on the boards:
- `TV-Guide`: PiP with the live dot and caption, panel for the focused on-air programme with `guide.panel.progress` (4 pt, accent fill on the 0.12 track, under the meta line), day chips (Today then short weekday names; selected chip 0.12 surface, weight 600, radius 8; unselected chips muted), time header, now line with pill, past blocks (muted text on 0.06), now and future blocks (primary text on 0.08), a block clipped at the window start with the ◂ marker, the focused block as the white card with a second line "<start> – <stop> · Live", the playing channel's name at weight 600, clock in the eyebrow row. Remind me and Start over are drawn here and hidden until a reminders spec exists.
- `TV-Guide-Placeholders`: placeholder rows "Loading guide…" (`guide.loading.<rowKey>`), "No programme information" (`guide.noGuide.<rowKey>`) and "Guide unavailable" (`guide.failed.<rowKey>`), each one block across the window, muted 24 pt on the 0.06 surface; an unfocused gap block (0.06 surface, unlabelled); a focused gap as the white card with the time line only; the panel for a gap (muted eyebrow "Today 21:00 · Arena HD", title "No programme information", meta, no summary, no progress bar, Watch only).
- `TV-Guide-Future`: the window scrolled to 21:00 with the now line at 783 pt; a focused future programme as the white card with the second line without "· Live"; its panel with the muted eyebrow "Today 22:00 · Sport One", no progress bar and Watch only; PiP while the engine is not playing (ground colour, caption, no live dot). The panel for a past programme is the same panel with a past start in the eyebrow.
- `TV-Guide-Empty`: `guide.empty` "No channels in <group>" muted 24 pt centred in the grid area; the Today chip focused (Focus token, weight 600, radius 8) with the other chips muted; time header and now line kept; PiP playing; the panel shows only the clock because no block has focus.
Not drawn: nothing.

## Problem

A guide grid is how TV viewers plan the evening: what is on across channels at a glance, and what comes later. Antenna's Guide tab is a placeholder. The parser exists; 0014 delivers the data; nothing renders it.

## Scope

In:
- Guide tab (0015) with the PiP box and a detail panel.
- Grid for the current group (0008/AC-15), time header in 30-minute columns, now line.
- Programme blocks sized by duration, past blocks muted, clipped blocks marked, gaps as unlabelled blocks.
- Focus model inside the grid, to the chips, and between grid and panel.
- Tuning from the grid.
- Day chips across the horizon.
- Opening at a programme requested by Search (AC-21).
- Clock.
- Accessibility identifiers with prefix `guide.`.

Out (explicitly):
- Reminders and the Remind me action.
- Recording, catch-up playback, Start over (hidden, as 0007/AC-14).
- Guide on iOS, iPadOS and macOS (no board yet).
- Group switching inside the guide; the current group is changed in the overlay (0007/AC-22) or by AC-21.
- Guide download, storage and refresh (0014).
- Programme search (0012).

## User flow

1. From the shell's tab bar (0015) the user selects Guide. The current channel keeps playing in the PiP box.
2. Focus starts on the block covering now in the playing channel's row. The panel shows it.
3. Moving focus across blocks updates the panel. Moving to a block outside the window scrolls so that block's start column is first. Up from the first row reaches the day chips.
4. Select on an on-air programme tunes to that channel and returns to full screen. Select on any other block moves focus to Watch.
5. Day chips move the window to the same local time of day on that date.
6. Menu from the grid or a chip shows the tab bar (0015/AC-6); Menu from the panel returns focus to the grid.

## Acceptance criteria

Each criterion is testable in isolation and has a stable id. Do not renumber.

### AC-1 PiP keeps playing
Given the engine is `.playing`
When the Guide tab is shown
Then the same engine instance continues in the 480 by 270 pt box with `guide.pip.liveDot` and `guide.pip.caption` "<number> <name>", with no `pause()` call.

### AC-1b PiP resumes a paused engine
Given the engine was paused by 0015/AC-5a
When the Guide tab is shown
Then `play()` is called once; until the engine reports `.playing` the box shows the ground colour with the caption.

### AC-2 Rows are the current group's channels
Given the current group has 42 channels
When the grid is scrolled from top to bottom
Then `guide.row.<rowKey>` is exposed for each of the 42 channels in 0013/AC-6 order and no others, each 84 pt tall, with `guide.channel.<rowKey>` showing number, logo or initials tile and name; the playing channel's name is drawn at weight 600.

### AC-3 Window and now line
Given the time is 21:34
When the guide is laid out
Then the visible window is four columns (two hours) whose first column starts at the half-hour boundary at or before now minus 90 minutes (20:00); the header shows 30-minute columns of 370 pt labelled in the locale short time style; the now line's left edge with a pill reading the current time is at 300 + 2 × 370 + 34/30 × 370 = 1459 pt from the leading edge of the channel column.

### AC-4 Block width
Given the window of AC-3
When blocks are laid out
Then a block's width is minutes / 30 × 370 − 4 pt (the 4 pt gap): 1476 for 120 minutes, 551 for 45, 366 for 30; a block narrower than 40 pt is widened to 40 and the following block's leading edge moves right by the difference while its trailing edge stays at its stop time (applied recursively); the now line and AC-16 use programme times, not drawn edges.

### AC-5 Clipped start marker
Given a programme that started before the visible window
When rendered
Then its block starts at the window's left edge, its width is computed from the window start, it begins with the ◂ marker before the title, and its accessibility value ends with ", started earlier".

### AC-6 Block state
Given programmes that ended, are on air, or start later
When rendered
Then each block's accessibility value starts with "past", "now" or "future"; the focused block shows a second line "<start> – <stop>" followed by " · Live" for an on-air programme.

### AC-7 Initial focus
Given the Guide tab is opened without a request (AC-21)
When shown
Then focus is on the block in the playing channel's row that covers now (programme, gap or placeholder) with the row scrolled into view; if the playing channel is not in the group, focus is on the block covering now in the first row.

### AC-8a Panel text
Given focus on a block
When the panel is rendered
Then `guide.panel.eyebrow` reads "Now · <channel>" (accent) or "<Today | Tomorrow | weekday> <start> · <channel>" (muted), `guide.panel.title` the title or "Untitled", `guide.panel.meta` start and stop in the locale short style, the duration from 0008/AC-5's formatter without "left" ("2 h", "45 min", "1 h 30 min"), `Programme.category` when present, and 0008/AC-7's resolution text only for the playing channel after the engine reports; `guide.panel.summary` the summary or nothing when nil.

### AC-8b Panel progress
Given focus on an on-air programme
When the panel is rendered
Then `guide.panel.progress` shows elapsed over duration within 0.01; it is absent for other blocks.

### AC-8c Panel actions
Given focus on any block
When the panel is rendered
Then `guide.watch` is present and Start over and Remind me are absent.

### AC-9 Select on an on-air programme
Given focus on a block whose programme is on air
When the user presses select
Then if the channel is not playing, `load(_:)` is called once with its `streamURL`, the guide is dismissed to full screen and a channel-change event is emitted; if it is already playing the guide is dismissed without `load` unless the engine state is `.failed`, in which case `load` is called (as 0007/AC-9a).

### AC-10 Select on any other block
Given focus on a future, past or gap block
When the user presses select
Then focus moves to `guide.watch` and the channel is unchanged; Watch tunes the channel as AC-9's first branch.

### AC-11a Day chips
Given a horizon from 2026-11-03 06:00 to 2026-11-10 06:00 and today 2026-11-03 in the user's time zone
When the guide is shown
Then `guide.days` lists one chip per calendar day from today to the day containing `horizon.end` minus one second, labelled Today then short weekday names from `Calendar`, horizontally scrollable with the selected chip visible; days before today are not listed; a horizon starting after today selects the horizon's first day.

### AC-11b Selecting a chip
Given a selected chip and a window at local time T
When the user selects another chip
Then the window moves to T on that date, clamped per AC-13; when T does not exist on that day (DST), the next existing minute is used.

### AC-11c Chip follows scrolling
Given the user scrolls the window across local midnight
When the first visible column changes day
Then the selected chip changes to that day.

### AC-12 Placeholder rows
Given a channel whose `loadingState` is `.noData`, `.unavailable` or `.loaded` with zero programmes in the horizon; `.loading`; or `.failed` with no previous guide
When its row is rendered
Then one focusable block spanning the visible window reads "No programme information" (`guide.noGuide.<rowKey>`), "Loading guide…" (`guide.loading.<rowKey>`) or "Guide unavailable" (`guide.failed.<rowKey>`); select on it behaves as AC-10 unless it covers now, then as AC-9; a `.failed` source whose previous guide is still queryable (0014/AC-11a) renders its programmes.

### AC-13 Horizontal bounds
Given the horizon of AC-11a
When the user scrolls left or right
Then the first visible column is never before the horizon start's half-hour boundary, and the last column is the one whose start is strictly before the horizon end.

### AC-14a First frame
Given All channels with 20 000 channels and seven days of guide
When the Guide tab is shown
Then the first frame with the grid visible is drawn within one second on an Apple TV 4K (3rd generation); the core layout function returns only items within the visible window plus one row and one column of slack.

### AC-14b Scrolling
Given the same fixture
When rows are scrolled continuously for 20 seconds
Then Instruments reports no animation hitch longer than one frame.

### AC-15 Clock-driven updates
Given the guide is open
When the injected clock advances one minute, or passes a programme's stop
Then the now line's offset increases by 370/30 pt per minute and the pill updates; when now is outside the visible window the line and pill are not drawn and the window does not scroll on its own; a block whose stop passed exposes "past" and the panel updates if it showed that programme, all on the next render (test: within five seconds of injected time).

### AC-16 Focus within the grid
Given focus on a block
When the user moves
Then up or down lands on the block in the adjacent row containing the focused block's start time clamped to the visible window; up from the first visible row moves to the selected day chip; right or left to a block outside the window scrolls so that block's start column is first; left from a block whose start is at or before the window's left edge scrolls one column, or does nothing at the AC-13 bound; channel cells and the time header are not focusable.

### AC-16b Focus from the chips
Given focus on a day chip
When the user moves down
Then focus returns to the block it came from, or to the first row's block covering the window start; moving right from the last chip moves to `guide.watch`.

### AC-17 Focus from the panel
Given focus on `guide.watch`
When the user presses Menu or moves down
Then focus returns to the block it came from and the guide stays open.

### AC-17b Menu from the grid
Given focus in the grid or on a day chip
When the user presses Menu
Then the tab bar is shown with Guide selected (0015/AC-6).

### AC-18 Gaps
Given programmes 20:30 to 21:00 and 21:30 to 22:00 on a channel in a window from 20:00
When the row is rendered
Then every interval of the visible window not covered by a programme, including before the first and after the last, is an unlabelled focusable block on the 0.06 surface (`guide.gap.<rowKey>.<start>`); the panel for a gap reads "No programme information" with the gap's start and channel in the eyebrow; select on a gap covering now tunes per AC-9, otherwise AC-10.

### AC-19 Empty group
Given the current group has no channels
When the guide is shown
Then `guide.empty` reads "No channels in <group>", the PiP keeps playing, focus is on the Today chip, and AC-13 bounds default to today 00:00 to 24:00.

### AC-20 Overlap in source data
Given 0014/AC-6's truncated programmes
When the row is rendered
Then the truncated block's width follows its truncated duration; no two blocks in a row overlap.

### AC-21 Open at a programme
Given Search (0012/AC-8) requests the guide for programme P on channel C
When the guide is shown
Then the window's first column is the half-hour boundary at or before P's start clamped per AC-13, the day chip for P's start date is selected, C's row is scrolled into view, the current group becomes All channels when C is not in it (0008/AC-15), and focus is on `guide.block.<rowKey>.<P.start>`.

### AC-22 Clock
Given the guide is open
When the injected clock crosses a minute boundary
Then `guide.clock` at the trailing edge of the eyebrow row shows the new time in the user's locale short time style within one second and is not focusable.

## Edge cases and failure modes

- Columns are 30 minutes of absolute time anchored on a local half-hour boundary; on the DST change day the header shows a repeated or missing hour; day chips use calendar days in the user's time zone. Core test with a fixed `TimeZone` and a 2027-03-28 fixture.
- PiP when the engine is `.loading` or `.failed`: the box shows the ground colour with the caption; Watch re-tunes.
- Empty programme title: block and panel read "Untitled".
- Source whose credential has not synced: its channels are absent (0004/AC-10).
- Reduce Motion: no slide when scrolling columns.
- VoiceOver: a block reads channel, title, times and its state value.
- `Channel.streamURL` is never shown or used in an identifier (ADR-0003).

## Test plan

Window maths, block widths and minimum-width propagation, clipping, state, gap derivation, day-chip derivation and bounds are pure functions in AntennaCore over a fixed clock and time zone. UI tests use a fake engine, fixture catalogue and fake `GuideStore`. Identifiers: `guide.pip`, `guide.pip.caption`, `guide.pip.liveDot`, `guide.panel`, `guide.panel.eyebrow`, `guide.panel.title`, `guide.panel.meta`, `guide.panel.progress`, `guide.panel.summary`, `guide.watch`, `guide.days`, `guide.day.<index>`, `guide.header`, `guide.nowLine`, `guide.clock`, `guide.row.<rowKey>`, `guide.channel.<rowKey>`, `guide.block.<rowKey>.<startUnixSeconds>`, `guide.gap.<rowKey>.<startUnixSeconds>`, `guide.noGuide.<rowKey>`, `guide.loading.<rowKey>`, `guide.failed.<rowKey>`, `guide.empty`.

| Criterion | Layer | Test |
|-----------|-------|------|
| AC-1 | ui (fake engine) | TBD |
| AC-1b | ui (fake engine) | TBD |
| AC-2 | ui | TBD |
| AC-3 | core + ui | TBD |
| AC-4 | core | TBD |
| AC-5 | core + ui (accessibility value) | TBD |
| AC-6 | core (state) + ui | TBD |
| AC-7 | ui | TBD |
| AC-8a | ui (fake engine height) | TBD |
| AC-8b | ui | TBD |
| AC-8c | ui | TBD |
| AC-9 | ui (fake engine load log) | TBD |
| AC-10 | ui | TBD |
| AC-11a | core (day list) + ui | TBD |
| AC-11b | core + ui | TBD |
| AC-11c | ui | TBD |
| AC-12 | ui (fake GuideStore states) | TBD |
| AC-13 | core + ui | TBD |
| AC-14a | device + core (visible-items function) | manual on Apple TV 4K |
| AC-14b | device | Instruments |
| AC-15 | ui (injected clock) | TBD |
| AC-16 | ui | TBD |
| AC-16b | ui | TBD |
| AC-17 | ui | TBD |
| AC-17b | ui | TBD |
| AC-18 | core (gap derivation) + ui | TBD |
| AC-19 | ui | TBD |
| AC-20 | core | TBD |
| AC-21 | ui (request injected) | TBD |
| AC-22 | ui (injected clock) | TBD |

## Open questions

- Group switching with a left swipe from the channel column, instead of going back to the overlay?
- Configurable zoom (TiviMate users ask for it)? A synced setting needs an ADR.
- Remember scroll position when returning from playback?
