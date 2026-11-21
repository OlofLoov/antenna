# Hangs while browsing fast

## Why

The owner, on an iPhone with a large provider, saw the app stop
responding while flicking quickly through Movies and Series. The system
logged that it could not get a snapshot from the app, and SwiftUI logged
"onChange(of: Rotation) action tried to update multiple times per frame".
A movie or series watcher who scrolls a big library expects the screen to
follow the finger and the posters on screen to arrive first.

## What Changes

- A drag on the Movies or Series banner tells the banner's timer once when
  the finger lands and once when it lifts or the scroll view takes over.
  Before, every touch move restarted the timer and redrew the banner,
  several times a frame.
- A poster card that scrolls away stops waiting for its picture, and once
  no card waits for that picture its download and decode stop. Before,
  every card a fast scroll passed kept its download running, and the
  posters on screen queued behind them.
- The poster and logo loaders are made once for the app instead of on
  every redraw of the window root, so a redraw there no longer redraws
  every poster and logo.

Out of scope:
- The tab bar's touch recognizer and the rotation stall, which another
  change handles.
- Channel logos keep their current loading; they are small and shared by
  many rows.

## Capabilities

### Modified Capabilities

- `movies-and-series-browsing`: Browsing stays responsive gains scenarios
  for a fast scroll and a drag on the banner.

## Impact

- `Apps/Shared/Persistence/PosterCache.swift`, `Apps/Shared/Views/Shelf/ShelfContent.swift`,
  `Apps/Shared/Views/Shelf/ShelfSync.swift`, `Apps/Shared/Components/Shelf/ShelfBannerLayouts.swift`.
- `BannerTouch` in AntennaCore next to `BannerPager`.
- No data model, sync or dependency change.
