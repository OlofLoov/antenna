# 0015. tvOS shell: tab bar, full-screen playback and Menu

- Status: In progress
- Progress: AC-2a, AC-5a in this PR
- Date: 2026-11-03
- Depends on ADRs: 0001, 0002, 0003, 0005, 0006, 0009
- Builds on specs: 0006, 0007, 0008, 0009, 0010, 0011, 0012, 0013, 0017
- Platforms: tvOS
- User stories: US-8, US-17

## Summary

This is for anyone using Antenna on an Apple TV: it is the frame every other Apple TV screen sits in. Opening the app goes straight to the channel they last watched, full screen. Pressing Menu dims the picture and shows a tab bar along the top (Live, Guide, Movies, Series, Search and Settings), and Menu again goes back to the picture. It does not cover what happens inside each tab, the Settings screen itself, the purchase screen, or the Top Shelf.

## Design

Boards: `docs/design/boards/TV-Movies.dc.html`, `TV-Search.dc.html` (the tab bar as drawn there), `TV-Shell-Menu.dc.html`, `TV-Shell-FocusedTab.dc.html`, `TV-Shell-Loading.dc.html`, `TV-Shell-Empty.dc.html`, `TV-Shell-Guide-Menu.dc.html` (the bar over the Guide, the shell's clock hidden and its space kept), `TV-Shell-Loading-Menu.dc.html` and `TV-Shell-Empty-Menu.dc.html` (the bar over the loading and empty screens, Retry without its highlight), `TV-Settings.dc.html` (Settings as it opens, first row focused; its content is 0023's).
Design rules that apply: DR-1, DR-2, DR-3, DR-4, DR-5, DR-11, DR-12, DR-13, DR-14, DR-15.
Not drawn: nothing.

Layout, sizes, states and identifiers come from the boards and are settled in the implementation plan, not here.

## Problem

Five Apple TV specs talk about "the tab bar" and "Menu goes back to full screen", and none of them says how those work. Today's app opens on a sidebar with Channels, Guide, Favorites and Settings, which matches none of the boards.

## Scope

In:
- A tab bar along the top: the Antenna mark, Live, Guide, Movies, Series, Search, a Settings button and a clock. Movies and Series appear only when a source offers them (0011).
- Live is the current channel full screen. The tab bar is hidden on Live and Guide and always shown on Movies, Series and Search.
- Menu from full screen shows the tab bar over the dimmed picture; Menu from the top level of a tab moves to the tab bar; Menu from the tab bar goes back to Live.
- On launch, the channel last watched on this Apple TV plays, or the first channel when there is none; a loading screen and an empty screen while that is not possible.
- The video carries on for a while behind Movies, Series and Search, then pauses to save bandwidth.
- A way for other screens to send the user to Search, to a programme in the Guide, or back to Live.
- Opening Settings (its content is another spec).

Out (explicitly):
- What happens inside the overlay, info bar, guide, movies and search (their specs).
- What Settings contains.
- The purchase screen (ADR-0006 follow-up spec); the shell assumes the user has paid.
- The Top Shelf.
- Leaving the app: the TV button does that, and Menu never leaves the app from inside the shell.
- The play/pause button, including while a tab has paused the video (playback spec).
- Where in the live stream the video resumes after a pause (playback spec).

## User flow

1. The user opens Antenna. The channel they last watched starts full screen with the info bar (0008).
2. Menu dims the picture and shows the tab bar with Live highlighted. Moving along the bar does not switch tabs.
3. Select on a tab opens it. Guide keeps the picture in a small box; Movies, Series and Search keep it playing unseen for 30 seconds, then pause it.
4. Menu from the top of a tab moves to that tab in the bar; Menu again goes back to Live and the picture resumes.
5. Menu or swiping down from the bar over the dimmed picture goes back to full screen.
6. The Settings button opens Settings; Menu closes it back to the Settings button with the same tab open.

## Acceptance criteria

### AC-1 The tabs, in order
Given the user has sources and at least one offers movies
When the tab bar shows
Then it holds, from left to right, the Antenna mark, Live, Guide, Movies, Series, Search, the Settings button and the clock, and exactly one tab is marked as the current one.

### AC-2a Back to the last channel on launch
Given the user watched a channel on this Apple TV before
When they open Antenna and its source has loaded
Then that channel plays full screen; if it no longer exists, or its source has not loaded within 10 seconds, the first channel of the first source to load plays instead.

### AC-3 Menu shows the tab bar over the picture
Given a channel is playing full screen with no overlay, info bar or channel-number box showing
When the user presses Menu
Then the picture dims and keeps playing (or stays failed), and the tab bar shows with Live highlighted.

### AC-4 Back to full screen from the tab bar
Given the tab bar shows over the dimmed picture
When the user presses Menu, swipes down, or selects Live
Then the tab bar goes away and the same stream carries on full screen; a stream that had failed is loaded again when the user selects Live.

### AC-5a The video pauses behind Movies, Series and Search
Given Movies, Series or Search is open and a channel is playing behind it
When 30 seconds pass without the user going back to Live or Guide
Then the video pauses, and it resumes without restarting the channel when the user goes back to Live or Guide.

### AC-6a Menu from the top of a tab reaches the tab bar
Given the user is at the top level of a tab
When they press Menu, or swipe up from the topmost item on Movies, Series or Search
Then the highlight moves to that tab in the bar, the tab stays open, and on Guide the bar appears over the guide.

### AC-6b Menu from the tab bar goes back to Live
Given the highlight is in the tab bar and a tab other than Live is open
When the user presses Menu
Then Live is open full screen, and a video paused behind the tab resumes without restarting.

### AC-10 A loading screen at launch
Given the user has sources and none has finished loading
When they open Antenna
Then a loading screen lists each source by name with how far it has got, and the user can still press Menu to reach the tab bar and Settings.

### AC-11 An empty screen with Retry
Given every source has finished, failed or is waiting for its password, and none has any channels
When Live is shown
Then a "No channels yet" screen names each source that added nothing and why, and Retry loads those sources again and shows the loading screen while they load; Menu shows the tab bar so the user can reach Settings.

### AC-12a Open Settings
Given the tab bar shows
When the user selects the Settings button
Then the Settings screen opens over what was there and the video is not touched.

### AC-13 Moving along the bar does not switch tabs
Given the tab bar shows over the dimmed picture with Live highlighted
When the user moves the highlight to Search without pressing select
Then Live stays the current tab and the picture stays dimmed behind the bar.

### AC-14a Other screens can send the user somewhere
Given any tab or the channel overlay is showing
When another screen asks the shell for Search, for the Guide at a given programme, or for Live after tuning
Then the overlay closes, that tab opens (the Guide is told which programme to show), and for Live the picture is full screen with no tab bar.

## Edge cases

- Playback failed: the player shows its error (playback spec); Menu still shows the tab bar and selecting Live tries again.
- Offline at launch: every source fails and the empty screen shows; Retry or Settings are the ways on. Offline mid-stream: as playback failed.
- All sources removed while a tab is open: onboarding (0006) replaces the shell.
- Coming back from the background: the same channel carries on; a cold launch follows AC-2a.
- A source that finishes after the first channel started does not switch the channel.
- The purchase lapses: the purchase screen replaces the shell (ADR-0006).
- A source whose password or record arrives after launch loads when the app comes back to the foreground or on Retry; while a channel plays the loading screen never appears.
- Reduce Motion: the dimming and the tab bar appear without animation.
- VoiceOver reads the tab bar as a group of tabs; the clock and mark are plain text.

## Test plan

| Criterion | Layer |
|-----------|-------|
| AC-1 | ui |
| AC-2a | integration |
| AC-3 | ui |
| AC-4 | ui |
| AC-5a | integration |
| AC-6a | ui |
| AC-6b | ui |
| AC-10 | ui |
| AC-11 | ui |
| AC-12a | ui |
| AC-13 | ui |
| AC-14a | ui |

## Open questions

- Decided: Menu keeps the user in the app; the TV button leaves.

## Notes for the plan

- `ShellView`, `ShellModel`, `ShellNavigator` and `LastChannelKey` live in `Apps/Shared/Views/Shell/` under `#if os(tvOS)`, tested in the AntennaTV bundle; nothing enters AntennaCore (ADR-0005). 0006 owns the root chooser; `RootView` stays the root elsewhere until 0010 ships.
- `ShellNavigator` is an environment object with `show(.search)`, `show(.guide(programmeKey:))` and `showLive()`; a request from the overlay dismisses it first.
- Last channel: a `LastChannelKey(sourceID, channelID)` in `UserDefaults` under `shell.lastChannel`, per device, not synced, written when 0008's channel-change event fires. No SwiftData field (ADR-0002). The key, the event payload and logs never carry the stream URL, which holds Xtream credentials (ADR-0003).
- Launch deadline: 10 seconds from the shell appearing and again on Retry, accepted for v1; revisit with device measurements on a 30 000-stream Xtream source. Until it, another source finishing does not tune. If `load(_:)` throws, no retry for that tune and the stored key is kept.
- Menu contract: a content screen deeper than its root consumes Menu itself; at root the shell's handler receives it. The shell never asks content for its depth. The overlay, info bar and number box consume Menu while visible.
- 0012 claims DR-1 for Search and needs "the video is paused after 30 seconds, as in 0015" added in its implementing PR. The pause timer runs while Settings is open over a content tab.
- One clock on screen: over the Guide the shell's clock hides and the guide's shows. The clock uses the locale's hour-minute style.
- Design deviations: DR-1 pause behind content tabs; DR-2 the current tab is white-filled when focus is in the content and falls back to the surface fill at weight 600 when the bar has focus; DR-5 tab pills 51 pt and gear 56 pt; DR-13 scrim at 0.55 with an opaque `#11151C` pill group; DR-3 accent check on completed loading rows; the loading container is a focus holder with no Focus token.
- Criteria are tested against a fake conforming to the existing `PlaybackEngine` protocol; the real engine, its error view and live-edge resume come from 0017.

## Dropped

- AC-9 (never exits to Home): an untestable universal claim, replaced by the Scope line on leaving the app.
- Split in an earlier round: AC-6 into AC-6a and AC-6b; AC-7, AC-12 and AC-14 into the lettered ids below.
- Moved to the implementation plan: AC-7a, AC-7b, AC-12b, and the reselect rules of the old AC-6a (selecting the open Guide tab returns to the guide; selecting the open Movies, Series or Search tab goes to its first item).
- Merged into AC-2a: AC-2b, AC-8.
- Merged into AC-4: AC-18, and AC-16 for Live. AC-16's swipe down over the Guide and over the loading and empty screens: moved to the implementation plan.
- Merged into AC-5a: AC-5b.
- Merged into AC-6a: AC-17.
- Merged into AC-10 and AC-11: AC-10b.
- Merged into AC-11: AC-15.
- Merged into AC-14a: AC-14b, AC-14c.
