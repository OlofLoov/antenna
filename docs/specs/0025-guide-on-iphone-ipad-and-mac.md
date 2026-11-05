# 0025. Guide on iPhone, iPad and Mac

- Status: Draft
- Date: 2026-11-04
- Depends on ADRs: 0001, 0002, 0003, 0005
- Builds on specs: 0004, 0006, 0007, 0008, 0009, 0010, 0012, 0013, 0014, 0015, 0017 (the player's observable state; tests use a stand-in until it ships)
- Needs from other specs: 0010 keeps the channel playing while the Guide is open, shares its current group with the Guide, and lets other screens open the Guide on iPhone, iPad and Mac; 0012: a later programme picked in Search opens this guide on iPhone, iPad and Mac; 0009 lets its guide layout take this guide's sizes; 0013 gives each channel row an identifier that never contains its stream link; 0015 makes its screen navigator work on every platform and change the current group.
- Platforms: iOS, iPadOS, macOS
- User stories: US-10

## Summary

For people who plan their viewing on an iPhone, iPad or Mac. Once this ships, the Guide tab and sidebar entry open a real TV guide: a grid of channels against time on iPad and Mac, and on iPhone a list of channels where each row scrolls sideways through that channel's programmes. They can move through the coming days, zoom the grid, read about a programme, and start watching from it, while whatever was already playing keeps playing out of sight. Reminders, recording, catch-up and a picture-in-picture box inside the guide are not part of it; the Apple TV guide is 0009.

## Design

Boards: `docs/design/boards/iPad-Guide.dc.html`, `docs/design/boards/iPhone-Guide.dc.html`, `docs/design/boards/iPad-Guide-Placeholders.dc.html`, `docs/design/boards/iPad-Guide-Empty.dc.html`, `docs/design/boards/iPhone-Guide-Placeholders.dc.html`, `docs/design/boards/iPhone-Guide-Detail.dc.html`.
Design rules that apply: DR-3, DR-4, DR-5, DR-6, DR-7, DR-8, DR-11, DR-12, DR-13, DR-14, DR-15.
Not drawn: details for a past, later, gap or placeholder programme; the empty group on iPhone; the loading and error states; the folded sidebar; other zoom levels and greyed-out zoom buttons; the now-playing chip without the live dot; nothing playing.

Layout, sizes, states and identifiers come from the boards and are settled in the implementation plan, not here.

## Problem

0009 draws the guide for Apple TV only. 0010 puts a Guide tab and a Guide sidebar entry on iPhone, iPad and Mac, and today they lead to a placeholder. TiviMate users name the guide as the reason they stay, and the lack of a phone and desktop app as the reason Apple users leave.

## Scope

In:
- iPad and Mac: a time grid for the current group under a toolbar with a filter field, day chips, a Now button, zoom buttons and what is playing. Pinch to zoom on iPad; buttons and keys on Mac.
- iPhone, and iPad in a narrow Split View: a channel list where each row scrolls sideways through that channel's programmes from the one on now. No grid: at phone width a 30-minute column would leave four or five letters of each title.
- Programme details in a popover (iPad, Mac) or a sheet (iPhone), with a Watch button.
- Watching from the guide: Watch, or tapping a channel, plays it in Live.
- The guide shows no picture. Whatever was playing keeps going, sound included, and is there again in Live.
- The current group is the same one Live uses; changing it in one changes it in the other.
- Moving through the days the guide covers.
- Opening at a programme another screen asks for.
- What rows show while a guide loads or when it is missing or failed, banners for failed guides and logins still to sync, an empty group, sources loading, and every source failed.
- Keyboard use on Mac and on iPad with a keyboard, wide layout only.
- With no source at all, onboarding (0006) shows instead.

Out (explicitly):
- Reminders.
- Recording, catch-up, Start over and rewinding live TV.
- Downloading, storing and refreshing the guide (0014).
- Searching programmes (0012). The filter here matches channels only.
- A picture-in-picture box inside the guide, and whether the system's PiP window keeps playing (0017).
- The Apple TV guide (0009).
- Hiding, renaming or reordering groups (0020).
- A zoom level that syncs between devices, or a zoom setting.
- Programme artwork in the details.
- Long-press or right-click menus on the guide.

## User flow

iPad and Mac:
1. The user picks Guide in the sidebar. The group is the one Live showed, and the channel playing in Live keeps playing; the toolbar names it.
2. The grid shows the group's channels in rows and two hours in half-hour columns from half an hour ago, with a line marking now.
3. The user drags through time and channels, zooms, taps a day to jump to the same time that day, and taps Now to come back.
4. Tapping a programme opens its details; Watch plays the channel in Live. Tapping the channel's name plays it straight away.
5. Typing in the filter narrows the rows by name or number.

iPhone:
1. The Guide tab shows group chips, day chips and one row per channel, each scrolled to the programme on now.
2. The user swipes a row to see later programmes and scrolls the list for other channels.
3. Tapping a programme opens its details; Watch plays the channel in Live. Tapping the row's header plays it straight away.
4. While something plays, a bar above the tab bar shows it; tapping the bar returns to Live.

## Acceptance criteria

### AC-1 A time grid on iPad and Mac
Given an iPad or Mac window in the wide layout at 21:34
When the user opens the Guide
Then a toolbar sits above a grid of the group's channels against half-hour columns starting at 21:00, with a line at 21:34; the channel names and time labels stay put while the programmes scroll under them; the sidebar folds away in narrower windows as in 0010; no channel list or picture is shown.

### AC-2 One row per channel on iPhone
Given an iPhone, or an iPad in a narrow Split View
When the user opens the Guide
Then group chips and day chips sit above a list with one row per channel, each showing that channel's programmes as cards from the one on now, with start time and title; the card on now is marked NOW with a progress bar; each row scrolls sideways on its own.

### AC-3 The same group as Live
Given the current group in Live is Sport with 42 channels
When the user opens the Guide, then picks News, then goes back to Live
Then the Guide first shows Sport's 42 channels in catalogue order with the playing channel marked, then News's channels, and Live shows News with the same channel still playing.

### AC-8a Zoom
Given the grid at its default scale on iPad or Mac
When the user taps zoom in or out, presses Command-Plus or Command-Minus, or pinches on an iPad
Then the grid steps through four fixed scales, keeping the time under the now line (or under the pinch) in place, with the buttons disabled at either end; the chosen scale is remembered on this device after a relaunch.

### AC-9b Move through the days
Given the guide covers today and the next seven days
When the user picks a day chip, drags past midnight on iPad or Mac, or taps Now
Then a day chip jumps to the same time of day on that day, dragging past midnight selects the new day's chip, and Now returns to today around the current time with the playing channel in view; the user cannot scroll before the guide's first half-hour or past its last programme, and earlier days are not listed.

### AC-11 Read about a programme
Given a programme in the grid or a row
When the user taps or clicks it, or on a keyboard moves to it with the arrow keys and presses Return
Then its details open (a popover on iPad and Mac, a sheet on iPhone) with when and where it airs, the title, times and length, how far it has run if on now, its description, and Watch; the usual dismiss gestures and Escape close it.

### AC-13a Start watching from the guide
Given a programme's details, or a channel's name in the grid or a row's header
When the user taps Watch or the channel's name
Then Live opens with that channel playing in the same group: a channel not yet playing, or one that failed, starts; a paused one resumes; one already playing carries on uninterrupted; for a programme later today or another day, Live also shows it as coming up later, as in 0012.

### AC-16 Channels with gaps or no guide
Given channels whose guide is loading, missing or failed
When the user looks at the guide
Then their rows read "Loading guide…", "No programme information" or "Guide unavailable" in place of programmes, and a source whose guide failed gets a banner "Could not load the guide for <source>" with Retry and dismiss.

### AC-20 Nothing to show yet
Given sources still loading, every source failed, or a group with no channels
When the user opens the Guide
Then the grid or list is replaced by the same loading rows or error message with Retry as Live (0010), or by "No channels in <group>" with the toolbar or chips still working; while loading or failed, the toolbar and chips are hidden.

### AC-21 Open at a programme
Given the user picks a later programme in Search (0012)
When the guide opens at it
Then it switches to All channels if that channel is not in the current group, clears the filter, selects the programme's day, scrolls to the programme and opens its details; if the programme cannot be found, or its guide is still loading, the guide opens at now with nothing selected and does not try again later.

### AC-23 Filter channels by typing
Given a group of 42 channels on iPad or Mac
When the user types in the filter field, or presses Command-F and types
Then after each letter only the group's channels whose name matches, or whose number starts with the digits typed, remain, matched as in Search (0012), with the header count following; clearing the field, picking another group, or opening at a programme brings the whole group back; iPhone has no filter.

### AC-26a Playback carries on out of sight
Given a channel playing or paused in Live
When the user opens the Guide and later goes back to Live
Then the guide does not pause, stop, resume or change the channel; the toolbar (iPad, Mac) or a bar above the tab bar (iPhone) shows the channel, a live dot while it plays, and how far the programme has run, plus the programme title and time left on iPhone; tapping it returns to Live; with nothing playing it is not shown.

## Edge cases

- As time passes the now line moves, programmes that end turn to past, and the next one gains NOW, within a few seconds; the grid never scrolls by itself.
- On the day the clocks change, the header shows the repeated or missing hour; a day jump to a time that does not exist that day lands on the next minute that does.
- Offline, the guide shows what it already has; with nothing yet, rows read "Guide unavailable".
- Rotating an iPad or resizing Split View swaps grid and list, keeping group, day and open details.
- On Mac a horizontal trackpad swipe or Shift with the mouse wheel moves through time.
- Large text sizes make rows and cards taller; the grid's columns stay the same width.
- VoiceOver reads a programme as channel, title, times and past, now or later; the details are announced when they open.
- Gaps between programmes show as empty space; on iPhone, as a card with just the times.
- A source whose login has not synced shows "<source>: waiting for its login to sync from iCloud" until the login arrives.
- A guide that failed to refresh keeps its old programmes.
- A Mac trackpad pinch does nothing; zoom on Mac uses the buttons and keys.
- With tens of thousands of channels over seven days, the guide opens and scrolls without stalling.
- A guide that finishes loading or refreshes while open fills its rows in place without moving the scroll position.
- A clock or time zone change while the guide is open moves the now line and day chips; open details stay open.
- A guide covering less than a day, or no guide at all, lists Today only.
- An open popover becomes a sheet, and back, when the iPad changes size.

## Test plan

| Criterion | Layer |
|-----------|-------|
| AC-1 | core + ui |
| AC-2 | core + ui |
| AC-3 | ui |
| AC-8a | integration + ui |
| AC-9b | core + ui |
| AC-11 | ui |
| AC-13a | ui |
| AC-16 | core + ui |
| AC-20 | ui |
| AC-21 | ui |
| AC-23 | core + ui |
| AC-26a | ui |

## Open questions

Decisions made without an interview. The owner answers each one that changes a criterion before this spec is Accepted.

- iPhone gets per-channel rows instead of a narrow grid. Changes AC-2.
- Guide and Live share the current group instead of the guide keeping its own. Changes AC-3.
- The channel keeps playing with no picture instead of a PiP box like 0009's. Changes AC-26a.
- Should a later programme picked in Search open this guide on iPhone, iPad and Mac, instead of playing the channel with a "Later" line as Accepted 0012 does today? Changes AC-21 and needs 0012 revised.
- Watch on a later programme plays the channel now and notes the programme, since reminders have no spec. Changes AC-13a.
- Zoom has four fixed steps kept per device. Changes AC-8a.
- The filter is on iPad and Mac only. Changes AC-23.
- The iPhone row header's tap area is under the 44 pt floor (DR-5). Can be decided in the plan.
- The grid opens half an hour back (tvOS opens 90 minutes back), and the Mac toolbar uses the iPad sizes. Can be decided in the plan.
- Should the guide remember its scroll position and open details when the user comes back from Live? Would add a criterion.

## Notes for the plan

- Detail of the Needs line: 0009's layout function takes column width, minimum block width and channel column width as parameters (tvOS keeps 370, 40, 300) and its row identifiers use `RowKey.identifierToken`; 0015's `ShellNavigator` compiles for every platform and gains a `currentGroup` setter; 0010 provides the navigator on these platforms and keeps the engine alive while the Guide is shown; 0012 calls `show(.guide(programmeKey:))`; `RowKey.identifierToken` is a stable digest of `sourceID`, `id` and position.
- Owner's numbers: 180 pt per 30 minutes by default, zoom steps 90, 120, 180, 270; 200 pt channel column; blocks narrower than 28 pt widen and push the next one right, with 4 pt gaps; window starts at the half-hour at or before now minus 30 minutes, or at or before now when the grid is too narrow to show the line; Mac minimum window 640 pt with the grid at least 440; iPhone cards 168 by 54 pt.
- Zoom level lives in an injected per-device store (production `UserDefaults`), never SwiftData. A pinch snaps to the nearest step.
- Identifiers use the `guide.` prefix and `RowKey.identifierToken`, never `Channel.id` or a stream URL. A UI test asserts that no `guide.*` identifier contains the scheme, host or query of any fixture stream URL (ADR-0003).
- Engine calls: Watch on a channel not loaded or failed calls `load` once; paused calls `play` once; playing or loading calls nothing. The guide itself makes no engine call. The fake engine offers `load`, `play`, `pause`, `stop` and a state of idle, loading, playing, paused or failed.
- Banners: a dismissed source does not come back from a replayed event but does on a new failure; no banner for a source with no channel on this device. A waiting banner clears within five seconds of the guide loading.
- Board deviations: DR-6, channel cells show number, logo and name only; DR-7, the now line stands in for progress bars in the grid; DR-4, the iPhone NOW badge (11 pt) and initials (9 pt); DR-5, the 34 pt iPhone header tap area and 30 pt day chips in a 44 pt row.
- Budget from the dropped AC-24a and AC-24b: only visible items plus one row and column of slack are laid out; with 20 000 channels and seven days, first rows within one second on iPhone 15 and iPad (M1), no hitch longer than one frame while scrolling.
- Columns are absolute half hours anchored on a local boundary; DST core test uses a fixed time zone and a 2027-03-28 fixture shared with 0009. Keyboard criteria run in CI on macOS and by hand on iPad.

## Dropped

- Split earlier (kept for history): AC-7 into AC-7a and AC-7b; AC-8 into AC-8a, AC-8b and AC-8c, since steps, pinch and persistence fail for different reasons; AC-9 into AC-9a, AC-9b and AC-9c; AC-13 into AC-13a, AC-13b and AC-13c, one per player state; AC-18 into AC-18a and AC-18b, since the two banners have different controls; AC-22b and AC-22c split off AC-22; AC-24 into AC-24a and AC-24b; AC-26 into AC-26a, AC-26b and AC-26c; AC-21b split off AC-21.
- Moved to the implementation plan: AC-5, AC-6, AC-7a, AC-24a, AC-24b, AC-25. AC-25 stays as an edge case.
- Merged into AC-1: AC-4.
- Merged into AC-2: AC-7b, AC-28.
- Merged into AC-3: AC-29.
- Merged into AC-8a: AC-8b, AC-8c.
- Merged into AC-9b: AC-9a, AC-9c, AC-10, AC-27.
- Merged into AC-11: AC-12, AC-22, AC-22b.
- Merged into AC-13a: AC-13b, AC-13c, AC-14, AC-15.
- Merged into AC-16: AC-17, AC-18a, AC-18b.
- Merged into AC-20: AC-19.
- Merged into AC-21: AC-21b.
- Merged into AC-23: AC-22c.
- Merged into AC-26a: AC-26b, AC-26c.
