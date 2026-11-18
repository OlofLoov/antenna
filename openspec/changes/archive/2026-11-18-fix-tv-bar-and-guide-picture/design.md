# Design

## Context

Three Apple TV findings from the owner's device test on 2026-11-18. The shell draws its own tab bar (`ShellTabBar.Bar`, kept by `refresh-visual-design`) over a single player surface that is full screen on Live, a 480 by 270 box on the Guide and hidden behind Movies, Series and Search. The Guide (`GuideScreen`, `GuideGrid.Screen`) lays the box and panel on top and the grid below.

## Boards and design rules

- Bar: `TV-Shell-Menu`, `TV-Shell-Menu-Profile`, `TV-Shell-FocusedTab`, `TV-Shell-Guide-Menu`, `TV-Shell-Empty-Menu`, `TV-Shell-Loading-Menu`, `TV-Search`, `TV-Movies`, `TV-Movies-Poster-Only`, `TV-Movies-Preview`, `TV-Movies-Preview-Loading`, `TV-Movies-Preview-Poster-Only`, `TV-Movies-Trailer`, `TV-Hints-Movies`. Each now centers the pill group and hangs the profile and Settings buttons 14 pt to its right.
- Guide: `TV-Guide`, `TV-Guide-Future`, `TV-Guide-Placeholders`, `TV-Guide-Empty`, `TV-Shell-Guide-Menu`. The top block's padding goes from 48 to 120.
- Design rules followed: `design-system/live-video-keeps-playing-under-overlays` (one surface, never rebuilt), `design-system/focus-is-the-lifted-white-card` (unchanged), the tvos-shell deviations (unchanged).
- Not drawn: the moment between a highlight move and the tune. The box shows the old picture until the new stream's first frame, then the waiting look the box already has (`GuidePanel.PictureLook.waiting`).

## Decisions

### 1. Center the pills, not the pills and buttons

Options:
- Center the group of pills, profile and gear (before). The pills sit left of center by half the buttons' width, 35 pt or 70 pt, and move when a second profile appears.
- Center the pills and hang the buttons to their right (chosen). It matches the system tab bar, and the pills stay put whether or not there is a profile button.
- Put the buttons at the trailing edge beside the clock. That changes the bar's order, which `tvos-shell/the-tabs-in-order` fixes, and puts Settings far from the tabs on a remote.

`ShellTabBar.Bar` is a `ZStack`: the mark and the clock or its slot at the edges in an `HStack`, the pill capsule centered over them, and the buttons in an `.overlay(alignment: .trailing)` of the capsule with `.alignmentGuide(.trailing) { $0[.leading] - 14 }`, so they add no width to it. Focus still moves by geometry: right from Search reaches the profile button or the gear. The bar's band is `ShellTabBar.height` (104).

While the bar or the guide has focus, the legend of remote hints sits in the bottom right corner (`ControlHintScreen.corner`), so it never meets the bar and changes nothing here.

### 2. The guide leaves the bar's band empty

Options:
- Keep the picture at 48 and slide the guide down when the bar rises. Every Back would move the playing video, and the grid would jump under the scrim.
- Hide the small picture while the bar shows. It breaks `tv-guide-grid/the-channel-keeps-playing-in-a-small-picture` under the scrim.
- Start the picture and panel below the band all the time (chosen). The bar then sits over the guide where it sits over Movies and Search, which also start their content at 120.

`GuideGrid.pictureTop` is `ShellTabBar.height + 16` (120). `GuideGrid.Screen` and the shell's picture box both read it, so the box and its slot stay together. The grid loses 72 pt: `GuideModel.visibleRows` goes from 7 to 6 whole rows, plus the one drawn cut off at the bottom.

### 3. The small picture follows the highlight

Options for when to tune:
- On every highlight move. Swiping down ten rows would open ten connections in a row, and providers limit connections per account.
- On select only (before). The picture shows a channel the viewer is not looking at.
- When the highlight rests on a row for 0.7 s (chosen). It is long enough that a held or repeated swipe passes rows without tuning, short enough to feel like it follows. Moving left or right on the same row does not restart the wait.

Options for the engine:
- A second engine for the preview. Two connections at once, and the full-screen player would have to hand over. Ruled out.
- The shell's one engine, loading the previewed stream in place of the old one (chosen). `ShellModel.guideHighlightMoved(to:)` waits on `dependencies.sleep(guideRestDelay)` and then tunes through the same `load` as every other tune, with `remember: false`. That load skips `SessionTracker`, so the previewed channel is not stored as the last channel and does not count toward Recents.

Options for what Back does:
- Keep whatever the picture shows. Browsing the guide would silently change the channel, and a viewer who opened the guide to look ahead loses their game.
- Return to the channel from before the guide unless the viewer picked one (chosen). `ShellModel.guideReturn` holds the channel tuned when the picture first followed the highlight, nil when it never did. Leaving the Guide tab for any other tab tunes it back through `tune`, which stores it as the last channel again. When nothing played before the guide, the previewed channel stays and is adopted as the last channel, because the empty Live screen would be wrong with channels loaded.

Select and Watch go through `ShellModel.pick`, which calls `keepGuidePreview` first: the channel in the picture becomes the last channel, `SessionTracker` starts its ten-second count, and `guidePicks` goes up so the shell shows the info bar, as a tune from the guide does. The stream does not load again. The reminder banner's Watch goes through `pickFromOverlay` and so through `pick` too. Any other tune (`tune`, used by the launch and Top Shelf) clears `guideReturn`, because the viewer chose that channel.

The guide pins its current group before the first preview (`overlay.tuned(from: group)` when no group was tuned from yet), so the rows do not switch when the picture's channel, which picks the default group, changes.

The remote hints for the Guide stay. "Click: Watch, or details for later" and "Back: Tab bar" still say what the remote does.

### Platforms

Apple TV only. The iPhone, iPad and Mac guides have no small picture and no resting highlight: a tap on a programme is the choice, so there is nothing to follow. Their tab bar and sidebar are the system's, already centered by the system.

## Identifiers

`shell.tabs` (new) names the capsule around the tab pills. The centering test measures it, because a focused pill reports its padded frame and the others report their text. The tests also read `shell.tab.live`, `shell.settings`, `shell.player`, `guide.pip`, `guide.channel.<row>` and `shell.debug.engine`.
