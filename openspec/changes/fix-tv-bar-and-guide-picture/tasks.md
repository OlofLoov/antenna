# Tasks

## 1. Bar and guide layout

- [x] 1.1 `ShellTabBar.Bar` centers the pill capsule and hangs the profile and Settings buttons 14 pt to its right; `ShellTabBar.height` names the 104 band
- [x] 1.2 `GuideGrid.pictureTop` (120) places the guide's top block and the shell's picture box below the band; `GuideModel.visibleRows` is 6
- [x] 1.3 Boards: the bar boards center the pills, the TV-Guide boards start the top block at 120

## 2. The small picture follows the highlight

- [x] 2.1 `ShellModel.guideHighlightMoved(to:)` waits 0.7 s on the shell's clock and tunes the one engine without storing the channel or counting it
- [x] 2.2 `ShellModel.pick` keeps the previewed channel without a reload and shows the info bar; leaving the Guide tab tunes back to the channel from before
- [x] 2.3 `GuideScreen` reports the highlighted row's channel and pins the current group

## 3. Verify

- [x] 3.1 Each requirement has a test citing `<capability>/<requirement-slug>`: `GuidePreviewTests`, `ShellUITests.testTheBarSitsInTheSamePlaceOnEveryTab`, `testTheSmallPictureFollowsTheHighlight`, `testWatchKeepsTheChannelInTheSmallPicture`
- [x] 3.2 The tvOS `ShellUITests` class, which holds the guide tests, passes on a local simulator
- [x] 3.3 `/opsx:verify` passes
