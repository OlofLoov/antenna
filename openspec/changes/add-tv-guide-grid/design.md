# Design

## Context

See proposal.md for why. The grid fills the Guide tab from `tvos-shell`, reads channels from `channel-catalogue` and programmes from `guide-data`.

Boards, under `openspec/specs/design-system/boards/`: `TV-Guide.dc.html`, `TV-Guide-Placeholders.dc.html`, `TV-Guide-Future.dc.html`, `TV-Guide-Empty.dc.html`.

Not drawn: the highlighted placeholder block and its panel, the highlighted Watch button, and the small picture when no channel has been tuned.

Design-system requirements that apply: “Live video keeps playing under overlays”, “Focus is the lifted white card”, “One accent color”, “Text stays above the platform caption floor”, “Targets are large enough to hit”, “Channels without a logo show initials”, “Accessibility identifiers follow the board”, “Nothing fake and nothing bundled”, “Text meets contrast minimums”.

User flow: the user picks Guide from the tab bar and the channel keeps playing in the small picture. The highlight starts on what is on now on that channel. Moving around updates the panel and scrolls the grid. Up from the top row reaches the day picker. Select on a programme on now tunes full screen; select on anything else moves to Watch. Picking a day moves to the same time on that date. Menu from the grid shows the tab bar; Menu from the panel goes back to the grid.

## Goals / Non-Goals

**Goals:**
- With 20 000 channels in All channels and seven days of guide, the first frame within one second on an Apple TV 4K (3rd generation), and no hitch longer than one frame over 20 seconds of scrolling in Instruments.

**Non-Goals:**
- Group switching inside the guide.
- Zooming the time scale.
- Start over, hidden. Remind me, added by `add-programme-reminders`, sits right of Watch for a programme that has not started.

## Decisions

- Needs change `add-playback-engine` for an observable engine state, `play()` on resume and presentation height.
- The core layout returns only what is visible plus one row and column of slack.
- Window: the first column is the half hour at or before now minus 90 minutes (20:00 at 21:34), and four half-hour columns show two hours.
- Geometry from the board: 370 pt per 30 minutes, 4 pt gap between blocks, 84 pt rows, 40 pt minimum block width with the following block's leading edge pushed right and its trailing edge kept. The now line and focus use programme times, not drawn edges.
- Window maths, block widths, clipping, past/now/future state, gaps, day list and scroll bounds are pure AntennaCore functions over a fixed clock and time zone. DST is tested with a 2027-03-28 fixture.
- A gap starts at the previous programme's stop or the horizon start. Overlaps in source data follow the guide store's truncation.
- Focus rules (up and down by start time, scrolling at the edges, chips to grid and back, Watch to grid on Menu, Menu from the grid shows the tab bar as in the shell) are in Focus rules below.
- Panel duration uses the zap bar's formatter without "left". Resolution uses the zap bar's mapping.
- Design deviations: “Channel rows share one anatomy” does not apply (the channel cell is number, logo and name); “A current programme always shows its progress”, the now line stands in for the progress bar in the grid; “Focus is the lifted white card”, Watch ships on the 0.12 surface; “One accent color”, the panel eyebrow is accent for "Now" only; “Text stays above the platform caption floor”, 14 pt initials in the 42 pt logo tile; “Focus is the lifted white card”, tighter block shadow; “Targets are large enough to hit”, chips and Watch are 36 and 50 pt; blocks use radius 8.
- `Channel.streamURL` is never shown or used in an identifier.
- Window, layout and day-list requirements are tested in the core package; focus and playback requirements in UI tests.

## Focus rules

Opening:
- Without a request from Search, focus starts on the block covering now in the playing channel's row (a programme, gap or placeholder), with the row scrolled into view. When the playing channel is not in the group, or nothing has been tuned, it starts on the block covering now in the first row.
- An empty group puts focus on the selected day chip.

In the grid:
- Up or down lands on the block in the next row that contains the focused block's start time, clamped to the visible window.
- Up from the group's first row moves to the selected day chip. Up from any other row scrolls that row into view if needed.
- Right or left to a block outside the window scrolls so that block's start column is first.
- Left from a block that starts at or before the window's left edge scrolls back one column, or does nothing at the left bound.
- Channel cells, the time header, the small picture, the panel text and the clock are not focusable.

From the day chips:
- Down returns to the block focus came from if the window has not changed since. Otherwise it goes to the block covering the window start in the row focus came from, or in the first row when there is none.
- Right from the last chip and up from any chip move to Watch.

From Watch:
- Menu or down returns focus to the block it came from and the guide stays open. Left, right and up do nothing.

Menu:
- Menu in the grid or on a day chip shows the tab bar with Guide selected, as the shell does.

Scroll bounds:
- The first visible column is never before the half hour at or before the horizon start. The last column is the one whose start is strictly before the horizon end.
- With no horizon in the store, the bounds are today 00:00 to 24:00 with a single Today chip.

## Risks / Trade-offs

- [Seven days across 20 000 channels is a lot of blocks] → the layout returns only the visible slice, checked against the budget in Instruments.
- Open question: zoom in and out of the time scale, as TiviMate users ask for? A synced setting needs a decision in that change's design.md. Can be decided during implementation.
- Open question: remember the scroll position when coming back from full screen? Can be decided during implementation.
