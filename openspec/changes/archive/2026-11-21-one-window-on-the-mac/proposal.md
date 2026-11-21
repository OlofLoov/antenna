# One window on the Mac

## Why

A Mac viewer who pressed Command-N, or chose File > New Window, got a
second Antenna window with its own Live, Movies and Series. That window
loaded every source and the whole catalogue again and opened its own
provider connection. Many accounts allow one connection at a time, so the
second window could stop the channel playing in the first. After this
change the Mac keeps one window, and File > New Window only brings it back
after the viewer closed it.

## What Changes

- File > New Window and Command-N open a window only when none is open,
  and are dimmed while one is.
- A playlist file, setup link or Handoff that arrives on the Mac goes to
  the open window instead of opening another.
- iPad stays single-window: the app does not declare support for more than
  one scene, which this change leaves alone.

Out of scope:
- Holding the libraries at app scope, so a second window would share them.
  With one window there is nothing to share.
- iPhone and Apple TV, which have one window.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `live-tv-on-iphone-ipad-mac`: adds "One window on the Mac".

## Impact

- `Apps/Shared/AntennaApp.swift` and `Apps/Shared/Commands/OneWindowCommands.swift`.
- A Mac UI test in `AntennaMacJourneys`, run by a new step in `.github/workflows/screenshots.yml`.
- `Apps/Journeys/Snap.swift` already presses Command-N when a CI Mac starts
  the app with no window; that still works.
- No data model, sync or dependency change.
