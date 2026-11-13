# Tasks

## 1. Grid maths in the core package

- [x] 1.1 Add window, now line and scroll bounds functions over an injected clock and time zone, with a 2027-03-28 DST fixture, and verify with a core test citing `tv-guide-grid/the-grid-opens-around-now-and-keeps-time`
- [x] 1.2 Add block widths, minimum width, clipping, gaps and past/now/future state, and verify with a core test citing `tv-guide-grid/programmes-are-drawn-to-scale`
- [x] 1.3 Add the day list and the day that follows scrolling past midnight, and verify with a core test citing `tv-guide-grid/pick-a-day`

## 2. Guide tab and small picture

- [x] 2.1 Keep the stream in the small picture, resuming a paused one without restarting, and verify with a UI test citing `tv-guide-grid/the-channel-keeps-playing-in-a-small-picture`
- [x] 2.2 Render one row per channel in the current group with the playing mark, and verify with a UI test citing `tv-guide-grid/one-row-per-channel-in-the-current-group`
- [x] 2.3 Render placeholder rows for loading, empty and unavailable guides, and verify with a UI test citing `tv-guide-grid/channels-without-a-guide-say-so`
- [x] 2.4 Render the empty-group state with the highlight on today, and verify with a UI test citing `tv-guide-grid/an-empty-group`
- [x] 2.5 Check the first-frame and scrolling budgets on an Apple TV 4K (3rd generation) in Instruments. The device check is in `docs/release/device-checklist.md`.

## 3. Focus, panel and tuning

- [x] 3.1 Put the initial highlight on now on the playing row, or the first row, and verify with a UI test citing `tv-guide-grid/it-opens-on-what-is-on-now`
- [x] 3.2 Build the panel with timing, channel, title, length, category, description, quality, progress and Watch, and verify with a UI test citing `tv-guide-grid/the-panel-describes-the-highlighted-programme`
- [x] 3.3 Tune full screen on select for a programme on now, keeping a playing stream, and verify with a UI test citing `tv-guide-grid/select-on-a-programme-that-is-on-now`
- [x] 3.4 Move to Watch on select elsewhere and handle Menu from Watch and grid, and verify with a UI test citing `tv-guide-grid/select-on-anything-else-goes-to-watch`

## 4. Entry from Search

- [x] 4.1 Open at a programme picked in Search, switching to All channels when needed, and verify with a UI test citing `tv-guide-grid/open-at-a-programme-found-in-search`

## 5. Verify

- [x] 5.1 Each requirement has a test citing `tv-guide-grid/<requirement-slug>`
- [x] 5.2 `/opsx:verify` passes
