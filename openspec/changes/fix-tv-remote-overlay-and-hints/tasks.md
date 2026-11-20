# Tasks

## 1. Overlay columns

- [x] 1.1 `ChannelOverlay.Layout` aligns its 1640-point row leading
- [x] 1.2 `ShellUITests.testTheColumnsKeepTheSafeEdgeWhileSwitchingGroups`

## 2. Picture after multi-view

- [x] 2.1 `PlayerSurfaceView` removes the picture and held-frame layers only from its own view
- [x] 2.2 The shell's scripted engine has a stand-in picture layer and the `shell.debug.picture` probe
- [x] 2.3 `MultiViewTVUITests.testAfterLeavingAChannelPickedFromTheListPlaysWithItsPicture`

## 3. One press, one action

- [x] 3.1 `HeldPress` in AntennaCore with `HeldPressTests`
- [x] 3.2 `HoldButton` on the full-screen picture, multi-view tiles, Try again and the movie player; timeshift's held play/pause on `HeldPress`
- [x] 3.3 `scripts/check-rules.sh` allows a long press only in `HoldButton`
- [x] 3.4 The hold tests for the picture, tiles and error check the single outcome

## 4. Remote hints placement

- [x] 4.1 Drop `ControlHintScreen.corner`; `ControlHints.Placed` draws the legend at one place for both hosts
- [x] 4.2 Boards `TV-Hints-Live`, `TV-Hints-Overlay`, `TV-Hints-Movies` and `TV-Settings-Hints` put the legend at top 124, right 80
- [x] 4.3 `ShellUITests.testRemoteHintsSitInOnePlaceOnEveryScreen`

## 5. Verify

- [x] 5.1 Each requirement has a test citing `<capability>/<requirement-slug>`
- [x] 5.2 `/opsx:verify` passes
