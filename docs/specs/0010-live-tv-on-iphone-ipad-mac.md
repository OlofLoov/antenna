# 0010. Live TV browsing on iPhone, iPad and Mac

- Status: Accepted
- Date: 2026-11-03
- Depends on ADRs: 0001, 0002, 0003, 0005
- Builds on specs: 0011, 0012, 0013, 0014, 0017 (the player that plays a channel inside the screen and supports Picture in Picture; tests use a stand-in until it ships)
- Supersedes on iOS, iPadOS and macOS: the full-screen player and the Channels tab of 0004, and the Favorites tab of 0005, which becomes a group inside Live. How 0005 stores and syncs favorites stays in force.
- Platforms: iOS, iPadOS, macOS
- User stories: US-9, US-11, US-12

## Summary

This is the Live TV screen for people who watch on an iPhone, iPad or Mac. They can scroll their channels, narrow them by group or by typing, and start a channel without the picture taking over the screen: it plays in a corner on iPad and Mac and pinned at the top on iPhone, while they keep browsing. Favorites become a group in the same list, and a star next to the playing channel adds or removes it. The guide, movies, search and settings are separate screens that this one only links to.

## Design

Boards: `docs/design/boards/iPad.dc.html`, `docs/design/boards/iPhone.dc.html`, `docs/design/boards/iPad-Loading.dc.html`, `docs/design/boards/iPhone-Loading.dc.html`, `docs/design/boards/iPad-NothingSelected.dc.html`, `docs/design/boards/iPad-Error.dc.html`, `docs/design/boards/iPhone-Error.dc.html`, `docs/design/boards/iPad-Banner.dc.html`, `docs/design/boards/iPhone-Banner.dc.html`, `docs/design/boards/iPad-Empty.dc.html`, `docs/design/boards/iPhone-EmptyFavorites.dc.html`, `docs/design/boards/iPad-Collapsed.dc.html`, `docs/design/boards/iPad-Collapsed-Narrow.dc.html`, `docs/design/boards/iPhone-FullScreen.dc.html`, `docs/design/boards/iPad-Focus.dc.html`.
Design rules that apply: DR-3, DR-4, DR-5, DR-6, DR-7, DR-8, DR-11, DR-12, DR-13, DR-14, DR-15.
Not drawn: "Loading guide…" and "No programme information" in the details, the now-playing line and the row; the filled star; the greyed-out Picture in Picture button.

Layout, sizes, states and identifiers come from the boards and are settled in the implementation plan, not here.

## Problem

On a phone or at a desk people browse with a finger or a pointer while something plays. Today Antenna opens every channel in a separate full-screen player, so the picture stops each time the user goes back to the list. TiviMate's channel list, with the picture running beside it, is what IPTV users expect, and it fits an iPad or Mac window and an iPhone screen.

## Scope

In:
- iPad and Mac: a sidebar with the app's sections and the channel groups, the channel list with a filter field, and the player with details about what is on now and next. Columns fold away in narrow windows and in Split View.
- iPhone, and iPad in a narrow Split View: the player pinned at the top, a now-playing line, group chips, the channel list, and a tab bar with Live, Guide, Movies, Search and Settings. Series sits inside Movies, as in 0011.
- Picking a channel plays it in place.
- Groups, including Favorites and All channels.
- Typing to filter the current group by name or number, on iPad and Mac only. iPhone uses Search (0012).
- Adding and removing favorites with a star.
- Player controls, a Picture in Picture button on iPhone and iPad, and full screen.
- What the screen shows while loading, when some or all sources fail, offline, with no channels, and before any channel is picked.
- Keyboard shortcuts on Mac and on iPad with a keyboard.
- With no source at all, onboarding (0006) shows instead.

Out (explicitly):
- The Guide, Movies, Series and Search screens (0009, 0025, 0011, 0012).
- What the Sources and Settings screens contain.
- How the player picks its playback path, and its buffering and error messages (0017, 0018).
- How Picture in Picture behaves, including starting it when the user leaves the app. This spec only places the button.
- Sound continuing in the background.
- Rewinding live TV and catch-up. The progress bar shows how far the current programme has run.
- Reloading channels when a source changes.
- Reopening the last channel on launch.
- Reordering favorites or groups.

## User flow

iPad and Mac:
1. Live is selected in the sidebar. Below it are Favorites, All channels and each group with its channel count.
2. The middle column lists the group's channels. Typing in the filter narrows the list as the user types.
3. Picking a channel plays it on the right. Under the picture: the programme, its times, a description, a star and what is on next.
4. The controls appear on a tap or when the pointer is over the picture.

iPhone:
1. The Live tab shows the picture at the top, a line with the programme and a star, group chips, and the channels.
2. Tapping a channel plays it in place. The full-screen button, or turning the phone sideways, fills the screen.

## Acceptance criteria

### AC-1 Sidebar, list and picture side by side
Given an iPad or Mac window wide enough for the regular layout
When the user opens Live
Then the sidebar with the app's sections and channel groups, the channel list and the picture sit side by side; narrower windows fold the sidebar and then the list behind buttons, and the list is never stacked above or below the picture.

### AC-2 Picture pinned at the top on iPhone
Given an iPhone, or an iPad in a narrow Split View
When the user opens the Live tab
Then the picture spans the width at the top, with the now-playing line, the group chips and the channel list below it and the tab bar at the bottom; switching between narrow and wide layouts does not interrupt the channel.

### AC-4 Pick a group
Given a group "Sport" with 42 channels
When the user picks it in the sidebar or taps its chip
Then the list shows those 42 channels in the catalogue's order, the channel already playing keeps playing, and the filter is cleared; on iPad and Mac the list's header reads "Sport" and "42 channels".

### AC-6 Watch without leaving the list
Given the channel list
When the user picks a channel
Then it plays in place, its row is highlighted, the list stays on screen and usable, and the details show that channel; picking the channel that is already playing does not restart it.

### AC-7 Type to narrow the list
Given a group is open on iPad or Mac
When the user types in the filter field
Then after every keystroke the list shows only the group's channels whose name matches, or whose number starts with the digits typed, matched the same way Search matches (0012); clearing the field brings the whole group back.

### AC-8 See what is on now and next
Given a channel is playing and the guide knows its current programme
When the user looks at the details (iPad and Mac) or the now-playing line (iPhone)
Then they see the programme on now with its times and how far it has run, and what comes next (up to three programmes on iPad and Mac, one on iPhone).

### AC-10a Player controls when you want them
Given a channel is playing in place
When the user taps or clicks the picture, or moves the pointer over it
Then pause, the programme's progress, the time of day, a LIVE badge and full screen appear, plus a Picture in Picture button on iPhone and iPad, greyed out when the player cannot do it; the controls go away after a few seconds without input, but not while paused.

### AC-11 Star a channel
Given a channel that is not a favorite
When the user taps the star next to it
Then the star fills, the channel appears in the Favorites group in favorite order, and the Favorites count in the sidebar goes up by one; tapping again undoes all three.

### AC-14 Keyboard shortcuts
Given a Mac, or an iPad with a keyboard
When the user presses keys while the list is focused
Then the up and down arrows move a focus ring between channels without switching channel, Return plays the focused channel, Space pauses and resumes outside a text field, Command-F jumps to the filter, and Escape leaves full screen.

### AC-17 Full screen
Given a channel is playing in place
When the user taps the full-screen button, or turns an iPhone sideways
Then the picture fills the window (on iPhone the screen) with its controls, and leaving full screen returns to the list without restarting the channel; on Mac the window's own full-screen button works independently of this.

### AC-18b A login that syncs later
Given a source shown as waiting for its login to arrive from iCloud
When the login reaches this device
Then the source loads by itself, within seconds or the next time the user returns to the app, and the waiting note goes away.

### AC-20 Sources that fail, are empty or wait for a login
Given at least one source failed to load, has no channels, or has no login on this device yet
When the user opens Live
Then the channels that did load are listed under a banner naming each failed source, with Retry, which reloads only those sources while the channel keeps playing, and a dismiss button; when no source loaded any channels, a message with Retry takes the list's place; the source's own error text is never shown.

## Edge cases

- When the guide has nothing for the channel, the details and the now-playing line read "No programme information".
- An empty Favorites group says "No favorites yet. Tap the star on a channel to add it."
- Before any channel is picked, the picture area says "Select a channel".
- While sources load, the list shows each source loading in turn.
- Offline, the message says so.
- Sources that loaded with no channels show "No channels yet" with Retry.
- A source whose login has not arrived from iCloud is named as waiting for it.
- With tens of thousands of channels the list opens and scrolls without stalling (budget in the plan).
- A favorite added or removed on another device updates the star and the Favorites group without reopening Live.
- When a programme ends, the details, the now-playing line and the list catch up within a few seconds.
- With large text sizes the rows grow and the iPhone picture keeps its shape.
- VoiceOver reads a row as name, number, programme and time left; every control has a label.
- Holding an arrow key scrolls the focus through the list without switching channel.

## Test plan

| Criterion | Layer |
|-----------|-------|
| AC-1 | ui |
| AC-2 | ui |
| AC-4 | ui |
| AC-6 | ui |
| AC-7 | core + ui |
| AC-8 | core + ui |
| AC-10a | ui |
| AC-11 | integration + ui |
| AC-14 | ui |
| AC-17 | ui |
| AC-18b | ui |
| AC-20 | ui |

## Open questions

- Decided: no swipe actions or context menu on iPhone rows in this spec; a later spec can add them.
- Decided: Mac gets full screen only, no separate player window.
- Decided: the filter matches channel name and number, not the programme title (AC-7).
- Decided: only Return switches channel; resting on a row with the arrow keys never does (AC-14).

## Notes for the plan

- Owner's column breakpoints: three columns from 904 pt (sidebar 232, list 352, player never under 320); the sidebar folds below 904, the list below 672.
- Board deviations: DR-6, the number trails the name on touch and pointer platforms; DR-7, the iPhone now-playing line has no bar; DR-5, controls drawn 30 to 40 pt get a 44 by 44 pt hit area; DR-4, the LIVE badge and tile initials sit one point under the floor. Mac leaves out the PiP control drawn on the iPad boards.
- Budget from the dropped AC-22: with 20 000 channels the first rows show within one second on an iPhone 15, a five-second flick drops no frames, and filtering takes under 50 ms in a debug `swift test`.
- Controls hide three seconds after the last touch and one second after the pointer leaves.
- Offline wording applies when every failure is `.notConnectedToInternet`, `.networkConnectionLost` or `.dataNotAllowed`, as in 0006. A source without a credential counts as neither loaded nor failed. A credential that arrives is picked up within 5 s or at the next scene activation.
- Tests use a fake engine that records loaded URLs to a file in the test's temp directory. Nothing derived from a stream URL goes on an accessibility attribute (ADR-0003).
- Accessibility identifiers use the prefix `browse.`. The filter has no debounce and does not match group names.
- When this ships, 0005's header and README row say its tab criteria are superseded on iOS, iPadOS and macOS.

## Dropped

- AC-15 (no sources shows onboarding): restated 0006 without its entitlement precondition; kept as a Scope line.
- Moved to the implementation plan: AC-5, AC-9b, AC-16, AC-22, AC-23.
- Merged into AC-1: AC-3.
- Merged into AC-8: AC-9a, AC-19.
- Merged into AC-10a: AC-10b, AC-13.
- Merged into AC-11: AC-12.
- Merged into AC-20: AC-18, AC-21, AC-24.
