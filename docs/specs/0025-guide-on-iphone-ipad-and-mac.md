# 0025. Guide on iPhone, iPad and Mac

- Status: Draft
- Date: 2026-11-04
- Depends on ADRs: 0001, 0002, 0003, 0005
- Platforms: iOS, iPadOS, macOS
- Builds on specs 0009 (tvOS guide grid: window maths, block widths, clipping, gaps, day chips, placeholder rows, open-at-programme), 0010 (sidebar, tab bar, current group, inline player, `browse.laterProgramme`, loading and error texts), 0013 (channel order, initials, `RowKey`), 0014 (`GuideStore`, `GuideLoadingState`, `progressStream()`, horizon, overlap resolution), 0012 (matcher for the filter, guide results), 0008 (remaining-time formatter, duration text), 0015 (`ShellNavigator` API), 0006 (no sources), 0007 (hidden Start over, tune rule), 0004 (sources without a credential).
- Amends 0009 (layout-function parameters; `<rowKey>` in its identifiers becomes `RowKey.identifierToken`), 0010 (provides `ShellNavigator` on iOS, iPadOS and macOS, engine lifetime across sections, current group), 0015 (`ShellNavigator` built for every platform, `currentGroup` setter), 0012/AC-8 (a future programme opens the Guide), 0013 (`RowKey.identifierToken`). The amendments are listed under "Required of other specs"; this PR does not edit those files because they are open on their own branches.
- Blocked on the playback engine spec (not yet written) for the engine's observable state (AC-13a to AC-13c, AC-26a to AC-26c), and on 0010 providing `ShellNavigator` on these platforms (Scope). Until both land, UI tests inject a fake engine and a fake navigator.
- No ADR: the zoom level is per device in `UserDefaults` through an injected store, as 0012/AC-11 and 0015/AC-8. A synced zoom setting would need one.
- Entitlement gating is the shell's; DR-14 applies before this screen is shown.

## Design

Boards: `docs/design/boards/iPad-Guide.dc.html` (iPadOS and macOS, regular width), `docs/design/boards/iPhone-Guide.dc.html` (iOS and any compact width). State boards beside them: `iPad-Guide-Placeholders.dc.html`, `iPad-Guide-Empty.dc.html`, `iPhone-Guide-Placeholders.dc.html`, `iPhone-Guide-Detail.dc.html`.
Design rules that apply: DR-3, DR-4, DR-5, DR-6, DR-7, DR-8, DR-11, DR-12, DR-13, DR-15. Deviations: DR-6, the 200 pt channel cell at regular width and the 20 pt header line at compact width are number, logo and name only, as 0009's channel cell; DR-7, in the grid the now line stands in for the progress bar and the panel and the compact on-air card carry the bar; DR-4, the `NOW` badge on compact cards is 11 pt and the compact logo tile's initials are 9 pt because the badge is letter-spaced label text and the tile is 20 pt tall; DR-5, the compact header line's hit area is 34 pt (the line, the 8 pt padding above it and the 6 pt gap below it) so that the cards beneath stay tappable, and the day chips are 30 pt tall inside a 44 pt row.
Colours, surfaces and weights named in this section are verified by the impl-reviewer against the boards, not by UI tests; criteria name identifiers, traits and accessibility values.
Identifiers use the `guide.` prefix that DR-11 already lists for 0009. Shared with 0009, same meaning on every platform: `guide.root`, `guide.header`, `guide.nowLine`, `guide.days`, `guide.day.<index>`, `guide.row.<rowKey>`, `guide.channel.<rowKey>`, `guide.block.<rowKey>.<startUnixSeconds>`, `guide.gap.<rowKey>.<startUnixSeconds>`, `guide.loading.<rowKey>`, `guide.noGuide.<rowKey>`, `guide.failed.<rowKey>`, `guide.empty`, `guide.panel`, `guide.panel.eyebrow`, `guide.panel.title`, `guide.panel.meta`, `guide.panel.progress`, `guide.panel.summary`, `guide.watch`. New in this spec: `guide.toolbar`, `guide.filter`, `guide.now`, `guide.zoomIn`, `guide.zoomOut`, `guide.grid`, `guide.groupTitle`, `guide.list`, `guide.strip.<rowKey>`, `guide.block.<rowKey>.<startUnixSeconds>.progress`, `guide.chips`, `guide.chip.<index>`, `guide.toggleSidebar`, `guide.nowPlaying`, `guide.nowPlaying.progress`, `guide.panel.close`, `guide.banner.failed`, `guide.banner.failed.retry`, `guide.banner.failed.dismiss`, `guide.banner.waiting.<sourceId>`, `guide.sourcesLoading`, `guide.sourcesLoading.<sourceId>`, `guide.error`, `guide.retry`. Not used here from 0009: `guide.pip.*` (no PiP box), `guide.clock` (the system status bar or menu bar shows the time). `<rowKey>` in an identifier is `RowKey.identifierToken`, a stable digest of (`sourceID`, `id`, `position`) that never contains `id` verbatim, because an M3U `Channel.id` embeds the stream URL (0013 edge cases, ADR-0003).
Surfaces and type, read from the boards: past blocks and cards draw muted text on the 0.06 surface, now and future blocks primary text on the 0.08 surface; the block or card whose panel is open sits on the 0.12 surface; a hardware-keyboard focused block has a 2 pt inset ring in the Text colour and no fill; placeholder blocks and cards are muted on 0.06; gap blocks are unlabelled on 0.06; the playing channel's name is weight 600; the selected day chip and `guide.watch` are white-filled with ground text; `guide.empty` and placeholder text are muted.
States on the boards:
- `iPad-Guide`: sidebar with Guide and the Sport group selected (0010's sidebar); `guide.toolbar` with the filter field (160 by 36), day chips (Today selected), `guide.now`, the zoom pair and `guide.nowPlaying` (40 by 26 tile, live dot, "104 Sport One", 3 pt progress); time header with `guide.groupTitle` "Sport 42" in the 200 pt channel column and 180 pt columns labelled 21:00 to 22:30; the now line (2 pt accent) with its pill at 21:34; rows 56 pt with number (13 pt muted), 56 by 36 logo tile and name (15 pt); past, now and future blocks with 4 pt gaps and the ◂ marker on blocks clipped at the window start; the tapped block on the 0.12 surface with `guide.panel` as a popover beneath it (340 wide: accent eyebrow "Now · Sport One", 17 pt title, 13 pt meta, 4 pt progress, 14 pt summary, `guide.watch` 44 pt, `guide.panel.close`).
- `iPad-Guide-Placeholders`: `guide.loading.<rowKey>` "Loading guide…", `guide.noGuide.<rowKey>` "No programme information" and `guide.failed.<rowKey>` "Guide unavailable", each one block across the visible window at 14 pt; an unlabelled gap block; a hardware-keyboard focused block; `guide.banner.failed` "Could not load the guide for Nordic IPTV" with `guide.banner.failed.retry` and `guide.banner.failed.dismiss`; `guide.banner.waiting.<sourceId>` "Blue Sky TV: waiting for its login to sync from iCloud" with neither; the sidebar's waiting-for-login row (0010/AC-24).
- `iPad-Guide-Empty`: `guide.empty` "No channels in Favorites" at 15 pt centred in the grid area, Favorites selected with count 0, toolbar, time header and now line kept.
- `iPhone-Guide`: `guide.chips` (Favorites, All channels, Sport selected, …; no counts, as 0010), `guide.days` (13 pt chips, Today selected) with `guide.now` at the trailing edge, rows of 96 pt each with a 20 pt header line (30 by 20 logo tile, 13 pt muted number, 15 pt name at weight 600) and a `guide.strip.<rowKey>` of 168 by 54 cards (12 pt muted start time, `NOW` badge in the accent on the on-air card, 14 pt title, 3 pt progress along the bottom of the on-air card); `guide.nowPlaying` as a 56 pt bar above the tab bar (44 by 28 tile, 15 pt programme title, 12 pt "104 Sport One · 26 min left", LIVE badge, 3 pt progress along its top edge); the tab bar with Guide selected.
- `iPhone-Guide-Placeholders`: placeholder cards with the three texts and no time, a past card followed by a gap card showing only its times, and `guide.banner.failed` under the day chips with Retry and dismiss.
- `iPhone-Guide-Detail`: the tapped card on the 0.12 surface, scrim at `rgba(8,10,14,0.55)`, `guide.panel` as a sheet at the medium detent with a grabber, accent eyebrow, 22 pt title, 13 pt meta, 4 pt progress, 15 pt summary and `guide.watch` at 50 pt.
Not drawn:
- The panel for a future or past programme: the same panel with the eyebrow muted ("Today 22:00 · Sport One", 12 pt, letter-spaced uppercase) and no progress bar, as `TV-Guide-Future` on 0009.
- The panel for a gap or placeholder (AC-16, AC-17): muted eyebrow "<Today | weekday> <start> · <channel>", the placeholder text or "No programme information" as the title (17 pt on iPad, 22 pt on iPhone), `guide.panel.meta` "<start> – <stop>" at regular width and absent at compact width, no progress, no summary, `guide.watch`; as `TV-Guide-Placeholders` on 0009.
- `guide.empty` at compact width: "No channels in <group>" muted 15 pt centred in the list area under the chips.
- `guide.sourcesLoading` and `guide.error`: the same rows and text as 0010's `iPad-Loading`, `iPhone-Loading`, `iPad-Error` and `iPhone-Error` boards in place of the grid or list, with the toolbar or chips hidden.
- The collapsed sidebar under 904 pt: `guide.toggleSidebar` in the toolbar's leading position as 0010's `iPad-Collapsed`.
- Zoom levels other than the default: the same grid with 90, 120 or 270 pt columns. The disabled zoom button at 90 or 270: glyph at 40 % opacity, as 0010's disabled PiP control.
- `guide.nowPlaying` without the live dot while the engine is `.loading`, `.failed` or `.paused`.
- The nothing-playing toolbar: `iPad-Guide` without `guide.nowPlaying`; the iPhone list without the mini bar.
The boards are drawn in the repo; the private canvas needs the same screens.

## Problem

0009 draws the guide grid for Apple TV and leaves iPhone, iPad and Mac out for want of a board. 0010 puts a Guide tab and a Guide sidebar section on those platforms and never describes the screen behind them, so today they lead to a placeholder. TiviMate users name the guide as the reason they stay and the lack of a touch and pointer client as the reason Apple users leave; a guide that only exists on the television leaves the phone, the tablet and the desk with a channel list.

## Scope

In:
- Regular width (iPadOS, macOS, iPad in a regular Split View): a time grid for the current group under a toolbar with a filter field, day chips, a Now button, zoom controls and the now-playing chip. Pinch to zoom on touch devices; buttons and key equivalents on Mac. A macOS trackpad pinch is ignored.
- Compact width (iOS, iPad in a compact Split View): a channel list where every row carries a horizontally scrolling strip of programme cards from the current one forward. No time grid at compact width, for the reason under "Compact layout".
- Programme detail as a popover (regular) or a sheet (compact) with Watch.
- Tuning: Watch and a tap or click on the channel cell play the channel inline in 0010's Live section through the same engine instance.
- The Guide shows no picture. The engine is left alone while it is shown (AC-26a, AC-26b), so audio of a playing channel continues and the picture is back when Live reappears.
- No context menu or right-click action on any guide element.
- The current group is 0010's: the sidebar's groups at regular width, `guide.chips` at compact width. Changing it here changes it for Live and the other way round.
- `ShellNavigator` on iOS, iPadOS and macOS. One type, 0015's, in `Apps/Shared/Views/Shell/`, compiled for every platform, with 0015's `show(.guide(programmeKey:))` and `showLive()` and a `currentGroup` setter that 0015 does not have yet. 0010's root provides the instance on these platforms. This spec's UI tests inject a fake that records calls (Required of other specs).
- Day picker across the 0014 horizon.
- Opening at a programme requested by another screen through `show(.guide(programmeKey:))`.
- Placeholder rows and cards for every `GuideLoadingState`, a banner per failed guide load, a waiting-for-login banner, empty group, sources loading and every-source-failed states.
- Hardware keyboard navigation on macOS and iPadOS at regular width. At compact width the hardware keyboard has system behaviour only.
- Lazy layout for groups of tens of thousands of channels, sharing 0009's core layout function.
- Accessibility identifiers with prefix `guide.`.
- With no `SourceRecord`, 0006/AC-1 applies and this screen is not shown.

Out (explicitly):
- Reminders and the Remind me action (reminders spec).
- Recording, catch-up playback, Start over, timeshift (catch-up spec; 0007/AC-14's hidden rule applies).
- Guide download, storage and refresh policy (0014).
- Programme search (0012); the filter here matches channels only.
- A PiP box inside the guide and whether the picture continues in a system PiP window while the guide is shown (playback spec). This spec only keeps the engine untouched (AC-26a, AC-26b).
- The tvOS guide (0009).
- Group management: hiding, renaming, reordering (later spec, see 0013 Out).
- A synced zoom level or a zoom setting in Settings (needs an ADR).
- Programme artwork in the panel (`Programme.iconURL` exists; a later spec decides whether to show it).

Required of other specs:
- 0009: the core layout function takes the column width (points per 30 minutes), the minimum block width and the channel column width as parameters instead of the constants 370, 40 and 300, so that AC-5 and AC-8a share it. 0009/AC-3, AC-4 and AC-15 change wording from constants to these parameters, with 370, 40 and 300 as the tvOS values; their results on tvOS are unchanged. 0009's `<rowKey>` identifiers use `RowKey.identifierToken` (the 0013 line below). 0009/AC-8a's eyebrow format "<Today | weekday> <start> · <channel>" is reused here unchanged.
- 0015: `ShellNavigator` compiles for iOS, iPadOS and macOS as well as tvOS and gains a `currentGroup` setter; its tvOS tests stay in AntennaTV.
- 0010: provides the `ShellNavigator` instance as described in Scope, keeps the engine instance alive while the Guide section or tab is shown (AC-26a, AC-26b), and exposes the current group so that AC-29 holds. 0010/AC-2 and AC-3 already place the tab and the section.
- 0012/AC-8: on iOS, iPadOS and macOS, selecting a future programme opens the Guide at it through AC-21 of this spec, as it does on tvOS, instead of playing the channel. `browse.laterProgramme` and the "Later:" fragment stay, reachable on these platforms only through Watch on a future programme in this guide (AC-14); 0012 no longer reaches them directly. Decided here; recorded under Open questions so the owner can overturn it.
- Playback engine spec (not yet written): the engine surface this spec assumes, listed under Test plan.
- 0013: adds `RowKey.identifierToken`, a stable digest of (`sourceID`, `id`, `position`) that never contains `id` verbatim, and 0009 and 0010 use it in their `<rowKey>` identifiers too, since their rows share the defect this spec's Design section names.

### Compact layout

A time grid at 390 pt leaves 190 pt for time after a usable channel column, so a 30-minute column is under 50 pt and most titles truncate to four or five characters; TiviMate has no phone client to copy and the research names touch as its gap. A phone is used to answer "what is on this channel now and next", not to scan twelve channels across two hours, so each row shows its own programmes as readable cards and gives up cross-channel time alignment. iPad and Mac keep the grid. The layout follows the horizontal size class, as 0010 does, so a Max-sized iPhone in landscape gets the grid.

## User flow

iPadOS and macOS, regular width:
1. The user selects Guide in the sidebar. The group selected under Groups is the one Live showed. The engine keeps playing; `guide.nowPlaying` in the toolbar names the channel.
2. The grid shows the group's channels in rows and a two-hour window of 30-minute columns starting half an hour before now. The now line marks the time.
3. The user drags to scroll in time and through channels, pinches (iPad) or presses the zoom buttons (Mac) to change the scale, taps a day chip to jump to that day at the same time, and taps Now to come back.
4. Tapping or clicking a block opens the detail popover. Watch plays the channel in Live. Tapping or clicking the channel cell plays it at once.
5. Typing in the filter field narrows the rows by name or number.

iOS and compact width:
1. The Guide tab shows the group chips, the day chips, and one row per channel with its programme strip starting at the programme on air.
2. The user swipes a strip to see what comes later on that channel, scrolls the list for other channels, and taps a chip for another group or day.
3. Tapping a card opens the detail sheet. Watch plays the channel in the Live tab. Tapping the row header plays the channel at once.
4. While a channel plays, the mini bar above the tab bar shows it; tapping the bar returns to Live.

## Acceptance criteria

Each criterion is testable in isolation and has a stable id. Do not renumber. Times are local to the user's time zone, injected in tests; "now" is the injected clock. "Tap" below means a tap or a click.

### AC-1 Regular-width layout
Given a horizontal size class of regular on iPadOS or macOS and the Guide section selected
When the screen is rendered at 1024 and at 800 pt wide
Then `guide.root` contains, top to bottom, `guide.toolbar` (44 pt: `guide.filter`, `guide.days`, `guide.now`, `guide.zoomOut`, `guide.zoomIn`, then `guide.nowPlaying` when AC-26a or AC-26b applies) and `guide.grid`; at 1024 pt 0010/AC-3's sidebar is visible with `browse.section.guide` selected; at 800 pt the sidebar is collapsed behind `guide.toggleSidebar` at the toolbar's leading edge, under the same 904 pt rule as 0010/AC-1; the macOS window's minimum width is 640 pt, at which the frame of `guide.grid` is at least 440 pt wide; no channel list column and no player are shown.

### AC-2 Compact-width layout
Given a horizontal size class of compact and the Guide tab selected
When the screen is rendered
Then `guide.root` contains, top to bottom, `guide.chips`, `guide.days` with `guide.now` at its trailing edge, `guide.list`, `guide.nowPlaying` (56 pt, only when AC-26a or AC-26b applies) and the tab bar of 0010/AC-2 with Guide selected; no `guide.grid` and no `guide.header` exist.

### AC-3 Rows are the current group's channels
Given the current group has 42 channels
When the grid or list is scrolled from top to bottom
Then `guide.row.<rowKey>` is exposed once for each of the 42 channels in 0013/AC-6a order and for no others; each row has `guide.channel.<rowKey>` whose label is "<number> <name>" and which contains the logo or initials tile (0013/AC-7; 56 by 36 pt regular, 30 by 20 compact); the frame of a row is 56 pt tall at regular width and 96 pt at compact width; the playing channel's `guide.channel.<rowKey>` has the `.isSelected` trait and no other does.

### AC-4 Window and now line
Given regular width, the default zoom and the time 21:34
When the guide is first laid out
Then the first visible column starts at the half-hour boundary at or before now minus 30 minutes (21:00); `guide.header` labels every 30-minute column in the locale short time style with 180 pt per column after a 200 pt channel column; `guide.nowLine` has a pill reading 21:34 in the header and its left edge is 200 + 34/30 × 180 = 404 pt from the leading edge of `guide.grid`; when the grid is too narrow for that offset (a 440 pt grid at 21:59), the first column is instead the half-hour boundary at or before now, so the now line is visible on first layout; the frames of `guide.header` and `guide.channel.<rowKey>` do not move while the grid is dragged horizontally, and `guide.header` does not move while it is dragged vertically.

### AC-5 Block width and overlap
Given the window of AC-4 and a programme row that includes 0014/AC-6's truncated programmes
When blocks are laid out
Then a block's width is minutes / 30 × 180 − 4 pt (the 4 pt gap): 716 for 120 minutes, 356 for 60, 176 for 30, 86 for 15; a block narrower than 28 pt is widened to 28 and the following block's leading edge moves right by the difference while its trailing edge stays at its stop time, applied recursively (programmes 21:00 to 21:05, 21:05 to 21:10, 21:10 to 21:15 and 21:15 to 21:45 get leading edges 0, 32, 62 and 92 pt from the window start and widths 28, 28, 28 and 174); a truncated programme's width follows its truncated duration and no two blocks in a row overlap; the now line and AC-9b use programme times, not drawn edges; all of this is computed by 0009's core layout function with 180, 28 and 200 as parameters.

### AC-6 Clipped start marker
Given a programme that started before the visible window
When rendered at regular width
Then its block starts at the window's left edge, its width is computed from the window start, its label begins with the ◂ marker before the title, and its accessibility value ends with ", started earlier".

### AC-7a Block and card state
Given programmes that ended, are on air, or start later
When rendered
Then each block (regular) or card (compact) exposes an accessibility value starting with "past", "now" or "future".

### AC-7b On-air card
Given compact width and a programme on air
When its card is rendered
Then the card's label contains "NOW" and the card contains `guide.block.<rowKey>.<start>.progress` whose value equals elapsed over duration within 0.01; past and future cards and every block in the grid have neither.

### AC-8a Zoom steps
Given regular width and the column width 180 pt
When the user activates `guide.zoomIn` or presses Command-Plus
Then the column width is 270 pt and the header time under the now line's x position is unchanged within 1 pt (subject to AC-27); `guide.zoomOut` or Command-Minus steps back through 180, 120 and 90; `guide.zoomIn` is disabled at 270 and `guide.zoomOut` at 90.

### AC-8b Pinch
Given a touch device at regular width and the column width 180 pt
When the user pinches with a final scale of 0.6
Then the column width is 120 pt (the step nearest the final scale) and the time under the gesture's centre is at the same x position within 1 pt; a macOS trackpad pinch changes nothing.

### AC-8c Zoom persistence
Given the column width 120 pt
When the app relaunches
Then the injected per-device store (production: standard `UserDefaults`) holds 120, the grid opens at 120, and no SwiftData record was written.

### AC-9a Day chip list
Given a horizon from 2026-11-03 06:00 to 2026-11-10 06:00 and today Tuesday 2026-11-03
When the guide is shown
Then `guide.days` lists eight chips, `guide.day.0` to `guide.day.7`, labelled Today, Wed, Thu, Fri, Sat, Sun, Mon, Tue (Today then short weekday names from `Calendar`, one per calendar day from today to the day containing `horizon.end` minus one second), horizontally scrollable with the selected chip visible; days before today are not listed; a horizon starting after today selects its first day; a horizon whose end is before the start of today lists Today only.

### AC-9b Selecting a chip
Given a selected chip and a window start (regular) or the anchor (compact) at local time T; the anchor is one time for every strip, initially now, set only by AC-9b, AC-10 and AC-21 and independent of strip scroll offsets
When the user selects another chip
Then the window start or the anchor moves to T on that date, clamped per AC-27; when T does not exist on that day (DST) the next existing minute is used; `guide.filter`'s text is kept.

### AC-9c Chip follows scrolling
Given regular width and the user drags the window across local midnight
When the first visible column changes day
Then the selected chip changes to that day; compact width has no equivalent.

### AC-10 Now button
Given the window or anchor has been moved by scrolling, a chip or AC-21
When the user activates `guide.now`
Then the Today chip is selected, the window start returns to AC-4's boundary (regular) or every strip's anchor returns to now (compact), the row of the playing channel is scrolled into view when it is in the group, and the list's vertical position is otherwise unchanged.

### AC-11 Detail popover
Given regular width and a block in the grid
When the user taps it
Then `guide.panel` is presented as a popover anchored to that block, the block has the `.isSelected` trait while the popover is open, and the popover shows `guide.panel.eyebrow` ("Now · <channel>" for an on-air programme; "<Today | weekday> <start> · <channel>" otherwise, as 0009/AC-8a), `guide.panel.title` (the title or "Untitled"), `guide.panel.meta` (start and stop in the locale short style, the duration from 0008/AC-5's formatter without "left", `Programme.category` when present), `guide.panel.progress` only for an on-air programme (value elapsed over duration within 0.01), `guide.panel.summary` only when a summary exists, `guide.watch`, and `guide.panel.close`; Remind me and Start over are absent; tapping outside, `guide.panel.close` or Escape dismisses it and the block loses `.isSelected`.

### AC-12 Detail sheet
Given compact width and a card in a strip
When the user taps it
Then `guide.panel` is presented as a sheet at the medium detent with the contents of AC-11 and the card has the `.isSelected` trait while the sheet is open; swiping the sheet down or tapping the scrim dismisses it and the card loses the trait; `guide.panel.close` is absent.

### AC-13a Watch on an on-air programme, channel not ready
Given `guide.panel` for a programme on air on channel C, and C is not the loaded channel or the engine state is `.failed`
When the user activates `guide.watch`
Then the panel is dismissed, the fake navigator records `showLive()` with the current group unchanged, and the fake engine records `load(C.streamURL)` once (0010/AC-6).

### AC-13b Watch on the paused channel
Given `guide.panel` for a programme on air on channel C, C loaded and the engine `.paused`
When the user activates `guide.watch`
Then the panel is dismissed, the fake navigator records `showLive()` with the current group unchanged, and the fake engine records `play()` once and no `load`.

### AC-13c Watch on the playing channel
Given `guide.panel` for a programme on air on channel C, C loaded and the engine `.playing` or `.loading`
When the user activates `guide.watch`
Then the panel is dismissed, the fake navigator records `showLive()` with the current group unchanged, and the fake engine records no call.

### AC-14 Watch on another block
Given `guide.panel` for a future or past programme P, a gap or a placeholder on channel C
When the user activates `guide.watch`
Then AC-13a to AC-13c's tune happens for C and, when P is a future programme, `browse.laterProgramme` (regular) or the "Later:" fragment of `browse.nowPlaying` (compact) shows P as 0012/AC-8 specifies; for a past programme, gap or placeholder nothing is added.

### AC-15 Tap on the channel cell
Given a row for channel C
When the user taps `guide.channel.<rowKey>`
Then AC-13a to AC-13c's tune happens for C with no panel shown; at regular width the hit area is the 200 pt cell; at compact width it is the header line, the 8 pt padding above it and the 6 pt gap below it, never the strip, so a tap at the vertical centre of a card opens the sheet (AC-12) and a tap on the header line tunes.

### AC-16 Placeholder rows and cards
Given a channel whose `loadingState` (0014) is `.noData`, `.unavailable` or `.loaded` with zero programmes in the horizon; `.loading`; or `.failed` with no previous guide
When its row is rendered
Then at regular width one block spanning the visible window reads "No programme information" (`guide.noGuide.<rowKey>`), "Loading guide…" (`guide.loading.<rowKey>`) or "Guide unavailable" (`guide.failed.<rowKey>`); at compact width the strip holds one 168 by 54 card with the same text and identifier and no time; tapping either opens `guide.panel` with that text as `guide.panel.title`, the eyebrow "<Today | weekday> <window start> · <channel>", `guide.panel.meta` "<window start> – <window end>" at regular width and absent at compact width, no progress, no summary and `guide.watch`; a `.failed` source whose previous guide is still queryable (0014/AC-11a) renders its programmes; the placeholder is replaced by `guide.block.*` elements within five seconds of the scripted store reporting `.loaded` with programmes.

### AC-17 Gaps
Given programmes 20:30 to 21:00 and 21:30 to 22:00 on a channel
When the row is rendered
Then at regular width every interval of the visible window not covered by a programme, including before the first and after the last, is an unlabelled block `guide.gap.<rowKey>.<start>`; at compact width a gap between two programmes is a card `guide.gap.<rowKey>.<start>` whose label is "<start> – <stop>" and nothing else, and no gap card is added before the first or after the last programme; tapping a gap opens `guide.panel` with the title "No programme information", the eyebrow "<Today | weekday> <gap start> · <channel>", `guide.panel.meta` "<gap start> – <gap stop>", no progress, no summary and `guide.watch`.

### AC-18a Failed guide banner
Given `progressStream()` (0014/AC-9) emits `.failed(sourceID:, error)` with an error other than `.credentialMissing` for a source S for which 0013's catalogue holds at least one channel on this device
When the guide is shown
Then `guide.banner.failed` above the grid (regular) or under the day chips (compact) reads "Could not load the guide for <S.name>" (several names joined with commas), `guide.banner.failed.retry` calls `refresh(sourceID:)` once per named source and nothing else, and `guide.banner.failed.dismiss` hides it; a replayed event (0014/AC-9a) never shows a dismissed source again, and a live `.failed` for S received after the dismissal does; a `.failed` for a source with no channel in the catalogue on this device shows no banner.

### AC-18b Waiting for login banner
Given `.failed(sourceID:, .credentialMissing)` for a source S
When the guide is shown
Then `guide.banner.waiting.<sourceId>` reads "<S.name>: waiting for its login to sync from iCloud" with no Retry and no dismiss, in the position of AC-18a's banner and below it when both exist, and disappears within five seconds of `progressStream()` emitting `.loaded(sourceID: S, …)` or of the `loadingState` of S's keys leaving `.unavailable` (0010/AC-18's rule).

### AC-19 Empty group
Given the current group has no channels
When the guide is shown
Then `guide.empty` reads "No channels in <group>" centred in the grid or list area; the toolbar, time header and now line (regular) or chips and day chips (compact) remain and work; `guide.days` and AC-27's bounds follow the store's horizon, or today 00:00 to 24:00 with a single Today chip when `horizon` is nil.

### AC-20 Sources loading and every source failed
Given sources are loading, or every source failed to load as 0010/AC-20 defines
When the Guide is shown
Then `guide.sourcesLoading` with one `guide.sourcesLoading.<sourceId>` row per source replaces the grid or list with 0010/AC-16's text, or `guide.error` with `guide.retry` replaces it with 0010/AC-20's text and offline rule; the toolbar (regular) or `guide.chips` and `guide.days` (compact) are absent in both states; a source with a missing credential appears in neither count and is listed as in 0010/AC-18.

### AC-21 Open at a programme
Given another screen calls `show(.guide(programmeKey:))` for programme P on channel C
When the guide is shown
Then the Guide section or tab is selected; the current group becomes All channels when C is not in it (0012/AC-6c's rule); `guide.filter` is cleared; the day chip for P's start date is selected; at regular width the first visible column is the half-hour boundary at or before P's start clamped per AC-27 and C's row is scrolled into view with `guide.block.<rowKey>.<P.start>` visible; at compact width the anchor becomes P's start for every strip (AC-28), so C's row is scrolled into view with P's card at its strip's leading edge; `guide.panel` opens for P as AC-11 or AC-12.

### AC-21b Open at an unknown programme
Given another screen calls `show(.guide(programmeKey:))` with a key that resolves to no loaded channel, or to a programme that is not yet queryable because its source's guide is `.loading`
When the guide is shown
Then the Guide section or tab is selected in AC-4's state (regular) or with the anchor at now (compact), no panel opens, and the request is not retried when the guide finishes loading.

### AC-22 Hardware keyboard movement
Given a hardware keyboard on macOS or iPadOS, regular width and keyboard focus in the grid
When arrow keys are pressed
Then Up and Down move keyboard focus (`hasKeyboardFocus`) to the block in the adjacent row containing the focused block's start time clamped to the visible window; Right and Left move to the next or previous block in the row and scroll the window so the block's start column is visible, stopping at AC-27's bounds; at compact width the guide handles no keys.

### AC-22b Hardware keyboard activation
Given a hardware keyboard, regular width and keyboard focus on a block
When Return, Escape or Space is pressed
Then Return opens `guide.panel` for the focused block; Escape closes an open panel or, when none is open, moves focus out of the grid; Space does nothing.

### AC-22c Hardware keyboard filter
Given a hardware keyboard and regular width
When Command-F is pressed, then Down
Then Command-F focuses `guide.filter` and Down from it focuses the first visible row's block covering the window start; Command-Plus and Command-Minus are AC-8a's.

### AC-23 Filter
Given regular width, the current group has 42 channels and 20 000 channels are loaded in total
When the user types into `guide.filter` one character at a time
Then after each character the exposed `guide.row.*` elements equal the group's channels matched by the 0012/AC-2 name rules or the 0012/AC-3 number prefix for the text typed so far, within one second of each character; the matcher runs over the current group's channels only, on each keystroke with no debounce, as 0012/AC-2 serves 0010/AC-7; group text and programme titles are not matched; `guide.groupTitle` reads "<group> <count>" ("Sport 42" with no filter) and shows the matched count while filtering; clearing the field, selecting another group (0010/AC-4) or AC-21 restores the group's rows; compact width has no `guide.filter`.

### AC-24a Large groups, materialisation
Given a core fixture of All channels with 20 000 channels and seven days of guide
When 0009's core layout function and the compact strip function are asked for a viewport
Then the layout function returns only items within the visible window plus one row and one column of slack, and a strip returns only the cards intersecting its visible width plus one on each side; rows outside the viewport return no strip.

### AC-24b Large groups, on device
Given All channels with 20 000 channels and seven days of guide on an iPhone 15 and on an iPad (M1)
When the Guide is shown and then scrolled
Then the first frame with rows is drawn within one second of the section or tab appearing, and a five-second vertical flick and, at regular width, a five-second horizontal drag show no animation hitch longer than one frame in Instruments (manual, as 0009/AC-14b).

### AC-25 Clock-driven updates
Given the guide is open
When the injected clock advances one minute, or passes a programme's stop
Then at regular width the now line's offset grows by 180/30 pt per minute at the default zoom and its pill updates; when now is outside the visible window the line and pill are not drawn and the window does not scroll by itself; a block or card whose stop passed exposes "past" and loses "NOW" and its progress element, the next card gains them without the strip's offset changing, and an open panel for that programme updates; `guide.nowPlaying.progress` and `guide.panel.progress` move with the clock; all within five seconds of injected time.

### AC-26a Playback untouched while playing
Given the engine is `.playing` on channel C from Live
When the Guide is shown and later left
Then between the Guide appearing and Live reappearing the fake engine records no `pause()`, `stop()`, `play()` or `load(_:)`; `guide.nowPlaying` shows C's logo or initials tile, "<number> <name>", the live dot, and `guide.nowPlaying.progress` with the current programme's elapsed fraction (absent with no current programme); tapping it records `showLive()` on the fake navigator and still no engine call; with the engine `.idle` or nothing selected, `guide.nowPlaying` is absent.

### AC-26b Playback untouched while paused
Given the engine is `.paused` on channel C from Live
When the Guide is shown and later left
Then the fake engine records no `pause()`, `stop()`, `play()` or `load(_:)`; `guide.nowPlaying` shows C as in AC-26a without the live dot; tapping it records `showLive()` and no engine call.

### AC-26c Compact now-playing text
Given compact width and AC-26a or AC-26b
When `guide.nowPlaying` is rendered
Then it also shows the current programme's title and 0008/AC-5's remaining text ("26 min left").

### AC-27 Horizontal bounds
Given the horizon of AC-9a
When the user scrolls the grid left or right, or a strip at compact width
Then the first visible column is never before the horizon start's half-hour boundary, the last column is the one whose start is strictly before the horizon end, and a strip lists no card outside the horizon.

### AC-28 Compact strip
Given compact width, a channel with programmes across the horizon and the anchor at now
When its row is rendered
Then `guide.strip.<rowKey>` lists one `guide.block.<rowKey>.<start>` card of 168 by 54 pt per programme in the horizon in start order, with 6 pt gaps, each labelled with the start time in the locale short style and the title or "Untitled"; the strip's initial horizontal offset puts the card covering the anchor (AC-9b) (or the first card starting after it when none covers it) at the leading edge; the offset is kept while the list scrolls vertically and reset by AC-9b, AC-10 and AC-21; strips scroll independently of each other.

### AC-29 Current group is shared with Live
Given the current group is Sport in Live
When the user opens the Guide, selects News in the sidebar or taps the News chip, and returns to Live
Then the Guide first showed Sport's rows, then News's, and Live shows News with the same channel still playing (0010/AC-4); the Favorites group lists 0013/AC-8's resolved favorites.

## Edge cases and failure modes

- Columns are 30 minutes of absolute time anchored on a local half-hour boundary; on the DST change day the header shows a repeated or missing hour; day chips use calendar days in the user's time zone. Core test with a fixed `TimeZone` and a 2027-03-28 fixture, shared with 0009.
- Offline: the guide renders whatever `GuideStore` holds; a refresh that fails with `.offline` after a completed load changes nothing in the rows (0014/AC-11a) and shows AC-18a's banner; with no previous guide the rows show AC-16's "Guide unavailable".
- A source whose credential has not synced contributes no channels (0004/AC-10) and shows AC-18b's banner; when the credential arrives, its rows appear on the next catalogue rebuild without user action.
- Engine `.paused` while the guide is shown: `guide.nowPlaying` keeps the channel identity without the live dot and the guide calls no `play()` (AC-26b); Watch or the channel cell on that channel calls `play()` once and no `load` (AC-13b); tapping `guide.nowPlaying` selects Live with the engine still `.paused`.
- Engine `.loading` or `.failed` while the guide is shown: `guide.nowPlaying` keeps the channel identity, drops the live dot, and Watch on that channel re-tunes in the `.failed` case (AC-13a).
- Empty programme title: block, card and panel read "Untitled". A summary longer than the popover is scrollable inside it; the popover is at most 480 pt tall.
- Size class change on iPad (Split View, rotation): the layout switches between AC-1 and AC-2 with the same group, day and panel state; an open popover becomes a sheet and the other way round.
- A system clock or time zone change while the guide is open re-lays out the window, the now line and the day chips on the next render; an open panel stays open.
- macOS scrolling: a horizontal trackpad scroll or Shift with a mouse wheel moves the window; a vertical-only mouse wheel scrolls rows.
- Reduce Motion: no slide when the window or a strip moves programmatically.
- Dynamic Type at accessibility sizes: rows and cards grow in height; the grid's column width does not change; card width grows to fit one line of the title at the chosen size up to 240 pt.
- VoiceOver: a block or card reads channel, title, times and its AC-7a state; the now line and header are not focusable; `guide.panel` is announced on presentation.
- `Channel.streamURL` is never shown or used in an identifier or log line (ADR-0003); the UI test asserts that no `guide.*` identifier contains the scheme, host or query of any fixture `streamURL`.
- Horizon shorter than one day, or `horizon` nil: `guide.days` lists Today only; rows show AC-16 placeholders.

## Test plan

Window maths, block widths, minimum-width propagation, clipping, state values, gap derivation, strip anchoring and card materialisation, day-chip derivation and bounds are pure functions in AntennaCore over a fixed clock and time zone, shared with 0009 where the rule is the same. UI tests run on iPad (regular), iPhone (compact) and macOS with a fake engine that records calls, a fake `ShellNavigator` that records calls, a fixture catalogue, a fake `GuideStore` whose `loadingState` and `progressStream()` are scripted, an injected clock and an injected per-device store for the zoom level. Sizes are read from element frames. Until the playback spec lands, the fake engine has the surface 0009 and 0015 already test against: `load(_:)`, `play()`, `pause()`, `stop()` and an observable `state` of `.idle`, `.loading`, `.playing`, `.paused` or `.failed`. Hardware-keyboard criteria run in CI on macOS; on iPad they are checked by hand with a connected keyboard, because the simulator's hardware keyboard setting is unreliable in CI.

| Criterion | Layer | Test |
|-----------|-------|------|
| AC-1 | ui (iPad and macOS at two widths) | TBD |
| AC-2 | ui (iPhone) | TBD |
| AC-3 | ui (iPad and iPhone, frames and traits) | TBD |
| AC-4 | core (window start) + ui (frames) | TBD |
| AC-5 | core (layout function with parameters) | TBD |
| AC-6 | core + ui (accessibility value) | TBD |
| AC-7a | core (state) + ui (iPad and iPhone) | TBD |
| AC-7b | ui (iPhone) | TBD |
| AC-8a | ui (macOS keys and buttons) | TBD |
| AC-8b | ui (iPad pinch) | TBD |
| AC-8c | integration (per-device store) + ui | TBD |
| AC-9a | core (day list) + ui | TBD |
| AC-9b | core (DST) + ui (both widths) | TBD |
| AC-9c | ui (iPad) | TBD |
| AC-10 | ui (iPad and iPhone) | TBD |
| AC-11 | ui (iPad) | TBD |
| AC-12 | ui (iPhone) | TBD |
| AC-13a | ui + fake engine and navigator logs | TBD |
| AC-13b | ui + fake engine and navigator logs | TBD |
| AC-13c | ui + fake engine and navigator logs | TBD |
| AC-14 | ui (iPad and iPhone) | TBD |
| AC-15 | ui + fake engine log (both widths) | TBD |
| AC-16 | ui (fake GuideStore states, both widths) | TBD |
| AC-17 | core (gap derivation) + ui (both widths) | TBD |
| AC-18a | ui (scripted progressStream, replay) | TBD |
| AC-18b | ui (scripted progressStream, fake credential store) | TBD |
| AC-19 | ui (both widths) | TBD |
| AC-20 | ui (stubbed sources) | TBD |
| AC-21 | ui (request injected, both widths) | TBD |
| AC-21b | ui (request injected, scripted `.loading`) | TBD |
| AC-22 | ui (macOS) + manual (iPad) | TBD |
| AC-22b | ui (macOS) + manual (iPad) | TBD |
| AC-22c | ui (macOS) + manual (iPad) | TBD |
| AC-23 | core (shared matcher) + ui (iPad) | TBD |
| AC-24a | core (visible-items and strip functions) | TBD |
| AC-24b | device | manual on iPhone 15 and iPad (M1) |
| AC-25 | ui (injected clock, both widths) | TBD |
| AC-26a | ui + fake engine and navigator logs | TBD |
| AC-26b | ui + fake engine and navigator logs | TBD |
| AC-26c | ui (iPhone) | TBD |
| AC-27 | core + ui | TBD |
| AC-28 | core (anchor offset) + ui (iPhone) | TBD |
| AC-29 | ui (iPad and iPhone) | TBD |

## Open questions

Decisions made without an interview; each can be overturned at review.

- Compact layout is per-row strips, not a grid (see "Compact layout"). The alternative is a grid with a 90 pt column and a pinned channel column.
- The current group is shared between Live and Guide (AC-29). The alternative is a guide-only group that starts from Live's.
- The engine keeps playing with no picture while the guide is shown (AC-26a), and a PiP box is left to the playback spec. The alternative is a PiP box like 0009's, which costs 180 pt of height on iPad and more on iPhone.
- 0012/AC-8 on these platforms opens the Guide at the programme (Required of other specs). The alternative keeps 0012's "play the channel and show Later:" behaviour and leaves AC-21 to future callers, tested by an injected request only.
- Watch on a future programme tunes the channel now and shows `browse.laterProgramme` (AC-14) rather than offering a reminder, because reminders have no spec.
- Zoom is four fixed steps persisted per device (AC-8a to AC-8c). The alternative is a continuous scale or a synced setting, which needs an ADR.
- The initial window starts 30 minutes before now (AC-4), not 90 as on tvOS, so the past takes a quarter of the screen on a smaller display.
- The filter field exists at regular width only (AC-23); on iPhone the Search tab covers it. The alternative adds a field above the chips.
- The compact header line's hit area is 34 pt, below DR-5's 44 pt floor. The reviewer expects a veto; settle it before the spec is Accepted. The alternative is a 106 pt row with a 44 pt header band.
- The macOS toolbar uses the iPad sizes (44 pt row, 36 pt controls) rather than the smaller controls usual on Mac, so one board serves both.
- Not decided, for the owner: should the grid remember its scroll position and open panel when the user returns from Live?

## Dropped

- AC-21's unknown-key clause moved to AC-21b, which also covers a programme whose guide is still loading.
- AC-8 is split into AC-8a, AC-8b and AC-8c; steps, pinch and persistence fail for different reasons.
- AC-9 is split into AC-9a, AC-9b and AC-9c, matching 0009/AC-11a to AC-11c.
- AC-7 is split into AC-7a and AC-7b; the state value applies to blocks and cards, the NOW badge and progress only to compact cards.
- AC-13 is split into AC-13a, AC-13b and AC-13c, one per engine state.
- AC-22 keeps the arrow keys; activation moved to AC-22b and the filter keys to AC-22c.
- AC-24 is split into AC-24a (core, fails in CI) and AC-24b (device); "no frames dropped" became 0009/AC-14b's hitch wording.
- AC-26 is split into AC-26a, AC-26b and AC-26c.
- AC-18 is split into AC-18a and AC-18b; its credential clause contradicted its own closing sentence and the two banners have different controls.
