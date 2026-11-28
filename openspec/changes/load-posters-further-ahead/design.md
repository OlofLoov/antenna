# Design

## Context

See proposal.md for why. What loads ahead on 2026-11-28, from
`expand-focused-title-on-apple-tv` (decisions 4 to 6) and commit
`25585a34`:

- Along a row, each poster that shows asks for the next 3 in the direction
  the row scrolls (`PosterPrefetch.along`), except in the half second after
  the row came into view.
- Each row that shows asks for the first posters of the 1 row past it in
  the direction of the scroll (`PosterPrefetch.rowsAhead`), as many as fit
  the window's width: 8 on Apple TV.
- On Apple TV, each new highlight position stops what the last one asked
  for (`stopPrefetching("focus.<prefix>")`) and asks for the 8 posters
  around its column in the row above and the row below.
- `PosterCache.prefetch` starts a download and decode for every poster
  asked for at once, at utility priority, through `URLSession.shared`,
  which opens 4 connections to a host.
- 50 MB of decoded posters in memory, about 44 posters of 448 by 640
  pixels on a 4K Apple TV, let go of shown longest ago first.

The titles themselves are not loaded per move: every title of every
source is in memory once the section opens, so a row's names and its
placeholder shapes draw at once. What shows late is the poster in each
shape, and the card's details after the 0.8 s rest.

No boards change. Posters that are late look as `TV-Movies-Expanded-Loading`
draws them; this change makes that state rarer.

## Measuring

`ShelfLargeTVUITests` with `TEST_RUNNER_ANTENNA_BENCHMARKS=1`, the `large`
shelf script (9 000 movies in 80 rows), on a cloned Apple TV 4K (3rd
generation) simulator, tvOS 27.2. The fixture server answers every poster
and backdrop path with one 600 by 900 or 1920 by 1080 JPEG after 500 ms,
five times the wait of the earlier tables, standing in for a provider's
poster host. It is a 40-line Python script, not in the repository. The app
was deleted before each test, so each starts with no posters on disk.

The walks are the ones in `expand-focused-title-on-apple-tv` ("Measuring"),
plus a new one, `testHitchesMovingDeepDownTheRows`: 12 rows down at 0.4 s,
then 10 posters right at 0.25 s, once. The six-row walk comes back to rows
it already loaded; the deep walk reaches rows nothing has loaded, as a
first browse of a big catalogue does.

Three builds, each run twice, alternating, on a quiet Mac. Before is
main at `e25a19c7`. "4 ahead" is the window of decision 1, the line of
decision 2 at 4 through `URLSession.shared`, decision 3 and 80 MB. "5 of
6" is the same with the posters' own session, 6 connections a host and 5
ahead, as chosen. Not ready is `posterMisses` over `posterAsks`; dropped
frames are over the frames counted, as before.

| Walk | Build | Dropped frames (hitch ms) over frames counted | Posters not ready |
|------|-------|-----------------------------------------------|-------------------|
| Deep down the rows, once | before | 67 (1207) / 859; 66 (1266) / 888 | 80 of 145; 79 of 145 |
| | 4 ahead | 69 (1220) / 859; 66 (1221) / 889 | 68 of 145; 68 of 145 |
| | 5 of 6 | 83 (1354) / 847; 58 (1012) / 897 | 61 of 145; 56 of 145 |
| Down and up the rows, first walk | before | 37 (704) / 621; 34 (706) / 622 | 28 of 112; 28 of 112 |
| | 4 ahead | 35 (703) / 621; 36 (687) / 622 | 18 of 112; 26 of 112 |
| | 5 of 6 | 38 (681) / 620; 30 (497) / 629 | 11 of 112; 12 of 112 |
| Down and up, later walks | all three | 25 to 37 / about 620 | 0 of 112 |
| Along the posters | before | 37 to 43 / 401 to 436 | 0 to 2 of 47 |
| | 4 ahead | 37 to 42 / 403 to 442 | 0 of 47 |
| | 5 of 6 | 34 to 52 / 412 to 440 | 0 of 47 |

What this shows:
- On the first walk down and up, 1 card in 4 showed the placeholder
  before and 1 in 10 after. Later walks find every poster on disk in all
  three builds.
- The deep walk goes from 55% not ready to 40%. It moves a row every 0.4
  s, and each row brings about 8 posters the screen shows plus the window
  ahead, close to 20 a second. 6 connections to a host that answers in
  half a second bring in about 12 a second, so on a host this slow a walk
  this fast outruns any window; the line keeps what arrives to the rows
  nearest the highlight. With 4 through the shared session it was 8 a
  second, which is why "4 ahead" gained little.
- Along a row nothing was late in any build, as at 100 ms.
- Frames: the runs overlap between builds on every walk, between 5% and
  10% of frames dropped, about 55 frames a second on the simulator and
  well above the 40 the earlier changes hold to. The deep walk's spread
  (58 to 83 dropped) is within one build.
- Not measured: a real Apple TV and a real provider's host. Many hosts
  answer posters faster than 500 ms; some answer over HTTP/2, where the
  6 connections are one and the line's 5 is the only bound.

## Decisions

### 1. How far ahead

Options:
- **Keep the window, load more at once.** Decision 2 does that, and the
  measurements show it is not enough on its own: the rows 2 past the
  highlight still start loading only when it gets there.
- **Load whole rows, or the whole section, ahead.** A row of 300 posters
  is 340 MB decoded. Rejected in `expand-focused-title-on-apple-tv` for the
  section; a row is no different.
- **A wider window in the direction of travel.** Chosen.

What that means:
- Along a row, 6 posters ahead instead of 3. On Apple TV a poster at the
  trailing edge shows when the highlight is about 5 posters short of it,
  so the lead goes from 8 posters to 11. Holding right moves the highlight
  about 4 posters a second, so that is close to 3 s of lead, against a
  host that answers in half a second plus a decode.
- When a row shows, the first posters of the 2 rows past it in the
  direction of the scroll, instead of 1. On Apple TV the row that comes
  into view at the foot of the screen is 2 below the highlight's row, so
  the rows loaded are 3 and 4 below it.
- On Apple TV, the posters around the highlight's column in 2 rows ahead
  of its last move between rows and 1 behind, nearest first: on the way
  down the row under, the row above, then the second row under
  (`PosterPrefetch.aroundHighlight`). It was 1 row each side. The
  direction comes from `PosterPrefetch.Trail.highlight`, which remembers
  the row the highlight was in, so a move along a row keeps the last
  direction and nothing new is observed. Ahead before behind, since the
  row behind was on screen a move ago and its posters are mostly still in
  memory.
- 3 rows ahead around the column was tried in reasoning only: a row 3
  past the highlight is never on screen before two more presses, and its
  8 posters would cost 9 MB more for every position.

iPhone, iPad and Mac get the along and next-rows changes. They have no
highlight that moves between rows, so no rows around a column.

### 2. A line for posters loaded ahead

Every poster asked for ahead used to start downloading at once. One move
down asked for up to 24 posters around the column and 8 more for the row
coming into view. `URLSession` opens a few connections to a host and
queues the rest in the order asked, so a card on screen that asked after
them waited for all of them.

Options:
- **Start every load, as before.** A card waits behind the queue. On a
  slow host that is seconds.
- **Lower `URLSessionTask.priority` for loads ahead.** The async
  `data(from:)` takes no priority, and how the system orders requests
  queued for one host by priority is not documented. Not tried.
- **A line in `PosterCache`.** Chosen. At most 5 posters asked for ahead
  load at once (`PosterCache.prefetchLimit`); the rest wait in line
  (`PosterLine`), and a new ask goes in front of older ones, since it is
  nearer where the viewer is now. A card that asks for a poster in line
  starts it at once, outside the 5. A poster that leaves the line, because
  its row scrolled away or the highlight moved on, is never downloaded.

How many at once:
- **4 through `URLSession.shared`.** The shared session opens 4
  connections to a host on iOS and tvOS. Measured as "4 ahead": the line
  kept cards from waiting, but 4 answers at a time against a slow host
  are too few for the window of decision 1.
- **The posters' own session with 6 connections a host, 5 ahead.**
  Chosen. 6 is what browsers open to one host, so a poster host sees no
  more than a web page would give it. The line stays one under it, so a
  card always finds a connection free. The session keeps no `URLCache`,
  since `PosterCache` keeps the files.
- **More, such as 8 or 10.** More per host than a browser opens; some
  providers serve posters from the same server as their streams and
  count connections. Not tried.

The line also bounds the decodes ahead to 5 at a time, so loading ahead
does not take every core while the screen animates.

### 3. A new highlight position replaces the last

Each move stopped what the last position asked for, then asked again.
The two positions share most of their posters: along a row, the 8
posters around the column move by one. So each move dropped downloads
half done and started them again.

Chosen: `PosterCache.prefetch(_:fitting:group:replacing:)`. With
`replacing`, the group wants the new posters alone; of what it wanted
before, only what no card waits for and no other group wants stops, and
what both positions want keeps loading. A fast walk along a row
reorders the line and restarts no download. Rows keep
adding to their own groups as before, and stop all of it when they
scroll away.

### 4. Memory

Options:
- **Keep 50 MB.** The window in decision 1 is about 30 posters past the
  two and a half rows on screen. Next to those 20 and an 8 MB banner
  backdrop that is 65 MB, so posters asked for ahead would be let go
  before they show, as at 50 MB in `expand-focused-title-on-apple-tv`.
- **400 MB, as tried before.** Turned down by the owner on 2026-11-25 as
  wasteful.
- **80 MB on every platform.** Chosen. It holds about 70 posters of 1.1 MB
  on a 4K Apple TV: the 50 the screen and the window need, the banner
  backdrop and about 10 posters of the rows just passed. iPhone posters
  decode smaller, so the same limit holds more of them.

The limit is a hard bound. `PosterMemory` lets go of the poster
shown longest ago before it takes one past the limit, and empties on a
memory warning, as before. 80 MB is under 4% of the 2.1 GB the app was
killed at on Apple TV earlier, for other reasons.

### 5. Frames

Nothing here runs per frame. Each move between posters on Apple TV
computes 3 ranges instead of 2 on the main actor (tens of microseconds,
measured in `expand-focused-title-on-apple-tv`) and sends one call to the
cache's actor. The loads and decodes run off the main actor at utility
priority, at most 5 at a time. The frame counts in the table above check
it.

### Not done

- Loading each title's details ahead of the 0.8 s rest. One provider call
  per title, and providers limit calls; the rest stays.
- Smaller decodes while moving fast. Rejected in
  `expand-focused-title-on-apple-tv` (posters look soft on a 4K TV).
