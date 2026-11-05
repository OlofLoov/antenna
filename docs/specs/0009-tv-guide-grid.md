# 0009. Apple TV guide grid

- Status: Accepted
- Date: 2026-11-03
- Depends on ADRs: 0001, 0002, 0003, 0005
- Builds on specs: 0004, 0007, 0008, 0012, 0013, 0014, 0015, 0017
- Platforms: tvOS
- User stories: US-10, US-21

## Summary

This is for someone on an Apple TV who wants to see what is on across their channels tonight and over the coming days. The Guide tab shows a grid: channels down the side, time across the top, each programme as a block as wide as it is long, with a line marking the current time. The channel they were watching keeps playing in a small picture in the corner, and choosing a programme that is on now switches to it full screen. It does not set reminders, record, play catch-up, or show a guide on iPhone, iPad or Mac.

## Design

Boards: `docs/design/boards/TV-Guide.dc.html`, `TV-Guide-Placeholders.dc.html`, `TV-Guide-Future.dc.html`, `TV-Guide-Empty.dc.html`.
Design rules that apply: DR-1, DR-2, DR-3, DR-4, DR-5, DR-8, DR-11, DR-12, DR-13.
Not drawn: the highlighted placeholder block and its panel, the highlighted Watch button, and the small picture when no channel has been tuned.

Layout, sizes, states and identifiers come from the boards and are settled in the implementation plan, not here.

## Problem

TV viewers plan the evening with a guide grid: what is on across channels at a glance, and what comes later. Antenna's Guide tab is an empty placeholder. The guide data is already downloaded and stored (0014); nothing shows it.

## Scope

In:
- The Guide tab (0015) with the playing channel in a small picture and a panel describing the highlighted programme.
- A grid of the current group's channels, with half-hour columns and a line at the current time.
- Programmes drawn to scale, past ones dimmed, gaps in the guide shown as empty blocks.
- Moving around the grid, to the day picker, and to the panel.
- Tuning from the grid.
- A day picker across the days the guide covers.
- Opening at a programme the user found in Search (0012).
- A clock.

Out (explicitly):
- Reminders (Remind me stays hidden).
- Recording, catch-up and Start over (hidden, as in 0007).
- A guide on iPhone, iPad and Mac (no board yet).
- Switching groups inside the guide; the user changes group in the channel overlay (0007).
- Downloading, storing and refreshing the guide (0014).
- Searching programmes (0012).

## User flow

1. The user picks Guide from the tab bar. The channel they were watching keeps playing in the small picture.
2. The highlight starts on what is on now on that channel, and the panel describes it.
3. Moving around the grid updates the panel and scrolls the grid as needed. Up from the top row reaches the day picker.
4. Select on a programme that is on now switches to that channel full screen. Select on anything else moves to the Watch button.
5. Picking a day moves the grid to the same time of day on that date.
6. Menu from the grid shows the tab bar; Menu from the panel goes back to the grid.

## Acceptance criteria

### AC-1 The channel keeps playing in a small picture
Given a channel is playing, or was paused when the user left full screen
When the user opens the Guide tab
Then the same stream plays in the small picture with the channel's number and name, resuming if it was paused, without restarting.

### AC-2 One row per channel in the current group
Given the current group has 42 channels
When the user scrolls the grid from top to bottom
Then there is one row for each of the 42 channels in the channel list's order (0013) and no others, each with its number, logo (or initials) and name, and the playing channel is marked as playing.

### AC-3 The grid opens around now and keeps time
Given it is 21:34
When the user opens the guide
Then the grid opens with the last hour and a half and the current time in view, and a line marks now; the line moves as time passes and is not drawn when now is scrolled out of view.

### AC-4 Programmes are drawn to scale
Given a channel's programmes for the visible time
When the row is drawn
Then each programme's block is as wide as it is long, blocks never overlap, past programmes are dimmed, and any time with no programme is an empty block the user can highlight.

### AC-7 It opens on what is on now
Given the user opens the guide without coming from Search
When it appears
Then the highlight is on what is on now on the playing channel's row, or on the first row when that channel is not in the group.

### AC-8a The panel describes the highlighted programme
Given a programme is highlighted
When the user looks at the panel
Then it shows whether it is on now or which day and time it starts, the channel, the title ("Untitled" when there is none), the times and length, the category and description when the guide has them, the picture quality for the playing channel, how far in it is when on now, and a Watch button and nothing else.

### AC-9 Select on a programme that is on now
Given a programme that is on now is highlighted
When the user presses select
Then that channel plays full screen with the info bar of 0008; if it was already playing the guide closes and the stream carries on, unless the stream had failed, in which case it is loaded again.

### AC-10 Select on anything else goes to Watch
Given a past or future programme, or an empty block, is highlighted
When the user presses select
Then the highlight moves to Watch without changing channel, and Watch then behaves as in AC-9.

### AC-11a Pick a day
Given the guide covers today and the next seven days
When the user picks a day from the list along the top
Then the grid moves to the same time of day on that date, the list shows today and each later day the guide covers, and the chosen day follows along when the user scrolls past midnight.

### AC-12 Channels without a guide say so
Given a channel whose guide is still loading, has nothing for the visible time, or failed to load with nothing saved from before
When its row is drawn
Then the row is one block that reads "Loading guide…", "No programme information" or "Guide unavailable", which the user can highlight and select like any other block.

### AC-19 An empty group
Given the current group has no channels
When the user opens the guide
Then the grid reads "No channels in <group>", the day list and time header still show, and the highlight is on today in the day list.

### AC-21 Open at a programme found in Search
Given the user picked a programme on a channel in Search (0012)
When the guide opens
Then the grid shows the half hour around the programme's start on its day, that channel's row is in view with the programme highlighted, and the current group becomes All channels if the channel was not in it.

## Edge cases

- Daylight saving change: the header shows the repeated or missing hour, and the day list follows calendar days in the user's time zone.
- The stream is loading or has failed: the small picture shows the background color with the caption, and Watch tunes again.
- Nothing has been tuned yet: the small picture is empty, the highlight starts on the first row, and Watch tunes.
- The guide has no dates at all: the grid covers today only with a single Today entry.
- A source whose password has not reached this device: its channels are absent.
- 20 000 channels with seven days of guide: the guide still opens quickly and scrolls smoothly (numbers in Notes for the plan).
- A programme ends while the guide is open: its block turns past and the next becomes now, and the panel follows. The grid never scrolls by itself to follow the time.
- A source whose guide refresh failed still shows the guide it had before.
- Reduce Motion: no slide when the grid scrolls.
- VoiceOver reads a block as channel, title, times, and whether it is past, now or future.

## Test plan

| Criterion | Layer |
|-----------|-------|
| AC-1 | ui |
| AC-2 | ui |
| AC-3 | core |
| AC-4 | core |
| AC-7 | ui |
| AC-8a | ui |
| AC-9 | ui |
| AC-10 | ui |
| AC-11a | core |
| AC-12 | ui |
| AC-19 | ui |
| AC-21 | ui |

## Open questions

- Decided: the guide has no group switching of its own; the user changes group in the channel overlay (0007), as Scope says.
- Zoom in and out of the time scale, as TiviMate users ask for? A synced setting needs an ADR. Can be decided in the plan.
- Remember the scroll position when coming back from full screen? Can be decided in the plan.

## Notes for the plan

- Needs 0017 for an observable engine state, `play()` on resume (AC-1) and presentation height (AC-8a).
- Owner's budgets: with 20 000 channels in All channels and seven days of guide, the first frame within one second on an Apple TV 4K (3rd generation), and no hitch longer than one frame over 20 seconds of scrolling in Instruments. The core layout returns only what is visible plus one row and column of slack.
- Window: the first column is the half hour at or before now minus 90 minutes (20:00 at 21:34), and four half-hour columns show two hours. A programme that started before the window is clipped to it and marked as started earlier.
- Geometry from the board: 370 pt per 30 minutes, 4 pt gap between blocks, 84 pt rows, 40 pt minimum block width with the following block's leading edge pushed right and its trailing edge kept; now line and focus use programme times, not drawn edges.
- Window maths, block widths, clipping, past/now/future state, gaps, day list and scroll bounds are pure AntennaCore functions over a fixed clock and time zone; test DST with a 2027-03-28 fixture.
- A gap starts at the previous programme's stop or the horizon start; overlaps in source data follow 0014's truncation. A failed source with a previous guide still shows its programmes.
- Focus rules (up and down by start time, scrolling at the edges, chips to grid and back, Watch to grid on Menu, Menu from the grid shows the tab bar as in 0015) are in this spec as of 1c06432.
- Panel duration uses 0008's formatter without "left"; resolution uses 0008's mapping. Start over and Remind me are hidden.
- Design deviations: DR-6 does not apply (the channel cell is number, logo and name); DR-7, the now line stands in for the progress bar in the grid; DR-2, Watch ships on the 0.12 surface; DR-3, the panel eyebrow is accent for "Now" only; DR-4, 14 pt initials in the 42 pt logo tile; DR-2, tighter block shadow; DR-5, chips and Watch are 36 and 50 pt; blocks use radius 8.
- `Channel.streamURL` is never shown or used in an identifier (ADR-0003).

## Dropped

- Moved to the implementation plan: AC-5, AC-13, AC-14a, AC-14b, AC-16, AC-16b, AC-17, AC-17b, AC-22.
- Merged into AC-1: AC-1b.
- Merged into AC-3: AC-15.
- Merged into AC-4: AC-6, AC-18, AC-20.
- Merged into AC-8a: AC-8b, AC-8c.
- Merged into AC-11a: AC-11b, AC-11c.
