# Design

## Context

The Apple TV shell (`ShellScreen` in `ShellView.swift`) has one `onExitCommand` that routes Back by where the highlight is. Before this change:

- On Live full screen, Back closed the info panel, the channel overlay, the number entry or the info bar first, then raised the tab bar with Live highlighted.
- In a tab's content it moved the highlight to that tab in the bar. Movies already did this from any poster, not only from the top, but the rows stayed where they were. The banner stayed scrolled away, and the next swipe down landed on whatever poster sat under the bar.
- In the bar, `ShellModel.menu(from: .bar)` lowered the bar over Live, or opened Live from any other tab. Back on Live raised the bar again, so Back never left the app. The spec said so outright: "Menu SHALL never leave the app from inside the shell."

Screens opened from a tab have their own `onExitCommand` deeper in the tree and keep it: the genre grid and See all (`ShelfTVScreen.grid`), the title page (`TitleScreen`), the movie player (`ShelfPlayerView`), Settings (a full-screen cover), multi-view and the reminder banner.

## What Apple says

Human Interface Guidelines, Remotes (checked 2026-11-14):

> In almost all cases, open the parent of the current screen when people press the Back button. At the top level of an app or game, the parent is the Apple TV Home Screen; within an app, the parent is defined by the app hierarchy, and isn't necessarily the previous screen.

> Note that people press and hold the Back button to go to the Home Screen from any location.

The same page's button table gives Back in an app as "Returns to previous screen. Exits to Apple TV Home Screen."

Human Interface Guidelines, Tab bars, tvOS:

> Regardless of a tab's contents, focus always returns to the tab bar at the top of the page when people press Menu on the remote.

Apple's TV, Music and App Store apps behave this way: Back in a tab's content scrolls it to the top and highlights the tab, and Back in the tab bar goes to the Home Screen. Swiping up from the first row also reaches the bar.

## Decisions

### The tab bar is the app's top level

Back with the highlight in the bar, on a tab, the profile button or Settings, is not handled by the app. `ShellBack` passes `nil` to `onExitCommand` while `barHasFocus` is true, so the press reaches tvOS, which suspends the app and shows the Home Screen. Options considered:

- Keep Back in the bar going to Live, and Back on Live going to the bar (rejected). This is what the owner ran into. It makes the full-screen picture the root and gives Back no way out, against the guideline above.
- Back in the bar over another tab goes to Live; Back in the bar over Live goes to the Home Screen (rejected). It takes three presses from Movies to leave, and Back means two things in the same bar.
- Back in the bar always goes to the Home Screen (chosen). One rule for every tab, the same as Apple's apps. Swiping down or selecting Live still brings back the picture, and the bar's legend says what Back does.

The Live full-screen rules are untouched: Back closes the info panel, the overlay, the number entry or the info bar first, then raises the bar (`tvos-shell/menu-shows-the-tab-bar-over-the-picture`, the `tv-channel-overlay` rules). Only the step after the bar changes.

`MenuOrigin.bar` and the `.bar` branch of `ShellModel.menu(from:)` go away, since the shell never sees that press. `menu(from:)` is no longer `async`: the only `await` was `showLive()` on that branch. The unit test that resumed a paused video through Back from the bar now does it through selecting Live, the remaining way back.

### No screen keeps Back

The owner also reported that a TV's own remote could not leave the app. A TV remote through HDMI-CEC, or a universal IR remote, often has Back, the arrows and OK but no TV button, and its Back reaches the app as the same Menu press as the Siri Remote's. So one rule covers every remote: repeated Back always ends at the Home Screen. Holding Back for the Home Screen is a Siri Remote gesture these remotes may not send.

The chain from each starting point, after this change:

| Start | Back, press by press |
|---|---|
| Live full screen | tab bar, Home Screen |
| Live with the info bar, the channel overlay, the info panel or a half-typed channel number | that layer closes, tab bar, Home Screen |
| Live loading, empty or failed screen | tab bar, Home Screen |
| Multi-view | one channel full screen, tab bar, Home Screen |
| Reminder banner | banner closes, then as the screen under it |
| Guide grid; Watch or Remind me in its panel | (panel back to the grid), tab bar, Home Screen |
| Movies or Series rows | tab bar (rows at the top), Home Screen |
| Genre grid or See all | rows, tab bar, Home Screen |
| Title page; movie or episode player | player closes, page closes, rows, tab bar, Home Screen |
| Search, keyboard or results | tab bar, Home Screen |
| Settings and its pages | pages pop, Settings closes onto its button in the bar, Home Screen |
| "Who's watching?" | Home Screen (was: nothing) |
| First-run welcome | Home Screen (unchanged) |
| Onboarding checklist while loading | Home Screen (was: nothing) |
| Onboarding checklist with nothing loaded | back to check the link (unchanged) |
| Paywall | Home Screen (unchanged) |

Two screens held on to Back besides the bar. `ProfileFlow` had an empty `onExitCommand {}` on "Who's watching?" because nothing is behind it; the spec said Menu there "does nothing". Nothing behind it is the reason Back should go to the Home Screen, so the handler goes. `OnboardingProgressScreen` had an `onExitCommand` that acted only when nothing loaded and swallowed the press otherwise; it now passes `nil` while sources load.

### Scrolling back to the top

`ShellScreen` publishes `barHasFocus` as the `shellBarFocused` environment value. `ShellBackToTop` (`.scrollsToTopFromTabBar()`) holds a `ScrollPosition` for the tab's scroll view and scrolls it to the top edge when `shellBarFocused` turns true. It is on the Movies and Series rows (`ShelfTVScreen.rows`) and on Search's results (`SearchTVScreen`). Options considered:

- An `onExitCommand` on each tab's scroll view that scrolls and moves the highlight itself (rejected): a second place that decides where Back goes, and swiping up to the bar would not scroll.
- A counter on `ShellModel` bumped by Back, read by each tab (rejected): the screens get the model only to read it, and swiping up is missed again.
- Scroll when the highlight reaches the bar, however it got there (chosen): one rule covers Back and swipe up, and nothing else changes focus to the bar from inside a tab.

The scroll animates for 0.3 seconds, and without animation when Reduce Motion is on.

The Guide keeps its place. Its rows are a time grid that opens on the playing channel and the current programme, and the bar shows over it as before.

The genre grid and See all close on Back as before (`movies-and-series-browsing/browse-a-genre-or-sort-the-lot`): Back there returns to the rows, and a second Back reaches the bar.

### Remote hints

`ControlHintScreen.tabBar` lists Back as "Home Screen" instead of "Back to Live". The Guide and the Movies and Series rows already list Back as "Tab bar". Live full screen had five lines, the most a legend holds, and no Back line. Back is the answer to the owner's question, so it replaces "Play/Pause, Pause" there. Play/pause is a labeled button on the remote, and the info bar's legend, which shows when the viewer pauses, keeps it. Search has no legend and gets none.

### Boards

The bar and the screens look the same, so no board changes. The change follows `TV-Shell-Menu`, `TV-Shell-FocusedTab` and `TV-Shell-Guide-Menu` for the bar, and the `design-system` focus rules. `TV-Hints-Live` draws the legend over the info bar, which keeps Play/Pause. The legend on the plain full-screen picture and in the tab bar is not drawn; its lines come from `ControlHintScreen.hints`.

### iPhone, iPad and Mac

The iPhone tab bar, and an iPad window narrow enough for it, are a SwiftUI `TabView` (`CompactTabs` in `RootView.swift`). UIKit scrolls a tab back to its top on a second tap only when the tab's root is a navigation controller, and Live, Guide, Movies and Search have none; Settings has a `NavigationStack` and keeps the system's behavior. So the app counts the taps itself:

- `CompactTabs` passes `TabView` a binding whose setter sees a tab that is already selected and adds one to `taps[tab]`. Each tab's content gets its count as the `tabTaps` environment value.
- Movies and Search put `scrollsToTopOnTabTap()` on their scroll view: a `ScrollPosition` scrolled to the top edge when `tabTaps` changes.
- Live's channel list is a `List` and the Guide's channels sit under a `ScrollViewReader` that already anchors them, so both scroll their first row to the top through the reader instead of a `ScrollPosition`.
- Movies also closes an open movie or series page on the same tap, as a navigation stack pops to its root. One tap does both, where UIKit takes two, because the page covers the rows and nothing on screen would show the first tap's scroll.
- Reduce Motion drops the 0.3 second animation.

Options considered: a `NavigationStack` around each tab to get the system's behavior (rejected: the screens draw their own top bars and the Movies page is not a pushed destination, so the stack would add a bar or need hiding everywhere); counting taps through `onTapGesture` on the tab items (rejected: `TabView` does not expose its items).

Mac and an iPad in the sidebar layout have no tab bar. The sidebar is always on screen, so there is no bar to reach and no second tap to count, and nothing changes there. Escape already closes a title page on Mac and iPad (`title-detail-and-episode-picker/back-to-where-you-were`).

## Tests

- `ShellUITests` on tvOS: repeated Back from the channel overlay leaves the app in three presses, and from a genre grid in three; Back from the bar over Live, and from Movies through the bar, leaves the app (`XCUIApplication.state` goes to the background); Back from the genre chips at the bottom of Movies lands on the Movies tab with the banner's Play button back on screen, and one swipe down focuses it. `testBackToFullScreen` drops Back from the ways down from the bar.
- `ControlHintsTVUITests`: the legend reads "Back, Tab bar." on the picture and "Back, Home Screen." in the bar.
- `ControlHintsTests` in AntennaCore: Back reads "Tab bar" on Live, the Guide and the rows, "Home Screen" in the bar.
- `ProfileUITests` on tvOS: Back on "Who's watching?" leaves the app; the old check that Menu stays on the picker goes.
- `ShelfUITests` on iPhone: tapping Movies again after scrolling brings the banner back.
- `ShellNavigationTests`: selecting Live from the bar over a paused tab resumes it without a reload.
