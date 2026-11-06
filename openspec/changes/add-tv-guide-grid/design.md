# Design

## Context

See proposal.md for why. The grid fills the Guide tab from `tvos-shell`, reads channels from `channel-catalogue` and programmes from `guide-data`.

Boards, under `openspec/specs/design-system/boards/`: `TV-Guide.dc.html`, `TV-Guide-Placeholders.dc.html`, `TV-Guide-Future.dc.html`, `TV-Guide-Empty.dc.html`.

Not drawn: the highlighted placeholder block and its panel, the highlighted Watch button, and the small picture when no channel has been tuned.

Design-system requirements that apply: “Live video keeps playing under overlays”, “Focus is the lifted white card”, “One accent color”, “Text stays above the platform caption floor”, “Targets are large enough to hit”, “Channels without a logo show initials”, “Accessibility identifiers follow the board”, “Nothing fake and nothing bundled”, “Text meets contrast minimums”.

Decisions this builds on: adr-0001 (hardware playback path for MPEG-TS), adr-0002 (SwiftData with private CloudKit for sync), adr-0003 (credentials in iCloud Keychain), adr-0005 (AntennaCore is UI-free).

User flow: the user picks Guide from the tab bar and the channel keeps playing in the small picture. The highlight starts on what is on now on that channel. Moving around updates the panel and scrolls the grid. Up from the top row reaches the day picker. Select on a programme on now tunes full screen; select on anything else moves to Watch. Picking a day moves to the same time on that date. Menu from the grid shows the tab bar; Menu from the panel goes back to the grid.

## Goals / Non-Goals

**Goals:**
- With 20 000 channels in All channels and seven days of guide, the first frame within one second on an Apple TV 4K (3rd generation), and no hitch longer than one frame over 20 seconds of scrolling in Instruments.

**Non-Goals:**
- Group switching inside the guide.
- Zooming the time scale.
- Remind me and Start over, both hidden.

## Decisions

- Needs change `add-playback-engine` for an observable engine state, `play()` on resume and presentation height.
- The core layout returns only what is visible plus one row and column of slack.
- Window: the first column is the half hour at or before now minus 90 minutes (20:00 at 21:34), and four half-hour columns show two hours.
- Geometry from the board: 370 pt per 30 minutes, 4 pt gap between blocks, 84 pt rows, 40 pt minimum block width with the following block's leading edge pushed right and its trailing edge kept. The now line and focus use programme times, not drawn edges.
- Window maths, block widths, clipping, past/now/future state, gaps, day list and scroll bounds are pure AntennaCore functions over a fixed clock and time zone. DST is tested with a 2027-03-28 fixture.
- A gap starts at the previous programme's stop or the horizon start. Overlaps in source data follow the guide store's truncation.
- Focus rules (up and down by start time, scrolling at the edges, chips to grid and back, Watch to grid on Menu, Menu from the grid shows the tab bar as in the shell) are those in docs/specs/0009 as of 1c06432.
- Panel duration uses the zap bar's formatter without "left". Resolution uses the zap bar's mapping.
- Design deviations: “Channel rows share one anatomy” does not apply (the channel cell is number, logo and name); “A current programme always shows its progress”, the now line stands in for the progress bar in the grid; “Focus is the lifted white card”, Watch ships on the 0.12 surface; “One accent color”, the panel eyebrow is accent for "Now" only; “Text stays above the platform caption floor”, 14 pt initials in the 42 pt logo tile; “Focus is the lifted white card”, tighter block shadow; “Targets are large enough to hit”, chips and Watch are 36 and 50 pt; blocks use radius 8.
- `Channel.streamURL` is never shown or used in an identifier (adr-0003).
- Window, layout and day-list requirements are tested in the core package; focus and playback requirements in UI tests.

## Risks / Trade-offs

- [Seven days across 20 000 channels is a lot of blocks] → the layout returns only the visible slice, checked against the budget in Instruments.
- Open question: zoom in and out of the time scale, as TiviMate users ask for? A synced setting needs a decision record. Can be decided during implementation.
- Open question: remember the scroll position when coming back from full screen? Can be decided during implementation.
