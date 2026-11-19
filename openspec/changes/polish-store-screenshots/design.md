# Design

## Context

Boards: `iPhone` (Live: picture, now-playing line, group chips, channel
list), `iPhone-Guide` (group chips, day chips, rows), `iPad` ("Player +
now/next" panel, list header), `iPad-Guide` (toolbar, time labels, grid).
None of them changes. Each draws the chips right under the line above them,
the grid's first row right under the time labels, and the panel's title and
times whole. The fixes bring the app back to the boards. Design-system
requirements followed: the type scale and the empty-and-error-states
layout, both unchanged. Not drawn: the panel and the list header in a
narrow iPad column with long text, which design decision 2 settles.

What the clean store run 44586119949 showed, and what causes it:

- iPhone Live and Guide: `Browse.Chips` is a horizontal `ScrollView`, which
  takes every point of height it is offered. Under a picture that is empty
  when nothing plays, or above the guide rows, the chip row and the list
  split the leftover height, so the chips float in the middle of a band. It
  is a layout bug, not a preview area.
- iPad guide: a two-axis `ScrollView` centers content shorter than itself,
  so five rows sit a third of the way down the grid.
- iPad Live panel: the programme title and its times share one line, so in
  a third of the screen both get cut. Up next's time column is a fixed
  52 points, which "6:00 PM" and "7:30 p. m." overflow onto a second line.
  The list header gives the count its width first and cuts the group name.

## Goals / Non-Goals

Goals:
- Fix the three layouts for every user on iPhone, iPad and Mac.
- A store set with art on Movies, a clock that agrees with the status bar,
  and Mac pictures in every store language.

Non-goals:
- Captions or device frames. Uploading. The Apple TV shell.

## Decisions

### 1. Chips and grid take their own height

`Browse.Chips` gets `.fixedSize(horizontal: false, vertical: true)`, so the
row is as tall as its chips on Live, Guide and Search. The grid's content
gets a minimum height of the visible area, aligned top leading, so a short
group starts under the time labels. The grid already had
`.defaultScrollAnchor(.topLeading)`, which did not keep short content at
the top.

### 2. The panel and the list header fall back to two lines

`ViewThatFits` picks between one line and two: the title with its times
beside it, else the title on up to two lines with the times under it; the
group name with the count beside it, else the count under the name, which
may shrink to 75%. The Up next time column takes the width of the widest
of the three times on one line (a hidden stack of all three), with 52
points as the floor, so the titles still line up. Options considered:
shrinking text to fit (unreadable at the narrow width), fixed wider
columns (wrong in the next locale), and a `Grid` (loses the combined
VoiceOver row).

### 3. The store clock: a time zone, not an injected clock

The app reads the time from 25 `TimelineView`s and from `Date.now` in its
models. Previews pass fixed dates to components, but screens have no clock
seam. Options:

- Inject a clock through the environment into every screen: a production
  seam touching 25 call sites and the models, for a Debug-only need.
- Shift the guide fixtures instead: the guide would still show the real
  time beside a 9:41 status bar.
- Run the store-shot app in a fixed time zone whose offset puts the launch
  moment at 9:41 (chosen). `UITestingStoreShots.pinClock()` sets `TZ` to
  `GMT±hhmm` and calls `NSTimeZone.resetSystemTimeZone()` before anything
  formats a date, so every formatter, calendar and `TimelineView` reads
  9:41. Dates stay real, so timers, progress and the scripted engines are
  unaffected. `NSTimeZone.default` alone was not enough, since
  `Date.FormatStyle` uses the autoupdating zone.

The store guide now aligns programmes to the half hour on that wall clock,
since the offset need not be a whole hour. 9:41 in the morning, so the
24-hour languages read 09:41 too, matching the status bar's "9:41"; the
store clip is a sunrise.

### 4. Art drawn by a script, Debug only

`scripts/make-store-art.py` draws a 400 by 600 poster and a 1280 by 720
backdrop for each of the 13 scripted titles from formulas (harbor, rings,
dunes, city, bands, peaks, aurora), standard library only, and encodes
them as JPEG with ffmpeg: about 480 KB in all. No text, people, logos or
brands. The files are `Apps/Shared/Debug/StoreArt-<source>-<kind>-<n>-<poster|backdrop>.jpg`,
excluded from Release by `EXCLUDED_SOURCE_FILE_NAMES` next to
`StorePicture.mp4`. With `-ui-testing-store-shots`, `UITestingShelf` gives
each title a `file://` poster address and each info and banner answer a
backdrop address; the poster cache reads file addresses as it reads web
ones. Without the argument nothing changes, so the shelf UI tests keep
their name tiles.

### 5. Mac pictures from a Mac walk

A new `AntennaMacJourneys` UI test target (macOS only, in a new
`AntennaMac` scheme so the iOS scheme does not change) holds
`MacJourneys.testStore`: the iPhone and iPad steps, clicking sidebar rows.
`Journey` takes the window's screenshot on a Mac instead of the screen's.
On a store-shot launch the Mac window is set to 1440 by 900 points and
centered, which gives 2880 by 1800 on a Retina screen and 1440 by 900 on a
1x one; App Store Connect takes both. CI builds it ad hoc signed
(`CODE_SIGN_IDENTITY=-`, personal entitlements: sandbox and network, no
iCloud) and runs it for every store language, English included, filing
the pictures as `<locale>/mac/<nn>-<step>.png`.

Locally the Mac walk waits on the system's permission prompt for UI
automation, so it was checked in CI only.

## Risks / Trade-offs

- A `TZ` with a minute offset is unusual. Nothing in the app keys off the
  zone's name, and Xtream catch-up uses the server's own zone.
- The Mac runner's screen size decides the pixel size; a screen under
  900 points tall would shrink the window. The run shows which.
