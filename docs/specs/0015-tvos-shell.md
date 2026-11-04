# 0015. tvOS shell: tab bar, full-screen playback and Menu

- Status: Draft (three spec-reviewer rounds; remaining findings listed in the PR)
- Date: 2026-11-03
- Depends on ADRs: 0001, 0002, 0003, 0006
- Platforms: tvOS
- Builds on specs 0006 (onboarding and the root chooser), 0011 (Movies and Series presence rule), 0013 (catalogue lookup), 0008 (channel-change event). Owns the navigation that 0007, 0008, 0009, 0011, 0012 assume. Replaces the tvOS root only; `RootView` remains the root for the other platforms until 0010 is implemented.
- Depends on the playback engine spec (not yet written) for the engine's observable state and for the live-edge position after resume, which that spec owns as its own criterion. Tested with a fake engine until then.

## Design

Boards: top bar as drawn on `docs/design/boards/TV-Movies.dc.html` and `TV-Search.dc.html` (Antenna mark, pill tab bar with the selected tab white-filled, gear, clock); shell states on `TV-Shell-Menu.dc.html`, `TV-Shell-FocusedTab.dc.html`, `TV-Shell-Loading.dc.html` and `TV-Shell-Empty.dc.html`. Full-screen playback with nothing but video is 0008's not-drawn hidden state; no clock is shown there. Element identifiers (`shell.mark`, `shell.tab.*`, `shell.settings`, `shell.clock`, `shell.scrim`, `shell.player`, `shell.loading`, `shell.empty`, `shell.retry`) are comments on those boards (DR-11).
Design rules that apply: DR-1, DR-2, DR-3, DR-4, DR-5, DR-11, DR-12, DR-13, DR-14, DR-15. Deviations: DR-1, behind Movies, Series and Search the engine is paused after 30 seconds to save bandwidth (0012's DR-1 claim covers the first 30 seconds only). DR-2, the selected tab is white-filled when focus is in the content so the user can see which section they are in without a focus ring in the bar; when focus is on the tab bar the focused item takes the Focus token and the selected item falls back to the surface fill with weight 600. DR-5, tab pills are 51 pt and the gear 56 pt tall because they are chips, not rows.
Menu from full screen opens the tab bar; the channel overlay is reached by swipe per 0007.
The tab bar is part of the Movies, Series and Search screens and always visible there (boards); it is hidden on Live and on Guide (TV-Guide board) and appears over the dimmed picture on Menu.
Colours and type are verified by the impl-reviewer against the boards, not by UI tests; criteria name identifiers and accessibility traits.
States on the boards: the gear (`shell.settings`, 30 pt glyph, unfilled, 56 pt target after the pill) on TV-Movies and TV-Search; the tab bar over the dimmed picture with Live selected and focused (`shell.scrim` full frame at `rgba(8,10,14,0.55)`, Focus token on Live, clock shown) on TV-Shell-Menu; the focused tab bar over Movies content (Search focused with the Focus token, Movies selected in the 0.12 surface fill at weight 600, no focus ring left in the content) on TV-Shell-FocusedTab; loading (`shell.loading`, one row per source with its name at 26 pt and a muted 22 pt detail, indeterminate ring or "<n> channels", no tab bar, no clock) on TV-Shell-Loading; empty (`shell.empty`, "No channels yet" at 29 pt, one muted 24 pt line per source whose login has not synced, `shell.retry` as the focused white button, no tab bar) on TV-Shell-Empty.
Not drawn, to be added before the implementing PR: the tab bar and `shell.scrim` over the Guide after Menu (AC-6a), same geometry as TV-Shell-Menu with `shell.clock` hidden (AC-7); the tab bar and scrim over `shell.loading` (AC-10b), same geometry; the Settings sheet, whose content is out of scope.

## Problem

Five tvOS specs say "the tab bar" and "Menu returns to full screen" and none owns it. `RootView` today is a sidebar-adaptable tab view with Channels, Guide, Favorites, Settings, which contradicts every board.

## Scope

In:
- The shell is `ShellView` in `Apps/Shared/Views/Shell/` under `#if os(tvOS)`. 0006 owns the root chooser (paywall per ADR-0006, then onboarding, then the shell when at least one source exists); this spec owns everything inside `ShellView`.
- Top tab bar: Antenna mark, Live, Guide, Movies, Series, Search, gear. Movies and Series present per 0011/AC-1, which owns that test. Clock at the trailing edge.
- Live is full-screen playback of the current channel; the tab bar is hidden on Live and Guide, persistent on Movies, Series and Search.
- Menu from full screen with no overlay, bar or pill visible shows the tab bar over the dimmed picture with Live selected.
- Moving focus along the tab bar does not change the selected tab or the screen beneath; select does. The tab bar is reached from content by Menu (AC-6a) and by swiping up from the topmost focusable element of Movies, Series and Search; Guide reaches it by Menu only.
- Launch: the last watched channel plays full screen; else the first channel per 0006/AC-15. Loading and empty states while that is not possible.
- Last watched channel is per device, in `UserDefaults` not SwiftData, so that two Apple TVs in one home do not fight over it; it is not synced.
- Programmatic navigation: other screens navigate through `ShellNavigator`, an environment object with `show(.search)`, `show(.guide(programmeKey:))` and `showLive()` (AC-14a to AC-14c).
- Settings sheet entry (content out of scope).
- Accessibility identifiers with prefix `shell.`.

Out (explicitly):
- Overlay, zap bar, guide, movies, search behaviour (their specs).
- Settings content.
- Paywall presentation (ADR-0006 follow-up spec); the shell assumes entitlement.
- Top Shelf extension.
- Leaving the app: the TV button does that; Menu never exits from inside the shell (open question records the HIG trade-off).
- The play/pause button, including while a content tab has the engine paused (playback spec).
- The live-edge position after resume (playback spec).

## User flow

1. Launch. The last watched channel starts full screen. The zap bar shows (0008/AC-1).
2. Menu with nothing showing: the picture dims, the tab bar appears with Live selected and focused. Swiping right moves focus across Guide, Movies, Series, Search, the gear, without switching.
3. Select on a tab shows that screen. Guide keeps the picture in its PiP box; Movies, Series and Search keep it playing unseen for 30 seconds, then pause it.
4. Menu from a tab screen's root level puts focus on that tab in the bar; Menu again selects Live and returns to full screen, resuming a paused engine.
5. Menu or swipe down from the tab bar over the dimmed picture returns to full screen.

## Acceptance criteria

Each criterion is testable in isolation and has a stable id. Do not renumber.

### AC-1 Tabs and order
Given sources exist, at least one is Xtream, and focus is in the content
When the tab bar is shown
Then `shell.tabBar` contains, in order, `shell.mark`, `shell.tab.live`, `shell.tab.guide`, `shell.tab.movies`, `shell.tab.series`, `shell.tab.search`, `shell.settings`, `shell.clock`; `shell.mark` and `shell.clock` are not focusable; exactly one `shell.tab.*` has the `.isSelected` trait.

### AC-2a Launch into the last channel
Given a stored key that resolves (0013/AC-15) in the catalogue of a source that has finished loading
When the shell appears
Then that channel plays within one second of that source finishing, no tab bar is visible, and a channel-change event is emitted (0008/AC-1).

### AC-2b Launch fallback
Given no stored key, or a key whose `sourceID` matches no source, or whose source has not finished loading 10 seconds after the shell appeared, or whose source finished without that channel id
When the shell appears
Then the first channel per 0006/AC-15 of the first source to finish with at least one channel plays, within one second of that source finishing or of the 10 second deadline, whichever applies, with a channel-change event; a later-finishing source never switches the playing channel.

### AC-3 Menu shows the tab bar
Given full-screen playback with no overlay, zap bar or entry pill visible
When the user presses Menu
Then `shell.scrim` exists, `shell.tabBar` exists, `shell.tab.live` has focus and the `.isSelected` trait, and the engine state is unchanged (`.playing` stays `.playing`, `.failed` stays `.failed`); no `load(_:)`, `pause()` or `stop()` call is made.

### AC-4 Leaving the tab bar to full screen
Given the tab bar is shown over the dimmed picture with Live selected
When the user presses Menu (test a) or selects `shell.tab.live` (test b)
Then `shell.tabBar` and `shell.scrim` are gone, the engine instance and state are unchanged, and no `load(_:)` call was made.

### AC-5a Pause behind content tabs
Given Movies, Series or Search is open and the engine is `.playing`
When 30 seconds pass on the injected clock without Live or Guide being shown
Then `pause()` has been called once and the engine instance is unchanged.

### AC-5b Resume
Given AC-5a's paused engine
When Live or Guide becomes the selected tab by any route (select, Menu per AC-6b, or a request per AC-14c) without a new tune
Then `play()` is called once before the tab's content is visible, and no `load(_:)` call was made.

### AC-6a Menu from a tab screen's root
Given focus inside a tab's content at the level its spec calls root (0009/AC-17b grid, 0011/AC-7 rows, 0012/AC-12 keyboard)
When the user presses Menu
Then focus is on `shell.tab.<thatTab>`, the selected tab is unchanged, and no screen is dismissed; for Guide `shell.scrim` and `shell.tabBar` appear over the guide.

### AC-6b Menu from the tab bar returns to Live
Given focus on any item of `shell.tabBar` and a tab other than Live selected
When the user presses Menu
Then Live is selected, `shell.tabBar` and `shell.scrim` are gone, no `load(_:)` call was made, and if the engine state was `.paused` then `play()` was called once, otherwise the engine state is unchanged.

### AC-7 Clock
Given the tab bar is shown
When the injected clock crosses a minute boundary
Then `shell.clock` shows the new time in the user's locale short time style within one second; while the bar is shown over Guide, `shell.clock` is hidden and 0009's clock remains.

### AC-8 Last watched channel is remembered
Given the user tunes to a channel
When the channel-change event (0008/AC-1) fires
Then the injected `UserDefaults` suite holds `shell.lastChannel` as `sourceID` plus channel `id` (0013/AC-11's components without position) before the event handler returns; no SwiftData record gains a field; the stream URL is never stored or logged.

### AC-10 Loading at launch
Given sources exist and none has finished loading
When the shell appears
Then `shell.player` exists with no video, `shell.loading` lists `shell.loading.<sourceId>` once per source with its name and state as 0010/AC-16, `shell.tabBar` does not exist, and tuning then follows AC-2a or AC-2b.

### AC-10b Menu while loading
Given `shell.loading` is shown
When the user presses Menu
Then `shell.scrim` and `shell.tabBar` appear over `shell.loading` with Live selected and focused, `shell.settings` is selectable (AC-12), and selecting Live returns to `shell.loading`.

### AC-11 No channels
Given every source has reached a terminal state per 0010/AC-16 (loaded, failed, or waiting for its credential) and the catalogue is empty
When Live is shown
Then `shell.empty` exists with `shell.empty.source.<sourceId>` once per source that is not loaded, showing that source's name and its 0010/AC-16 state text, `shell.retry` has focus, `shell.tabBar` does not exist, and Menu shows the tab bar (AC-3 with `shell.empty` beneath instead of video).

### AC-12 Settings sheet
Given the tab bar is shown
When the user selects `shell.settings`
Then a sheet opens over the shell, the engine state is unchanged, and Menu dismisses it to the tab bar with the previous tab selected.

### AC-13 Focus does not switch tabs
Given focus on `shell.tab.live` over the dimmed picture
When focus moves to `shell.tab.search` without select
Then `shell.tab.live` keeps the `.isSelected` trait, `shell.scrim` still exists, and no `movies.`, `series.`, `search.` or `guide.` root identifier exists.

### AC-14a Request Search
Given any tab or the overlay is shown
When `show(.search)` is called (0007/AC-23)
Then `shell.tab.search` is selected and the search root (0012) is visible before the next remote event is processed.

### AC-14b Request Guide with a programme
Given any tab or the overlay is shown
When `show(.guide(programmeKey:))` is called (0012/AC-8)
Then `shell.tab.guide` is selected and 0012/AC-8's programme is the focused cell before the next remote event is processed.

### AC-14c Request full-screen Live
Given any tab or the overlay is shown
When `showLive()` is called after a tune (0009/AC-9, 0012/AC-6)
Then `shell.tab.live` is selected, `shell.tabBar` and `shell.scrim` are gone, and `shell.player` is the only visible content before the next remote event is processed.

### AC-15 Retry
Given `shell.empty` is shown
When the user selects `shell.retry`
Then every source that is not loaded is reloaded once, `shell.loading` replaces `shell.empty` while any source is loading, and the outcome follows AC-2a, AC-2b or AC-11.

### AC-16 Swipe down from the bar
Given the tab bar is shown over the dimmed picture
When the user swipes down
Then for Live `shell.tabBar` and `shell.scrim` are gone as in AC-4; for Guide focus returns to the guide cell that had it and `shell.tabBar` and `shell.scrim` are gone.

## Dropped

- AC-9 (never exits to Home): untestable universal claim. Replaced by the Scope sentence on leaving the app and the open question.
- AC-6 (Menu from a tab screen): split into AC-6a and AC-6b because its second Menu cited AC-4, whose Given does not hold on content tabs and whose Then forbade the `play()` a paused engine needs.
- AC-14 (programmatic navigation): split into AC-14a to AC-14c with the `ShellNavigator` calls named; "within one frame" was not observable and the channel-change clause belongs to 0008/AC-1.

## Edge cases and failure modes

- Playback failed: the full-screen view shows the player's error state (playback spec); Menu still shows the tab bar (AC-3); Live re-tunes on select.
- Sources removed while a tab screen is open: onboarding replaces the shell at the next root evaluation (0006/AC-1).
- Return from background: the same engine instance resumes the same channel; a cold launch applies AC-2a or AC-2b.
- Entitlement lapses: the paywall replaces the shell at the next root evaluation (ADR-0006).
- The channel-change event payload and any log line carry the stored key (AC-8), never the stream URL, which for Xtream carries the credentials (ADR-0003).
- Reduce Motion: scrim and tab bar appear without animation.
- VoiceOver: the tab bar is a tab group; the clock and mark are static text.

## Test plan

Integration tests drive `ShellModel` with a fake engine (recording `load`, `play`, `pause`, `stop`), fake sources with injected completion order, an injected `UserDefaults` suite and an injected clock. UI tests on the tvOS simulator cover focus, Menu and identifiers, with one smoke test for AC-2a. Identifiers: `shell.tabBar`, `shell.mark`, `shell.tab.live`, `shell.tab.guide`, `shell.tab.movies`, `shell.tab.series`, `shell.tab.search`, `shell.settings`, `shell.clock`, `shell.player`, `shell.scrim`, `shell.loading`, `shell.loading.<sourceId>`, `shell.empty`, `shell.empty.source.<sourceId>`, `shell.retry`.

| Criterion | Layer | Test |
|-----------|-------|------|
| AC-1 | ui | TBD |
| AC-2a | integration (ShellModel, fake sources, injected defaults) + ui smoke | TBD |
| AC-2b | integration (ShellModel, injected clock, completion order) | TBD |
| AC-3 | ui (fake engine state) | TBD |
| AC-4 | ui (tests a and b) | TBD |
| AC-5a | integration (ShellModel, injected clock, fake engine) | TBD |
| AC-5b | integration (ShellModel, fake engine) + ui (per route) | TBD |
| AC-6a | ui (per tab) | TBD |
| AC-6b | ui (fake engine state) | TBD |
| AC-7 | integration (ShellModel, injected clock) + ui (Guide) | TBD |
| AC-8 | integration (ShellModel, injected defaults) | TBD |
| AC-10 | ui (fake sources) | TBD |
| AC-10b | ui (fake sources) | TBD |
| AC-11 | ui (fake sources, fake credential store) | TBD |
| AC-12 | ui | TBD |
| AC-13 | ui | TBD |
| AC-14a | ui (ShellNavigator call injected) | TBD |
| AC-14b | ui (ShellNavigator call injected) | TBD |
| AC-14c | ui (ShellNavigator call injected, fake engine) | TBD |
| AC-15 | ui (fake sources, reload recorded) | TBD |
| AC-16 | ui (Live and Guide) | TBD |

## Open questions

- Menu at the top level: this spec keeps the user inside the shell (AC-4 and AC-3 alternate), which departs from the tvOS HIG expectation that Menu at the top level returns Home. Alternative: Menu on the tab bar with Live selected suspends the app.
- Is 30 seconds the right pause delay behind Movies and Search, or should audio continue muted?
