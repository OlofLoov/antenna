# Design

## Context

On a real iPhone with a large provider the owner saw hangs while flicking
through Movies and Series. The device log held "onChange(of: Rotation)
action tried to update multiple times per frame" and "Snapshot request ...
response-not-possible".

`Rotation` is the id of the `.task(id:)` in `ShelfBannerHost` that pages
the banner every eight seconds. Its `inputs` field went up on every call to
the banner's `interacting` closure. On iPhone and iPad that closure was
called from the banner's `DragGesture.onChanged`, which fires on every touch
move. The banner is the top 520 pt of the iPhone screen, so most upward
flicks start on it. Each move bumped `inputs`, restarted the task, redrew
`ShelfBannerHost` and handed a new `BannerContext` to every banner part,
which built a new gesture. That is the "multiple times per frame" line. The
same gesture only reported the end in `onEnded`, which does not run when
the scroll view takes the drag, so the banner could also stay held.

Posters load through `PosterCache.poster(for:fitting:)`. A card's `.task`
is cancelled when it leaves the screen, but the cache awaited an
unstructured task that ignored that, so the card kept waiting and the
download and decode ran to the end. A fast flick through a 20 000 title
library started hundreds of downloads a second; the session runs a few per
host at once, so the posters on screen waited behind the ones scrolled past.

`ShelfSync` built a new `PosterLoader` and `LogoLoader` closure in `body`.
Neither is `Equatable`, so every redraw of the window root changed the
environment for every poster and logo under it.

No board changes. Design-system requirements followed: none change; the
banner keeps `movies-and-series-browsing/new-titles-up-front`.

## Decisions

### The banner's touch state

Options:
1. Keep `interacting` and `inputs` as two `@State` values and guard each
   write in the closure.
2. A small value type in AntennaCore, `BannerTouch`, that only counts inputs
   for `BannerPager.Hold.restartsOnInput` (Apple TV) and that the host writes
   only when it changes.

Chosen: 2. The rule "a touch platform's moves never restart the timer"
becomes a core test, and the host's write guard is one line. Apple TV keeps
restarting the wait on each focus move, which is a discrete event.

The iPhone and iPad swipe now sets a `@GestureState` while the finger is
down and reports `interacting` from `onChange` of that state. SwiftUI resets
a gesture state when the gesture ends or is cancelled, so the banner hears
once on touch down and once on lift, including when the scroll view takes
over.

### Cancelling poster loads

Options:
1. Let each card run its own download with no sharing.
2. Keep one shared load per address and frame, count the callers waiting
   for it, return `nil` at once to a cancelled caller, and cancel the load
   when the last caller leaves.

Chosen: 2. Rows and grids often show one poster twice (Recently added and
its genre row), and sharing one download stays. Each caller waits on its
own continuation, so a cancelled card returns without waiting for the
shared load. Cancelling the load cancels its `URLSession` data task.

### Loaders made once

`ShelfSync` keeps the poster and logo loaders in static constants. They
capture only the shared caches, so one instance serves the app's life.

## Measurements

An iPhone 17 Pro simulator (iOS 27.2) ran a Debug build compiled with `-O`
on a local fixture: 20 000 movies and 20 000 series in 150 genres with a
164 KB 1000 by 1500 poster each from a local HTTP server that answers in
50 to 300 ms, and 50 000 channels with logos. A UI test flicked through the
Movies rows, sideways through three rows, switched to Series and back,
opened a genre's grid and flicked through it, then Live's list and Series
again. A watchdog thread pinged the main queue every 16 ms and recorded
each reply slower than 100 ms. Neither the fixture nor the watchdog is
committed.

| | Before | After |
|---|---|---|
| Main-queue replies over 250 ms | 87 | 24 |
| Their total | 85.5 s | 21.5 s |
| Longest | 11.9 s | 5.9 s |
| Past the first 25 slow replies (launch): over 250 ms | 70, 40.9 s | 17, 9.2 s |
| Past the first 25: longest | 3.6 s | 1.5 s |
| Test run | 547 s | 410 s |

Both runs include launch, where 50 000 channels load and the longest
replies fall, and XCUITest's accessibility snapshots, which run on the main
thread. The Mac ran other builds at the same time, so the numbers move by a
wide margin between runs; the direction held. `sample` on the main thread
during the flicks showed no single app function above 1% of samples in
either run, so the gain is the redraws and task restarts that no longer
happen, not one slow call.

Xcode's Time Profiler could not attach to the simulator app on this Mac
("Cannot find process for provided pid"), so the stacks come from `sample`.

The simulator also logged thousands of `CVPixelBufferCreate returned err
-6680` lines from ImageIO's thumbnail path. It falls back to a software
decode and the poster shows; this did not reproduce as a stall and is left
as it is.

The SwiftUI line the owner saw did not appear in the simulator log, since
XCUITest's synthesized drags rarely start on the banner. The core test
pins the rule instead: 240 reports of one touch change the timer's state
once.
