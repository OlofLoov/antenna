# Design

## Context

See proposal.md for why. What exists on 2026-11-23:

- `ShelfTVScreen` reads the focused row and the focused title with
  `@FocusedValue`. Each move of the highlight changes one of them, so the
  screen's body runs again on every move.
- The screen makes its `ShelfActions` in its body. Their closures never
  compare equal, so every redraw of the screen also redraws
  `ShelfRowsContent`, which works out Continue watching, My list and
  Recently watched and lays out every row on screen, and `ShelfBannerHost`,
  which hands the banner a new context.
- A mask over the rows' scroll view hides rows that pass under the preview.
  A mask makes the rows render off screen before they are drawn, every
  frame they move.
- A title played from a poster opens the player over the shell. While it
  plays nothing in the rows has the highlight, so 350 ms later the screen
  scrolls the rows back to the top. When the player closes, the poster has
  scrolled out of the lazy rows and the shell puts the highlight on the
  first thing on the page, the banner's Play button.
- Swiping down from Movies in the tab bar lands on whatever is nearest
  below the tab. `defaultFocus` on the rows' scroll view picks Play when
  the shell sets focus from code, but not when the highlight moves in by a
  swipe, so after Series and back it landed on a poster in Recently added or
  on My list.

## Boards

No board changes. `TV-Movies`, `TV-Movies-Rows` and `TV-Movies-Preview`
stay as drawn: the fade under the preview's foot looks the same, and the
highlight lands where the boards put it. Design-system requirements
followed: `design-system/apple-tv-content-stays-in-the-safe-area`.

## Measuring

- The `large` shelf script (`-ui-testing-shelf large`) has 9 000 movies in
  80 categories and 3 500 series in 40, from two sources, with a few large
  categories and a long tail. Office answers 5 seconds after Cabin, so its
  titles join the rows while the viewer is in them. With
  `-ui-testing-poster-host http://127.0.0.1:<port>` every poster (600 by
  900) and backdrop (1920 by 1080) loads over HTTP from a fixture server on
  the Mac, a different address per title, so every one is fetched and
  decoded. No provider is asked.
- Instruments' Animation Hitches and the SwiftUI template do not record on
  the tvOS simulator ("Hitches is not supported on this platform"), and
  `XCTHitchMetric` records nothing there. A Debug-only display link counts
  instead: a tick that comes more than 1.5 frames after the one before
  counts the frames in between as dropped, and the gap past one frame as
  hitch time. It sees frames the main thread missed, not frames the render
  server dropped.
- Debug-only counters record how often the screen, the rows, the posters
  and the banner run their body. `shelf.debug.*` elements show both sets of
  counts to the UI tests.
- `ShelfLargeTVUITests` runs the walks behind
  `TEST_RUNNER_ANTENNA_BENCHMARKS=1`, three runs each, on an Apple TV 4K
  (3rd generation) simulator with tvOS 27.2 on an Apple silicon Mac.

## Decisions

### 1. Who reads the focused row and title

Options:
- **Keep the reads in the screen and make everything below it skip
  redraws.** Every move still runs the screen's body, its overlays and the
  preview's context.
- **Read them in a small view that does the work they drive.** Chosen.
  `ShelfTVFocusFollower` sits behind the rows, reads both focused values,
  places the focused row and rests the preview. It writes two values to
  the screen: whether the highlight is in the rows, which changes as it
  enters or leaves them, and the preview's title, which changes once a
  poster has rested for 0.8 seconds. The preview's schedule, the row last
  placed and the restoring flag live in `ShelfPreviewFollow`, an object
  nothing observes, so they outlive the follower when a genre grid
  replaces the rows.

### 2. Rows and banner that skip a redraw of the screen

`ShelfActions` carries the section's kind and the identities of the
library, activity and playback it was made from, and two actions compare
by those. `ShelfRowsContent` is equatable on its model and actions and
leaves out `seeAll`, which every screen makes again to set the same state.
SwiftUI uses that conformance when it compares the view.

Wrapping the rows in `.equatable()` was tried first and ruled out. In the
`LazyVStack` it turned all 80 rows into one child that built at once: 729
poster bodies on opening Movies instead of 27. The conformance alone keeps
the rows lazy.

On Apple TV the banner goes in `ShelfTVBanner`, equatable on its model,
actions, whether the preview pauses it and the object it reports its title
to. It leaves out the shell's focus binding, which is the same each time.

### 3. Hiding rows under the preview

The mask drew nothing over the top 496 pt while the preview showed, then a
40 pt fade. The rows sit on the ground color, so a layer of the ground
color over those 496 pt with a 40 pt fade from the ground color to clear
shows the same pixels, fades in and out with the preview as the mask did,
and lets the rows draw straight to the screen.

### 4. Back from playing

`ShelfLibrary.returning`, which the poster or banner button that opened a
page watches to take focus back, becomes a `ShelfSpot` (title and origin)
so playback can use it too. A play from a poster or a Continue watching
card records its spot; `ShelfSync` hands it to `returning` when playback
ends, and the poster's `ReturnFocus` takes the highlight as it does after a
page. While the player is open the follower no longer scrolls the rows to
the top, so the poster is still there. The banner's Play records nothing:
the banner keeps the highlight there already.

### 5. Down from the tab bar

The banner's buttons watch the shell's `shellBarFocused`. When the
highlight leaves the bar for the open tab and lands on anything but Play,
they put it on Play through their own focus state. The shell's `.content`
focus value is bound in Movies, Series and the Guide at once, and setting
it on this path left the highlight in the bar, so the banner uses its local
value. A banner scrolled away or in a tab not on screen does nothing.

## Results

Frames the main thread missed per run, three runs each, on 2026-11-23
before and after decisions 1 to 3. A run along the posters is 10 presses
right and 10 left; a run down the rows is 6 presses down and 6 up, 0.4
seconds apart.

| Walk | Before: dropped (hitch ms) | After: dropped (hitch ms) |
|------|----------------------------|---------------------------|
| Along the posters | 48, 52, 85 (760, 1086, 1410) | 44, 38, 36 (732, 637, 607) |
| Down and up the rows | 68, 60, 82 (1089, 984, 1322) | 67, 75, 62 (1047, 1228, 999) |
| A series page and back | 33, 21, 21 (589, 336, 360) | 24, 25, 23 (439, 483, 370) |
| Movies to Series and back | 25, 15, 13 (378, 245, 218) | 18, 13, 17 (297, 214, 269) |
| Opening Movies | 12 (201) | 16 (257) |
| Standing still for 6 s | 4, 4, 6 (0, 63, 134) | 4, 6, 1 (125, 95, 33) |

Over 8 moves along a row, before: the screen ran its body 10 times, the
rows 11 and the banner 8. After: the screen at most 3 (the preview
changing title), the rows and the banner not at all.

Moving along the posters lost 39% less hitch time. The other walks did not
change beyond the noise. Taking out, one at a time, each poster's menu, its
focus return, every poster modifier, the poster pictures and the row
placement left the numbers where they were, so what the simulator still
counts is not in those parts. XCUITest takes an accessibility snapshot of
the app for each press, and those snapshots showed up on the main thread in
Time Profiler; that cost does not exist on a device without VoiceOver.

## What to check on the device

The simulator draws on the Mac's GPU and runs XCUITest's accessibility
queries in the app, which cost frames a device does not lose. On an Apple
TV 4K with a large provider:

- Move quickly along Recently added and along a long category: the
  highlight keeps up and the preview changes once you stop.
- Move down and up through ten rows: each row slides in one movement with
  no stall when it arrives under the preview.
- Play a movie from the third row, press Menu: the same poster has the
  highlight and its preview shows.
- From Movies, press Menu, move to Series and back, swipe down: Play has
  the highlight.
- In Xcode's Instruments on the device, the Animation Hitches template
  works there; a hitch ratio under 5 ms/s while browsing is the target.
