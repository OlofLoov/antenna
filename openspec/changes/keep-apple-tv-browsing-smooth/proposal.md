## Why

A tester on a real Apple TV reported on 2026-11-23 that loading and browsing
Movies and Series is laggy, that "the menu is not always in focus", and that
the menus must hold 60 fps. On the tvOS 27.2 simulator, with a library of
9 000 movies and 3 500 series in 80 and 40 categories, every move between
posters redrew the whole screen: the banner, every row on screen and the
preview's mask. Two focus faults showed up on the same library. Back from a
movie played from a row, the highlight landed on the banner's Play button
instead of the poster. Swiping down from Movies in the tab bar, after a
visit to Series, landed on a poster or on My list instead of Play.

## What Changes

- On Apple TV a move between posters redraws the posters, the row's place
  and the preview. The banner and the rows no longer redraw for it.
- Rows passing under the preview fade into a layer of the background color
  instead of a mask over the whole scroll view, so the rows are not drawn
  off screen first.
- Leaving a title played from a poster puts the highlight back on that
  poster with its preview, as leaving its page already does.
- Swiping down from Movies or Series in the tab bar lands on Play.
- A `large` UI testing library with posters from a fixture server on the
  Mac, a redraw and frame-gap probe, and UI tests for the redraws and both
  focus faults.

Out of scope:
- iPhone, iPad and Mac show no preview. There the rows also skip the
  redraws of the screen around them, as when the iPhone banner scrolls
  under the top bar; nothing else changes.
- Frame rates on a device. The simulator counts frames the main thread
  missed; the owner checks the device (design.md, "What to check on the
  device").

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `movies-and-series-browsing`: "Browsing stays responsive" adds the
  scenario "Moving through the rows on Apple TV".
- `title-detail-and-episode-picker`: "Back to where you were" adds the
  scenario "Back from a title played from a poster on Apple TV".
- `tvos-shell`: "Back from a tab goes to the tab bar" adds the scenario
  "Swipe down after moving along the bar".

## Impact

- Apps: `ShelfTVScreen`, a new `ShelfTVFocusFollower`, `ShelfContent`
  (`ShelfActions`, `ShelfRowsContent`), `ShelfLibrary`, `TitleRoute`,
  `ShelfSync`, the Debug-only `UITestingShelf` and `UITestingShelfLarge`,
  unit tests in `AntennaTests` and UI tests in `AntennaTVUITests`.
- No new container, dependency or stored data, so the C4 diagrams stay as
  they are.
