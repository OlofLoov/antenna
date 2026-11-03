# 0015. tvOS shell: tab bar, full-screen playback and Menu

- Status: Draft (two spec-reviewer rounds; remaining findings listed in the PR)
- Date: 2026-11-03
- Depends on ADRs: 0001, 0002, 0003, 0006
- Platforms: tvOS
- Builds on specs 0006 (onboarding), 0011 (Movies and Series presence rule), 0013 (catalogue lookup), 0008 (channel-change event). Owns the navigation that 0007, 0008, 0009, 0011, 0012 assume. Replaces the tvOS root only; `RootView` remains the root for the other platforms until 0010 is implemented.
- Blocked on the playback engine spec (not yet written) for the engine's observable state and a live-edge API (AC-5b). Tested with a fake engine until then.

## Design

Boards: top bar as drawn on `docs/design/boards/TV-Movies.dc.html` and `TV-Search.dc.html` (Antenna mark, pill tab bar with the selected tab white-filled, clock). Full-screen playback with nothing but video is 0008's not-drawn hidden state; no clock is shown there.
Design rules that apply: DR-1, DR-2, DR-3, DR-4, DR-11, DR-12, DR-13, DR-14, DR-15. Deviations: DR-1, behind Movies, Series and Search the engine is paused after 30 seconds to save bandwidth (0012's DR-1 claim covers the first 30 seconds only). DR-2, the selected tab is white-filled when focus is in the content; when focus is on the tab bar the focused item takes the Focus token and the selected item falls back to the surface fill with weight 600.
The tab bar is part of the Movies, Series and Search screens and always visible there (boards); it is hidden on Live and on Guide (TV-Guide board) and appears over the dimmed picture on Menu.
Not drawn, to be added before the implementing PR: the tab bar over the dimmed picture (full-frame scrim `rgba(8,10,14,0.55)`, bar as on TV-Movies with the Focus token on the focused item); the focused-tab-bar state; the gear item (`shell.settings`, 30 pt glyph after Search); loading state (`shell.loading`, one row per source, 26 pt, muted detail); empty state (`shell.empty`, 29 pt title, 24 pt muted lines).

## Problem

Five tvOS specs say "the tab bar" and "Menu returns to full screen" and none owns it. `RootView` today is a sidebar-adaptable tab view with Channels, Guide, Favorites, Settings, which contradicts every board.

## Scope

In:
- Top tab bar: Antenna mark, Live, Guide, Movies, Series, Search, gear. Movies and Series present per 0011/AC-1. Clock at the trailing edge.
- Live is full-screen playback of the current channel; the tab bar is hidden on Live and Guide, persistent on Movies, Series and Search.
- Menu from full screen with no overlay, bar or pill visible shows the tab bar over the dimmed picture with Live selected.
- Moving focus along the tab bar does not change the selected tab or the screen beneath; select does. The tab bar is reached from content by Menu (AC-6) and by swiping up from the topmost focusable element of Movies, Series and Search; Guide reaches it by Menu only.
- Launch: the last watched channel plays full screen; else the first channel per 0006/AC-15. Loading and empty states while that is not possible.
- Programmatic navigation requested by other screens (AC-14).
- Settings sheet entry (content out of scope).
- Accessibility identifiers with prefix `shell.`.

Out (explicitly):
- Overlay, zap bar, guide, movies, search behaviour (their specs).
- Settings content.
- Paywall presentation (ADR-0006 follow-up spec); the shell assumes entitlement.
- Top Shelf extension.
- Leaving the app: the TV button does that; Menu never exits from inside the shell (open question records the HIG trade-off).

## User flow

1. Launch. The last watched channel starts full screen. The zap bar shows (0008/AC-1).
2. Menu with nothing showing: the picture dims, the tab bar appears with Live selected and focused. Swiping right moves focus across Guide, Movies, Series, Search, the gear, without switching.
3. Select on a tab shows that screen. Guide keeps the picture in its PiP box; Movies, Series and Search keep it playing unseen for 30 seconds, then pause it.
4. Menu from a tab screen's root level puts focus on that tab in the bar; Menu again returns to full-screen Live.
5. Menu from the tab bar over the dimmed picture returns to full screen.

## Acceptance criteria

Each criterion is testable in isolation and has a stable id. Do not renumber.

### AC-1 Tabs and order
Given sources exist and at least one is Xtream
When the tab bar is shown
Then `shell.tabBar` lists `shell.mark` (not focusable), `shell.tab.live`, `shell.tab.guide`, `shell.tab.movies`, `shell.tab.series`, `shell.tab.search` in that order followed by `shell.settings` and `shell.clock`; the selected item has background `#F2F4F8` and text `#0B0E13` and the others are unfilled; presence of Movies and Series follows 0011/AC-1.

### AC-2a Launch into the last channel
Given a stored key that resolves (0013/AC-15) in the catalogue of a source that has finished loading
When the shell appears
Then that channel plays within one second of that source finishing, no tab bar is visible, and a channel-change event is emitted (0008/AC-1).

### AC-2b Launch fallback
Given no stored key, or one that resolves in no finished source within 10 seconds
When the shell appears
Then the first channel per 0006/AC-15 plays with a channel-change event; a later-finishing source never switches the playing channel.

### AC-3 Menu shows the tab bar
Given full-screen playback with no overlay, zap bar or entry pill visible
When the user presses Menu
Then `shell.scrim` covers the picture, the tab bar appears with Live selected, `shell.tab.live` has focus and is the only white-filled item, and the engine state stays `.playing`.

### AC-4 Leaving the tab bar to full screen
Given the tab bar is shown over the dimmed picture
When the user presses Menu (test a) or selects `shell.tab.live` (test b)
Then the tab bar and scrim are gone, the engine instance and state are unchanged, and no `load(_:)` call was made.

### AC-5a Pause behind content tabs
Given Movies, Series or Search is open and the engine is `.playing`
When 30 seconds pass on the injected clock without Live or Guide being shown
Then `pause()` has been called once and the engine instance is unchanged.

### AC-5b Resume on Live
Given AC-5a's paused engine
When the user selects Live
Then `play()` is called and the position is within five seconds of the live edge (needs the playback spec's live-edge API; blocked until then).

### AC-6 Menu from a tab screen
Given focus inside a tab's content at the level its spec calls root (0009/AC-17b grid, 0011/AC-7 rows, 0012/AC-12 keyboard)
When the user presses Menu
Then focus is on `shell.tab.<thatTab>`, the tab stays selected, and for Guide the bar is now visible over the dimmed PiP screen; a second Menu applies AC-4.

### AC-7 Clock
Given the tab bar is shown
When the injected clock crosses a minute boundary
Then `shell.clock` shows the new time in the user's locale short time style within one second; on Guide the clock is 0009's.

### AC-8 Last watched channel is remembered
Given the user tunes to a channel
When the app is terminated and relaunched
Then AC-2a plays it; the key stored is `sourceID` plus channel `id` (0013/AC-11's components without position) in the standard `UserDefaults` suite, in no SwiftData record and never as the stream URL.

### AC-10 Loading at launch
Given sources exist and none has finished loading
When the shell appears
Then `shell.player` shows the ground colour with `shell.loading` listing one row per source with its name and state as 0010/AC-16, the tab bar is hidden, and the first channel tunes within one second of the first source finishing (AC-2a or AC-2b).

### AC-11 No channels
Given every source finished and the catalogue is empty, including a source whose Keychain item is absent
When Live is shown
Then `shell.empty` reads "No channels yet" with "<name>: waiting for its login to sync from iCloud" per such source and `shell.retry`; Menu still shows the tab bar.

### AC-12 Settings sheet
Given the tab bar is shown
When the user selects `shell.settings`
Then a sheet opens over the shell, the engine state is unchanged, and Menu dismisses it to the tab bar with the previous tab selected.

### AC-13 Focus does not switch tabs
Given focus on `shell.tab.live` over the dimmed picture
When focus moves to `shell.tab.search` without select
Then Live stays selected, the scrim stays, and no screen is presented.

### AC-14 Programmatic navigation
Given any tab or the overlay is shown
When another screen requests Search (0007/AC-23), Guide with a programme (0012/AC-8), or full-screen Live after a tune (0009/AC-9, 0012/AC-6)
Then the shell selects that tab, or hides the bar for Live, within one frame, delivers the request's payload (programme key) to the destination, and a tune from any tab emits the channel-change event of 0008/AC-1.

## Dropped

- AC-9 (never exits to Home): untestable universal claim. Replaced by the Scope sentence on leaving the app and the open question.

## Edge cases and failure modes

- Playback failed: the full-screen view shows the player's error state (playback spec); Menu still shows the tab bar; Live re-tunes on select.
- Sources removed while a tab screen is open: onboarding replaces the shell at the next root evaluation (0006/AC-1).
- Return from background: the same engine instance resumes the same channel; a cold launch applies AC-2.
- Entitlement lapses: the paywall replaces the shell at the next root evaluation (ADR-0006).
- Reduce Motion: scrim and tab bar appear without animation.
- VoiceOver: the tab bar is a tab group; the clock and mark are static text.

## Test plan

UI tests on the tvOS simulator with a fake engine (recording `load`, `play`, `pause`), fixture sources with injected completion order, a fake defaults suite and an injected clock. Identifiers: `shell.tabBar`, `shell.mark`, `shell.tab.live`, `shell.tab.guide`, `shell.tab.movies`, `shell.tab.series`, `shell.tab.search`, `shell.settings`, `shell.clock`, `shell.player`, `shell.scrim`, `shell.loading`, `shell.loading.<sourceId>`, `shell.empty`, `shell.retry`.

| Criterion | Layer | Test |
|-----------|-------|------|
| AC-1 | ui | TBD |
| AC-2a | ui (fake defaults, injected completion order) | TBD |
| AC-2b | ui (injected clock) | TBD |
| AC-3 | ui (fake engine state) | TBD |
| AC-4 | ui (tests a and b) | TBD |
| AC-5a | ui (injected clock, fake engine) | TBD |
| AC-5b | ui (blocked on playback spec) | TBD |
| AC-6 | ui (per tab) | TBD |
| AC-7 | ui (injected clock) | TBD |
| AC-8 | integration (fake defaults) + ui (relaunch) | TBD |
| AC-10 | ui (stubbed sources) | TBD |
| AC-11 | ui (fake credential store) | TBD |
| AC-12 | ui | TBD |
| AC-13 | ui | TBD |
| AC-14 | ui (requests injected) | TBD |

## Open questions

- Menu at the top level: this spec keeps the user inside the shell (AC-4 and AC-3 alternate), which departs from the tvOS HIG expectation that Menu at the top level returns Home. Alternative: Menu on the tab bar with Live selected suspends the app.
- Should Menu from full screen open the channel overlay (TiviMate's Back) instead of the tab bar, with the tab bar on a long press?
- Is 30 seconds the right pause delay behind Movies and Search, or should audio continue muted?
