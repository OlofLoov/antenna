# Proposal

## Why

> When navigating to the top menu, should one really have to navigate all the way up? What about just pressing back or something?

The living-room viewer deep in the Movies rows wants one press to get back to the tab bar, the way Apple's own TV, Music and App Store apps work. Back already moved the highlight to the bar, but the rows stayed scrolled down, so the next swipe down landed somewhere in the middle, and nothing on screen said Back does this. Back in the bar went to Live, and Back on Live went to the bar, so Back never left the app. Apple's guidelines say Back at an app's top level goes to the Home Screen.

Afterwards the viewer presses Back once to reach the tab bar from anywhere in a tab, finds the rows back at the top, and presses Back again to go to the Home Screen.

## What Changes

- Back from anywhere on the top level of Movies, Series and Search moves the highlight to that tab in the bar and scrolls the tab back to its top. Swiping up from the topmost item does the same.
- Back with the highlight in the tab bar goes to the Apple TV Home Screen, over every tab. Swiping down or selecting Live still brings back the full-screen picture.
- Live full screen keeps its own rules: Back closes the channel overlay, the info panel, the info bar or the channel number first, then shows the tab bar.
- Screens opened from a tab (genre grid, See all, title page, Settings) still close on Back.
- No screen keeps Back for itself, so pressing it again and again always reaches the Home Screen. The owner also wrote: "on my non Apple TV remote I was not able to actually quit the app?" A TV's own remote has Back and arrows but no TV button. "Who's watching?" and the loading checklist in onboarding held on to Back; both now let it through.
- On iPhone and in a narrow iPad window, tapping the tab that is already open scrolls Live's list, the Guide, Movies and Search back to their top, and closes a movie or series page open in Movies.
- The remote hints say where Back goes: "Tab bar" on Live full screen, the Guide and the Movies and Series rows, "Home Screen" in the tab bar. On Live full screen the Back line replaces "Play/Pause, Pause", which stays on the info bar.

Out of scope:
- Holding Back, which goes to the Home Screen from anywhere and is handled by tvOS.
- The Guide keeps its place when Back reaches the bar; it has no top to scroll to.
- Mac and the iPad sidebar layout, which have no tab bar to tap.

## Capabilities

### New Capabilities

None.

### Modified Capabilities
- `tvos-shell`: "Back from a tab goes to the tab bar" and "Back from the tab bar goes to the Home Screen" replace "Menu from the top of a tab reaches the tab bar" and "Menu from the tab bar goes back to Live". "Back to full screen from the tab bar" loses Back.
- `profiles`: Back on "Who's watching?" goes to the Home Screen.
- `first-run-onboarding`: Back on the loading checklist goes to the Home Screen.
- `live-tv-on-iphone-ipad-mac`: "Tap the open tab to go back to the top".
- `control-hints`: the Live full-screen legend lists Back for the tab bar, and the tab bar's legend says Back goes to the Home Screen.

## Impact

- Platforms: tvOS, iOS (iPhone and narrow iPad). Mac is covered in design.md.
- Depends on `add-control-hints` (archived) for the legend.
- Code: the Apple TV shell, the Movies, Series and Search screens on Apple TV, "Who's watching?", the onboarding checklist, the iPhone tab bar and its screens, `ControlHintScreen` in AntennaCore.
