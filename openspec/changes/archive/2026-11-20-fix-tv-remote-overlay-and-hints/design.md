# Design

Four Apple TV bugs from the owner's test on a real Apple TV, 2026-11-19. Each section gives the cause, where it came from, the fix and the test that fails without it.

## Boards and design rules

- Overlay: `Main`, `Main-Empty`, `TV-Hints-Overlay`. Follows design-system/apple-tv-content-stays-in-the-safe-area.
- Remote hints: `TV-Hints-Live`, `TV-Hints-Overlay`, `TV-Hints-Movies`, `TV-Settings-Hints`. Each board now draws the legend at the same place, top 124, right 80.
- Multi-view: `TV-MultiView-Two`. Nothing drawn changes.

## 1. The overlay's columns left the safe edge

Cause: `ChannelOverlay.Layout` fixed its row of columns at 1640 points with `.frame(width: 1640)`, which centers its content. The panel slot is empty while the highlighted channel is not in the shown group, which is the case as soon as the user moves up or down the group column. The row then shrank to the groups and channels, 1061 points, and the frame centered it, 290 points from the left. With the highlight on a channel the panel filled the rest, so the columns sat at the edge.

History: there since the panel arrived in `f7063316` (feat(tv): add the overlay's now-and-next panel). Not an earlier fix undone; `ee720d30` and `16742d25` fixed focus and scrolling in the same column and never touched the frame.

Fix: `.frame(width: 1640, alignment: .leading)` in the layout component, so every screen that uses it (the shell's overlay and the multi-view picker) keeps the edge whatever the panel holds.

Test: `ShellUITests.testTheColumnsKeepTheSafeEdgeWhileSwitchingGroups` compares the group row's and the channel header's frames while changing channels and after moving to another group. Without the fix the group row is at x 370 instead of 80.

## 2. A black picture after multi-view

Cause: the demuxing engine draws into one `AVSampleBufferDisplayLayer`, which can sit in one view at a time. Leaving multi-view trades the single player's engines with the kept tile's, and the shell's picture view is rebuilt to host the kept layer. The multi-view screen is still on screen for the dismissal and redraws tile 2 once more. Its `PlayerSurfaceView` now finds the tile's new, empty engine with another layer, and `host(_:hold:)` called `removeFromSuperlayer()` on the layer it last hosted, which by then sat in the shell's view. The stream played on with sound, size and format, but its picture was in no view. Every later channel loads into the same engine and layer, so it stayed black until a new multi-view put the layers in new views. HLS was not affected: `AVPlayerLayer`s attach to a player and do not move.

Reproduced on the tvOS simulator with a local M3U of three paced MPEG-TS streams and logging in `host`: the tile view's update at the end of the dismissal removed the layer from the new shell view.

History: there since multi-view arrived in `620812e7`. That change rebuilt the shell's surface with `.id(model.multiViewEnds)` to take the layer back, which works until the tile view's last update runs after the rebuild. Not an earlier fix undone.

Fix: `PlayerSurfaceView` removes a layer only when it is still in its own view (`CALayer.leave(_:)`), for the picture and the held frame, on every platform. iPad and Mac multi-view use the same view and get the fix.

Options considered:
- Stop the tile view from updating after the exchange, by making `TileEngines.engines` observable or hiding the tiles before the trade. It fixes this path only; any other screen that moves an engine's layer can do the same.
- Take the layer back in the shell's view on every update. Two live views would then pass the layer back and forth.
- Remove only what this view still hosts. Chosen: the view that last took the layer keeps it.

Test: `MultiViewTVUITests.testAfterLeavingAChannelPickedFromTheListPlaysWithItsPicture`. The scripted engine in the shell's UI tests now has a stand-in picture layer that `PlayerSurfaceView` hosts like the demuxer's, and the `shell.debug.picture` probe says whether a view holds it. Without the fix the probe reads `missing` after leaving.

## 3. One press did two things

On Apple TV a SwiftUI `Button` fires its action when select is released, also after a hold that a `LongPressGesture` already acted on. Every button that paired a click with a hold did both:

| Where | Hold | Release also did |
|---|---|---|
| Full-screen picture | info panel | opened the channel list over it |
| Multi-view tile | tile actions | opened the picker |
| Try again on an error | try again | tried again a second time |
| Movie and episode player | Audio and Subtitles | play or pause (guarded) |

History: `e2322cf5` (feat(app): skip and scrub in movies and episodes) met this in the movie player and added a guard there, `panelOpenedAt`. Play/pause held for live got its own guard, `takeHeldPress`, in `2c0057b6`. Neither reached the shell's picture (`80f464f4`, `620812e7`) or the error (`PlayerTVFailure`), which kept a bare `simultaneousGesture(LongPressGesture)`. The simulator does not send the release as a click, so no UI test caught it.

Fix: `HeldPress` in AntennaCore marks a press a hold acted on and swallows the click that ends it within 1.5 seconds. `HoldButton` in `Apps/Shared/Components` is the one way to put a click and a hold on a button; the four places above use it, and timeshift's held play/pause uses `HeldPress`. `scripts/check-rules.sh` fails on any other `LongPressGesture` or `onLongPressGesture` in the apps.

Other handlers checked and left alone:
- `onMoveCommand` on the shell and the guide grid: the shell's handler acts only with focus on the picture, and a swipe down from the bar is guarded by `barLowered`.
- `onExitCommand` in the shell, guide, multi-view, title, person, reminder banner and player: the innermost handler takes Menu; multi-view's Menu closes the actions without leaving (`testActionsFullScreenAndBack`).
- `onPlayPauseCommand` with the held play/pause recognizer: guarded by `takeHeldPress`.
- Held left and right: a click skips, then the hold scans, as `timeshift-catch-up-and-start-over/skip-scan-and-drag` asks.
- Overlay and guide rows: a hold opens the system context menu, which takes the release itself.
- iPhone, iPad and Mac: `onTapGesture(count: 2)` sits before the single tap on the Live picture, the movie player and multi-view tiles, so a double tap is not also a single tap.

Tests: `HeldPressTests` (AntennaCore). UI tests assert the single outcome after each hold: `PlayerPanelTVUITests.openPanel` (no channel list), `MultiViewTVUITests.testActionsFullScreenAndBack` (no picker), `PlayerErrorTVUITests.testHoldingSelectOnTheErrorTriesAgainWithoutAPanel` (one load). These pass on the simulator with or without the fix, since it never sends the release; the unit test and the `check-rules.sh` grep are what fail on the broken code.

## 4. The remote hints moved between screens

Cause: by design. `add-control-hints` gave each screen a corner (`ControlHintScreen.corner`): top right over video, the info bar and the players, bottom right elsewhere. The owner wants one place.

Fix: the corner is gone from AntennaCore. `ControlHints.Placed` draws the legend at `ControlHints.placement`, top right, 60 + 64 points from the top so it clears the 34-point clock on the overlay, the tab bar and the guide, and 80 from the right. Both hosts, the shell and Settings, use it. Top right keeps it clear of the info bar and the player bars along the bottom.

Test: `ShellUITests.testRemoteHintsSitInOnePlaceOnEveryScreen` reads the legend's top right corner on Live, the overlay and the tab bar. Before the fix the overlay's legend sat at y 780.
