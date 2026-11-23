## Why

The movie and series watcher browses Movies and Series on Apple TV with the
remote. The owner found on 2026-11-23 that moving up from one row to the row
above, as from Recently added back to Continue watching on Series, lags: the
row above stays under the preview at the top of the screen for a moment,
then slides down into place. Moving down never did this.

Afterwards a move up brings the row above straight to its place just under
the preview, in one movement, on Movies and Series.

## What Changes

- The "Preview of the focused title on Apple TV" requirement gets a scenario
  for moving up to the row above.
- A row the highlight moves into while it sits under the preview starts
  scrolling to its place at once, instead of after the 350 ms the screen
  waits for the focus engine's own scroll on a move down.
- The row's resting place takes the tab bar's inset into account, so its
  header lands 16 pt under the preview as designed, not 42 pt.

Out of scope:
- iPhone, iPad and Mac. They have no preview and no focus-driven row
  placement, so nothing changes there.
- The `_UITabBarTouchDetectionGestureRecognizer ... possible phase` console
  line. It comes from the system tab bar, not from the app (see design.md).
- Moves down, along a row, and back to the banner, which behave as before.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `movies-and-series-browsing`: "Preview of the focused title on Apple TV"
  adds the scenario "Moving up to the row above".

## Impact

- Apps: `ShelfTVScreen` and `ShelfPreviewFocus` on tvOS, a unit test in
  `AntennaTVTests` and a UI test in `AntennaTVUITests`.
- Builds on `adopt-tvos-tab-view` and the preview as they are. Blocked on
  nothing.
- No new container or dependency, so the C4 diagrams stay as they are.
