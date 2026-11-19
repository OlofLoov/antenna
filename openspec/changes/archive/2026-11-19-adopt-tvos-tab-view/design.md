# Design

## Context

The owner's answer of 2026-11-19 to `refresh-visual-design` open question 1, recorded there as decision 9. The shell today is one `ZStack` in `ShellScreen`: the picture, the live layer, the open tab's content, the zap bar, the info panel, the scrim, the bar and the overlay, with one `FocusState<ShellFocus?>` routing focus between them and `ShellModel.menu(from:)` deciding what Menu does.

Board: `TV-Shell-TabView` (the system bar over Live with the dimmed picture, Settings as the last tab).

Design-system requirements it follows: "Liquid Glass stays on the navigation layer", "Content clears the tab bar", "Focus is the lifted white card", "Apple TV content stays in the safe area".

## Goals / Non-Goals

**Goals:**
- The system tab bar on Apple TV, with the system's Menu and focus behavior.
- Live keeps playing full screen under the bar; Movies, Series and Search keep pausing it.

**Non-Goals:**
- Changes to the channel overlay, zap bar, guide grid or multi-view.

## Decisions

### 1. Live is a tab whose page is the picture

Options considered:
- **The picture behind the `TabView`.** The engine's surface stays where it is and every tab draws over it. Live's page is clear. Keeps the stream untouched when tabs change, but the system bar's backdrop expects content of its own.
- **The picture inside Live's page.** Moves the surface into the tab, so leaving Live tears it down and the Guide's small picture needs a second surface.

Decision: the picture stays behind the `TabView`, and Live's page is clear. The Guide's small picture keeps its frame.

### 2. Settings is the last tab

Settings moves from a full-screen cover to a tab after Search. The profile button moves to the top of Settings' lead column. "Closing Settings" becomes moving to another tab.

### 3. The clock moves into the pages

The system bar has no trailing slot. Live's info bar and overlay already show the time; the Guide header shows it; Movies and Series show it in the hero's top right inside the safe area.

## Risks / Trade-offs

- [Focus routing] → `ShellFocus.tab(_)` and `.settings` go; the system owns focus in the bar. Tests that assert `shell.tab.*` focus move to the tab bar's buttons by label.
- [Menu] → the system handles Menu from the bar, so `ShellBack` keeps only the layers inside a page.

## Migration Plan

None. No stored data changes; the restored tab keeps its key.

## Open Questions

None.

## Findings while building

Measured on the tvOS 26.5 simulator with the `channels` and `titles` scenarios.

- The system bar opens a tab as the highlight lands on it, and calls the
  selection binding again on select over the open tab. There is no way to
  move along the bar without switching pages, so "Moving along the bar does
  not switch tabs" goes, replaced by "The page follows the highlight in the
  tab bar". Passing over Movies, Series or Search pauses the video and
  coming back resumes it; tab changes queue in `ShellModel.tabChange`, so a
  fast run along the bar settles in order. Pages opened this way must not
  take focus themselves: Movies, Series and the empty Guide check
  `shellBarFocused` before they move it.
- Select on the open tab moves the highlight into its page
  (`ShellModel.reselects`): the picture on Live, the grid on the Guide,
  Play on Movies and Series, the keyboard on Search.
- Left to itself the bar stays over the full-screen picture. Live and the
  Guide hide it with `toolbarVisibility(.hidden, for: .tabBar)` until the
  highlight is in it. Menu with nothing open over the picture is left to
  the system, which shows the hidden bar with Live highlighted, so "Menu
  shows the tab bar over the picture" holds without shell code.
- Once the highlight goes into a page the system bar slides away, and a
  swipe up from the page's top does not bring it back, with or without
  `toolbarVisibility(.visible)`. Back does. "Back from a tab goes to the tab
  bar" now names Back only, with a scenario for the swipe up.
- SwiftUI on tvOS has no focus callback for "the highlight is in the tab
  bar" (`onFocusChange` is not on tvOS). `ShellBarFocus` watches
  `UIFocusSystem.didUpdateNotification` and checks whether the focused item
  sits in a `UITabBar`. The dimming, the remote hints legend (`.tabBar`),
  the scroll back to the top and the bar's visibility over Live and the
  Guide all read that one value.
- When Live opens from code (a pick in the Guide or Search, or the shell
  appearing after "Who's watching?") the focus engine can put the first
  highlight in the bar. The shell sends it to the picture when that
  happens within 800 ms of Live opening from code, and on appearance.
- The tab bar items take accessibility identifiers and traits from the
  tab's label, so `shell.tab.<tab>` stays, Settings keeps `shell.settings`,
  and the open tab carries the selected trait.
- Settings is a tab, so `ShellModel.settingsOpen`, its full-screen cover
  and `ShellModel.openSettings()` go. Settings opened from Movies keeps the
  hold, as on iPhone and iPad.
- The info bar's clock sits top right of the screen while the info bar
  shows (`zapBar.clock`); the Movies and Series hero draw `shell.clock` level
  with the bar. `ShellTabBar` is gone; its clock is `TVClock`.
- Under the system bar a row the highlight enters lands at 519, a point
  over the preview's 520 pt foot, where it landed about 545 under the old
  bar. Moving `ShelfTVScreen.rowTop` did not move it, so the row is placed
  by the focus engine's own scroll here; `ShelfPreviewTVUITests` accepts 518.
- The Guide page stays alive between visits in the tab view, so it opens
  again on what is on now each time it appears.
- The reminder banner sits in the open page rather than over the tab view,
  where the focus engine would not give it the highlight.
- A tab opened from code with nothing to focus, such as Search from the
  channel overlay, leaves the highlight on its tab in the bar; one swipe
  down reaches the keyboard, as before.
- Select on Live in the bar is not reported when Live is open, so a failed
  stream loads again when the highlight comes down from the bar onto it,
  by select or swipe.
- Boards: `TV-Shell-TabView-Movies`, `TV-Shell-TabView-Guide` and
  `TV-Shell-TabView-Settings` draw the other states. `TV-Shell-Menu`,
  `TV-Shell-FocusedTab`, `TV-Shell-Guide-Menu`, `TV-Shell-Menu-Profile`,
  `TV-Shell-Empty-Menu` and `TV-Shell-Loading-Menu` drew the custom bar and
  are deleted. The `TV-Movies*`, `TV-Hints-Movies` and `TV-Search` boards
  still draw the old bar over their page; for the bar itself the
  `TV-Shell-TabView` boards win.
- Two bar bugs the owner saw on a device with the custom bar: the bar sat
  lower over the Guide than over the other tabs, and the first and last
  tabs sat too close to the capsule's ends. The system bar places itself
  and keeps its own insets, so the app draws no bar, no padding and no
  fill or border next to glass. `testTheBarSitsInTheSamePlaceOnEveryTab`
  compares the tabs' frames over Live, the Guide, Movies and Settings, the
  bar's top at 46 pt, and the equal space from the screen's center to the
  first and last tab.
- Why earlier fixes did not hold: the custom bar was drawn by the app in
  each screen's own layout, with hand-set heights and paddings
  (`ShellTabBar.height`, the Guide's picture offset, the profile and
  Settings buttons hung off the pill group). Each fix moved one of those
  numbers, and the next screen or a device with a different safe area
  undid it. The system bar removes those numbers: the app places nothing
  in the bar. Run against the custom bar (main before this change), the
  frame test fails on the edge check (308 pt from the center to Live
  against 398 pt to Settings). With that check removed, its frame
  comparison over the Guide passed on the simulator, so the device's Guide
  offset did not reproduce there.
