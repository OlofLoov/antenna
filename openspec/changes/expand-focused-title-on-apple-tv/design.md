# Design

## Context

See proposal.md for why. What exists on 2026-11-25:

- `ShelfTVScreen` lays a 520 pt preview (`ShelfPreview.Television`) over
  the top of Movies and Series while the highlight is in a row, with a
  layer of the ground color behind it to hide the rows above the focused
  one. The focused row is scrolled to 536 pt, so one row and the header of
  the next fit under the preview.
- `ShelfTVFocusFollower` reads the focused row and title. It places the
  focused row under the preview and, once a title has had the highlight for
  0.8 seconds (`PreviewSchedule`), writes it to the screen's
  `previewTitle` and asks the provider about it (`ShelfModel.preview`).
- A move down waits 350 ms (`ShelfRowPlacement.settle`) for the focus
  engine's own scroll, then slides the row up into place over 0.3 s.
- Each poster starts loading when its card is laid out (`PosterLoading`).
  `PosterCache` decodes it at the card's size off the main actor and keeps
  it in memory (50 MB) and on disk (500 MB). Nothing loads ahead.

## Boards

New: `TV-Movies-Expanded`, `TV-Movies-Expanded-Loading` and
`TV-Movies-Expanded-Poster-Only`. They replace `TV-Movies-Preview`,
`TV-Movies-Preview-Loading` and `TV-Movies-Preview-Poster-Only`, which are
deleted. `TV-Movies-Expanded-Loading` also draws posters still loading:
the quiet Surface 0.06 shape at the end of Drama and across Comedy, with a
note on the fade. `TV-Movies`, `TV-Movies-Rows` and the iPhone, iPad and
Mac boards do not change; their posters take the same shape while they
load, at their own poster sizes. The design-system reference gains a
Poster placeholder token. Series uses the same boards with `series.`
identifiers.

Design-system requirements followed:
`design-system/apple-tv-content-stays-in-the-safe-area` (the rows and the
card's copy start at x 80), `design-system/controls-use-system-styles` (the
card is the poster's own button, with the system card focus),
`design-system/one-accent-color-per-profile` (the eyebrow is muted),
`design-system/visual-changes-update-the-boards-in-the-same-change` (the
placeholder). The fade follows the Reduce Motion rule the card already
follows: no animation, the poster appears at once.

Not drawn: the card in a row of a right-to-left language. It mirrors as
the rows do, with the posters after it moving to the left.

## Decisions

### 1. Where the focused title shows

Options:
- **Keep the top preview and make it smaller.** Still a second place to
  look, and still one row fewer on screen.
- **A detail strip under the focused row.** Netflix's older Apple TV
  layout. The row under it moves down by the strip's height on every
  move between rows.
- **Grow the focused poster into a card in its row.** Chosen, as Netflix's
  current Apple TV app does. The card is 566 by 318 pt, the height of a
  poster, so a row never changes height and nothing above or below it
  moves; only the posters after it in the same row slide 354 pt aside.

The poster's face (`ShelfExpandedCard.Expanding` in `ShelfView.PosterCard`)
reads `isFocused`. The card shows the moment the button takes focus, in
its own `withAnimation(.easeOut(0.25))` transaction, and the posters after
it slide aside in the same movement; with Reduce Motion they change
without animation. Decision 7 says how the card is drawn without the row
laying out again. Only the
screen's rows set `shelfExpandedCard`; the genre grids, Search and the
other platforms leave it out, so their posters never grow. Continue
watching cards are already landscape and do not grow.

### 2. When the provider is asked

The 0.8 s rest stays, through the same `PreviewSchedule` in
`ShelfTVFocusFollower`. The card shows what the row knows (category, name,
poster) at once and fills in from the details when they arrive. A card
reads its own title's details through `ShelfModel.cardDetails`, a
`KeyedValues`, so an answer redraws only that card. The follower no longer
writes a title to the screen, so after the highlight enters the rows a
move between posters redraws no part of the screen but the two cards.

Back from a page or the player, `follow.restoring` asks at once as before;
the card already shows the kept details since the model has them.

### 3. Where the focused row rests

The focused row's header rests 36 pt under the tab bar
(`ShelfRowPlacement.rowTop`, 156 pt), so two and a half rows show. The
placement code stays, with one change found while measuring: a row that
is already wholly on screen when it takes the highlight is placed at once
instead of after the 350 ms wait. The focus engine does not scroll a row
it can already see, so there is nothing to wait for. Only a row cut by the
foot of the screen waits. `misplaced` now checks the row is within 8 pt of
`rowTop` either way.

### 4. Posters ahead of the highlight

Options:
- **Fetch more of the title lists at launch.** They already load whole,
  every title of every source, when the section opens. Nothing in a focus
  move waits for a list.
- **Load every poster of the section up front.** 9 000 posters at 600 by
  900 is hundreds of megabytes of downloads and more than the 500 MB disk
  limit.
- **Load a window ahead.** Chosen. `PosterPrefetch` in AntennaCore says
  which: when a poster in a row shows, the next 3 in the direction the row
  is scrolling, told by the poster that row showed last
  (`PosterPrefetch.Trail`); when a row shows, the posters the row under it
  shows first, or on the way up the row above it, as many as fit the
  window's width (8 on Apple TV, 4 on iPhone). A row that just came into
  view loads nothing along it for 0.5 s, since its first posters show all
  at once. On Apple TV, while the highlight rests, the rows above and
  below it load the 8 posters around the poster to the right of its
  column, which they show once it moves into them (see "Why each walk
  finds more posters not ready"). Decision 5 says why the window is this
  small.
  `PosterCache.prefetch` loads and decodes them at the card's frame, the
  same key the card asks for, so the card finds them in memory. A card that
  asks while one loads joins it. Each row is a group: when a row scrolls
  away, the loads it asked for that no card waits for and no other row
  wants stop (`PosterCache.stopPrefetching`), so a fast scroll does not
  leave a queue. A card that stops waiting leaves a load running while a
  row still wants it. Prefetches run at utility priority.

The triggers are the `task` of a poster and of a row, which every
platform has, so iPhone, iPad and Mac load ahead of their scroll too. They
read the rows from the library in the task, not in a body, so a change to
the rows redraws nothing.

### 5. Poster memory

The first pass of this change raised the poster memory on Apple TV from
50 MB to 400 MB. A poster decoded for its card with room for the focus
lift (1.25 times the card) took 576 by 832 pixels on a 4K Apple TV, about
2 MB, so 50 MB held about 25 posters. With the next 8 posters of each row
and the first 8 of the 2 rows under it loaded ahead, posters were let go
before their cards showed. On 2026-11-25 the owner turned 400 MB down as
wasteful. Posters do not need to be that big; they can load as they come,
with an animation on the poster, and a cache where it helps.

Options:
- **Raise the limit on Apple TV.** 400 MB found 1 poster in 170 not ready
  on the walk down and up. It keeps eight times the memory, most of it for
  posters the viewer has passed. Rejected.
- **Keep 50 MB and decode posters smaller than the card.** Saves memory,
  but every poster on screen looks soft on a 4K TV, not only during a
  move. Rejected.
- **Keep 50 MB, decode at the card's resting size, load a small window
  ahead, and fade a late poster in.** Chosen.

What that means:
- 50 MB on every platform, Apple TV included (`PosterCache.memoryLimit`).
  The disk keeps 500 MB, so a poster that left memory decodes again from
  the file instead of downloading.
- A poster decodes at the card's size on screen, points times the screen
  scale, rounded up to 64 pixels: 448 by 640 on a 4K Apple TV, about
  1.1 MB, so 50 MB holds about 44. `PosterFit` has no focus headroom any
  more. The card's focus lift scales the picture up a little; that is
  accepted. Banner and title page backdrops decode at the window's size as
  before.
- The expanded card needs no larger decode. It shows the poster whole at
  70% of the card's height over a blurred copy, smaller than the poster in
  the row, so it uses the decode the row already holds. The backdrop that
  fades in after the 0.8 s rest decodes at the card's width, 566 by 318 pt,
  and only for the card that rested.
- A card whose poster is not in memory shows a quiet shape in Surface 0.06
  at the poster's size, with no name, and the poster fades in over 0.2 s
  when it lands (`PosterLoading.fadeIn`). A poster already in memory draws
  without the fade: the card looks it up in `PosterCache.kept` as it is
  laid out, without waiting for the actor. `PosterLoadingTests` draws a
  card in a window once and checks both cases; it does not tell the
  lookup at layout from the one in the card's task, which also ran before
  that draw. Under Reduce Motion the poster appears at once. A
  title with no poster, or one that failed, still shows its name tile.
  Drawn on `TV-Movies-Expanded-Loading`; the reference has the token.
- A card that leaves the screen lets go of its picture, so the cache is the
  only place decoded posters stay, and 50 MB is the real limit.
- The window ahead is 3 posters in the direction of travel and the posters
  the next row in the direction of the scroll shows first (decision 4). On
  Apple TV that is two and a half rows on screen, about 20 posters, plus 3
  and 8 ahead: about 31 posters, 36 MB. The 8 MB of a 1920 by 1080 banner
  backdrop shares the same limit; keeping backdrops apart changed nothing
  on the walk down and up ("At 50 MB").
- The memory lets go of the poster shown longest ago first
  (`PosterCache.Memory`), and empties itself when the system runs low on
  memory, as `NSCache` did.
- The cancellation rules stay: each row is a group, and a row that scrolls
  away stops the loads it asked for that no card waits for and no other row
  wants.

### 6. The highlight keeps its column between rows

Measuring found that each move up or down landed the highlight a poster
to the right: the focus engine picks the poster under the middle of the
expanded card, which is 566 pt wide where a poster is 212. A walk six rows
down and back up from the first poster of Recently added ended on the
eighth. The owner called it a bug on 2026-11-25: the Apple TV app and
Netflix keep the column.

Options:
- **Leave the focus engine's choice.** The drift above. Rejected.
- **The poster at the same screen x as the resting poster the highlight
  left.** Needs each row's sideways scroll offset, read from every row's
  geometry; a geometry reader on every row cost about 40 dropped frames
  per walk down and up (decision 5, "At 50 MB"). Rejected.
- **The poster at the same position in the row.** Chosen. On the boards
  every row starts at x 80 and only scrolls sideways once the highlight
  walks along it, so for rows the highlight has not walked along this is
  the same screen x. A row shorter than the position lands on its last
  poster. Continue watching's cards are wider than posters, so a move into
  or out of it keeps the focus engine's choice.

How: each row is a focus section whose default focus, for a move into
it, is the poster at the highlight's column (`ShelfRowColumn`,
`.defaultFocus(priority: .userInitiated)`), so the focus engine lands
there in one move. `ShelfTVFocusFollower` writes the column to a small
observed `ShelfColumnState`; only the rows' focus modifiers read it, so a
move along a row redraws no poster. On the walk six rows down and up this
lands right on all but about 1 move in 12.

The rest it corrects. The follower remembers the row and position the
highlight is on. When it lands in another row on a different position
than the one it left, `ShelfColumn.target` names the position, and the
follower asks that poster to take focus through `ShelfModel.focusRequests`,
a `KeyedValues` keyed by row and title, so only that poster redraws. The
poster takes focus in an `onChange`, before the frame draws, so the poster
the focus engine picked does not grow first. The debug probe counts these
second moves (`corrections` in `shelf.debug.posterTrace`): 1 per walk,
where the correction alone made 12. Steering only with the default focus,
without the correction, ended one walk a poster to the right, and
`testDownAndUpTheRowsKeepsTheColumn` failed, so both stay. Deciding the
target in `onMoveCommand` before the engine moves was not tried. Each correction places the
row again, since the focus engine scrolls for it too; without that, a row
was left 39 pt above its place in `ShelfRowsUpTVUITests`.

A second press before the correction lands moves from the poster the
focus engine picked. Over a short row, such as a My list of two posters,
nothing sits under that poster, and the focus engine passes the row:
`ShelfRowsUpTVUITests` saw two quick presses up from Recently added land in
Continue watching. That was its flake, "myList does not hold the
highlight". `ShelfColumn.skipped` finds the row passed over and the
highlight lands in it, and a correction not yet taken is dropped when the
next press lands. The class then passed 6 runs in a row.

Finding the position in a row and the rows' order takes 16 to 40 µs per
move on the simulator, measured with the debug probe (770 to 1 900 µs over
48 moves on the walk down and up), so it costs no frames. The rows by the
highlight now load the posters around its column instead of the one to its
right.

### 7. The card outside the row's layout

The first build grew the poster's button to 566 pt inside the row's
`LazyHStack`. Each frame of the growing animation laid the stack out
again and walked its `ForEach`; Time Profiler put most of the extra main
thread time there ("Frames against main"). On 2026-11-26 the owner
approved taking the growth out of the row's layout.

Options:
- **Grow the button, as before.** About twice main's dropped frames on
  every walk. Rejected.
- **A card overlay with the posters after it staying put.** No layout and
  no moves, but the card covers the next posters, and the spec has them
  move aside. Rejected.
- **Fixed slots, the card drawn over the focused slot, the posters after
  it moved by an offset.** Chosen. An offset changes where a view draws,
  not its frame, so the stack never measures again.

How:
- Every poster keeps its 212 pt slot. Each Apple TV row of posters holds
  a `ShelfCardRoom` (set by `ShelfRowColumn`, which already knows the
  row's titles). Each poster and the See all tile register a
  `ShelfCardPlace` with it as they appear (`makesRoomForTheCard`). When a
  poster takes focus, `Expanding` tells the room inside its animation;
  the room sets `front` on that poster's place and `aside` on the places
  after it. Each place is observed alone, so a step along the row
  redraws only the poster that loses the highlight and the one that gains
  it; entering a row moves every poster after the column on screen.
- A place with `aside` is offset by 354 pt, the card's extra width. The
  row's trailing padding has the same 354 pt for good, so the last
  poster's card has room and the content size never changes.
- The card is an overlay on the place, outside the poster's button. The
  system card style clips its label to the label's frame, so a card inside
  the button showed only the poster's width of it. The place in front has
  `zIndex` 1, so the card draws over the posters that slide under it.
- Outside the button the card has no system lift, so it draws its own: a
  scale of 1.06 and a shadow. The system lifts a poster by an eighth; at
  an eighth the card's copy started at x 72, left of the safe area
  (`testMoviesKeepsTheSafeEdges`). The poster stays drawn under the
  opaque card, shrunk to 0.9 so the system's lift keeps it inside the
  card. Hiding it at no opacity took the button out of the accessibility
  tree, and the UI tests and VoiceOver lost the highlight.
- The highlight stays on the poster's button, so focus moves, the
  column-keeping of decision 6, the focus requests, the return from a page
  and VoiceOver's label and hint work as before. VoiceOver's frame is the
  poster's slot, not the card. The card is a container with the
  identifier `<prefix>.card.focused`, which the UI tests measure.

## Measuring

As in `keep-apple-tv-browsing-smooth`: the `large` shelf script, 9 000
movies in 80 categories and 3 500 series in 40, posters (600 by 900) and
backdrops (1920 by 1080) from a fixture server on the Mac that waits
100 ms before each answer, the frame-gap probe, `ShelfLargeTVUITests`
behind `TEST_RUNNER_ANTENNA_BENCHMARKS=1`, Apple TV 4K (3rd generation)
simulator, tvOS 27.2. New: `shelf.debug.posterMisses` counts the cards that
asked for a poster not yet in memory, so a run shows how often the
highlight reached a name tile.

The Mac ran several other agents' builds and simulators during these runs,
so the standing-still floor is higher than on 2026-11-23 and the numbers
compare only within this table.

Before, on main at `d12910bb`, three runs each. Along the posters is 10
presses right and 10 left with no wait; down the rows is 6 presses down and
6 up, 0.4 s apart; standing still is 6 s with no press.

| Walk | Dropped frames (hitch ms) over frames counted |
|------|-----------------------------------------------|
| Along the posters | 178 (2945) / 304, 145 (2417) / 334, 143 (2312) / 378 |
| Down and up the rows | 257 (4205) / 401, 306 (5029) / 377, 284 (4632) / 411 |
| Standing still | 19 (506) / 550, 83 (1373) / 461, 27 (402) / 608 |

### After, 2026-11-25

Measured on a quiet Mac (load average under 5), so the numbers above do
not compare with these. Main at `d12910bb` was run again on the same
simulator for that. The fixture server is a small Python script that
answers every `poster/` and `backdrop/` path with the same 600 by 900 or
1920 by 1080 JPEG after 100 ms; it is not in the repository. Every run
is the same walk as above, three runs each, one after the other in the
same launch. Not ready is `posterMisses` over `posterAsks`.

| Walk | Build | Dropped frames (hitch ms) over frames counted | Posters not ready |
|------|-------|-----------------------------------------------|-------------------|
| Along the posters | main `d12910bb` | 38 (621) / 413, 42 (669) / 409, 38 (590) / 414 | not counted |
| | card, no prefetch | 77 (1272) / 464, 75 (1227) / 495, 72 (1173) / 499 | 6 of 37, 0 of 35, 0 of 35 |
| | card, prefetch, 400 MB | 73 (1233) / 466, 73 (1167) / 496, 75 (1181) / 463 | 1 of 37, 1 of 34, 0 of 35 |
| Down and up the rows | main `d12910bb` | 49 (766) / 582, 39 (602) / 619, 38 (606) / 622 | not counted |
| | card, no prefetch | 84 (1405) / 668, 80 (1313) / 670, 86 (1343) / 670 | 85 of 183, 18 of 158, 19 of 158 |
| | card, prefetch, 160 MB | 88 (1450) / 663, 82 (1314) / 670, 90 (1473) / 662 | 39 of 182, 49 of 156, 58 of 158 |
| | card, prefetch, 320 MB | 79 (1313) / 670, 85 (1393) / 665, 82 (1364) / 668 | 1 of 182, 18 of 156, 20 of 158 |
| | card, prefetch, 400 MB | 84 (1401) / 667, 81 (1377) / 669, 81 (1299) / 669 | 1 of 184, 1 of 169, 1 of 160 |
| Standing still | main `d12910bb` | 5 (19) / 502, 7 (69) / 474, 6 (119) / 505 | |
| | card, prefetch, 400 MB | 12 (210) / 589, 15 (202) / 589, 11 (188) / 591 | |

What this showed then:
- Loading ahead worked once the memory held it: at 400 MB about 1 poster
  in 170 was still loading when its card showed. Without it the first walk
  found 85 of 183 still loading, and later walks 1 in 8, since the first
  walk left most of their posters in memory.
- The change missed about twice as many frames as main in the simulator,
  on every walk and standing still too, with the prefetch or without. Not
  explained. Standing still presses nothing, so the moves and the card's
  growing are not the whole cause; the screen shows two and a half rows
  instead of one, and each probe reading walks the app's accessibility
  tree on its main thread, which may count as missed frames. Instruments'
  hitch templates do not record on the tvOS simulator, so this needs the
  device check below before archiving.

### At 50 MB, 2026-11-25

The same simulator, fixture server and walks, with the Mac at a load
average of 2 to 6. The commit before this rework, `973cdeb7` (400 MB,
focus headroom, 8 ahead), ran again in the same hour to compare.

`posterAsks` counts differently now. Before, every load a card or the
expanded card started counted, and a card coming back on screen asked
again. Now a card counts once each time it shows, when it looks in memory
before its first frame, and the expanded card's picture does not count.
So the asks are lower and compare only within each build.

| Walk | Build | Dropped frames (hitch ms) over frames counted | Posters not ready |
|------|-------|-----------------------------------------------|-------------------|
| Along the posters | `973cdeb7`, 400 MB | 75 (1200) / 492, 75 (1188) / 498, 73 (1218) / 468 | 2 of 38, 0 of 34, 0 of 35 |
| | 50 MB, no prefetch | 73 (1164) / 467, 79 (1255) / 493, 74 (1203) / 463 | 4 of 13, 2 of 13, 0 of 13 |
| | 50 MB, prefetch | 72 (1190) / 468, 78 (1249) / 493, 73 (1211) / 496 | 0 of 13, 0 of 13, 0 of 13 |
| | 50 MB, prefetch, backdrops apart | 76 (1267) / 463, 74 (1232) / 498, 83 (1330) / 459 | 0 of 13, 0 of 12, 0 of 13 |
| | 50 MB, around the highlight | 81 (1290) / 519, 82 (1323) / 519, 78 (1271) / 519 | 0 of 13, 0 of 12, 0 of 12 |
| | 50 MB, column kept | 80 (1290) / 550, 79 (1287) / 521, 86 (1320) / 518 | 0 of 10, 0 of 13, 0 of 12 |
| Down and up the rows | `973cdeb7`, 400 MB | 88 (1456) / 662, 78 (1283) / 671, 88 (1383) / 665 | 1 of 182, 1 of 156, 1 of 158 |
| | 50 MB, no prefetch | 82 (1374) / 667, 92 (1505) / 660, 88 (1437) / 663 | 85 of 112, 99 of 126, 104 of 127 |
| | 50 MB, prefetch | 78 (1288) / 671, 80 (1291) / 668, 92 (1502) / 656 | 14 of 112, 30 of 126, 50 of 127 |
| | 50 MB, prefetch, backdrops apart | 91 (1430) / 662, 86 (1366) / 667, 87 (1384) / 661 | 14 of 112, 29 of 126, 50 of 127 |
| | 50 MB, around the highlight | 94 (1548) / 687, 92 (1539) / 718, 98 (1572) / 684 | 6 of 112, 15 of 126, 36 of 127 |
| | 50 MB, column kept | 106 (1730) / 674, 93 (1523) / 686, 95 (1575) / 686 | 2 of 104, 1 of 120, 1 of 120 |
| Standing still | 50 MB, prefetch | 11 (195) / 591, 10 (175) / 589, 9 (206) / 591 | |

What this shows:
- Frames: 50 MB misses as many frames as 400 MB on every walk. The
  posters that load late cost no frames that the probe sees.
- Along a row the window ahead is enough: no poster was still loading
  when its card showed.
- Down and up the rows, 1 card in 8 showed the placeholder on the first
  walk, 1 in 4 on the second and 2 in 5 on the third, where 400 MB had
  almost none. Most of these are rows coming back on the way up, whose
  posters left memory; they decode again from the disk, so the
  placeholder shows for the time of a file read and a decode, and the
  poster fades in. Without loading ahead, 3 in 4 or more did. Each walk
  finding more than the one before is explained below.
- Backdrops sharing the 50 MB with posters do not explain it. "Backdrops
  apart" kept wide pictures in a memory of their own, 24 MB, with the same
  order of letting go and the same purge on low memory, and posters alone
  in the 50 MB. It found 14, 29 and 50 not ready, the same as before. That
  memory is not in the code: it bought nothing here, and a backdrop decoded
  for a 4K window, about 33 MB, would not fit in 24 MB at all.
- Also ruled out: the order the memory lets go in (the `NSCache` runs
  below), and how far the next row loads ahead on the first walk (14 of
  112 against 46 of 112 with only the row under).

#### Why each walk finds more posters not ready

A debug probe, `shelf.debug.posterTrace`, counts where posters go:
loads started ahead, loads stopped, posters let go of before any card
showed them, by who asked, and cards that found no load at all. The
benchmark prints it before and after each walk, with the row and the
position the highlight is on.

- The highlight does not come back to where it started. Each move up or
  down lands it a poster to the right of its column, since the expanded
  card is wider than a poster and the focus engine picks the poster under
  its middle. The first walk starts on the first poster of Recently added
  and ends on the eighth; the second ends on the ninth, the third on the
  tenth. Every row the highlight moves into then scrolls sideways to that
  column, to posters nothing loaded: the rows had loaded their start as
  they came into view. Cards that found no load at all went from 12 to 15
  to 24 per walk.
- Pressing left 15 times after each walk, so every walk starts on the
  first poster, found 5, 20 and 24 not ready instead of 14, 29 and 50
  (with the change below). The rise from the first walk to the second
  remains: the first starts with only the first rows in memory, the later
  ones with what the walk before left.
- Rows the stack keeps alive do not skip loading: the rows load ahead 11
  times per walk, every walk. A row scrolling away stopped no load (0 in
  every walk), and no load was left running after a walk. Rows still
  listed about 22 finished loads as wanted after each walk; that is fixed,
  it did not cause misses.
- Each row coming into view showed its first 9 or 10 posters at once, and
  each asked for the 3 after it, so posters that were never shown loaded
  along the rows, 53 to 85 per walk, and 44 to 64 of them were let go of
  unshown. Now a row loads nothing along it for 0.5 s after it comes into
  view (`PosterPrefetch.Trail.settle`): 13 to 21 per walk.

What changed:
- While the highlight rests on a poster, the rows above and below load
  the 8 posters around the poster to the right of its column
  (`PosterPrefetch.around`), the ones they show once the highlight moves
  into them. A new position stops what the last one asked for that no
  card waits for.
- The 0.5 s pause along a row that just came into view, and a finished
  load is no longer listed as wanted.
- "Around the highlight" in the table: 6, 15 and 36 not ready. Loading the
  next row around the column instead of at its start, without the rows by
  the highlight, made it worse (21, 59 and 65): the rows still show their
  start as they come into view.
- Each walk still found more than the one before, since the highlight
  still moved right: cards that found no load at all were 9, 18 and 39.
  Decision 6 keeps the column, and "column kept" in the table found 2, 1
  and 1 not ready. At 0.4 s between presses the highlight still slips a
  poster now and then: the three walks ended on the first, second and
  third poster of Recently added, against the eighth, ninth and tenth
  before. `testDownAndUpTheRowsKeepsTheColumn` walks at 0.6 s and comes
  back to the first poster in each of 10 runs.
- Dropped frames on the walk down and up went from 78 to 92 (before the
  rows by the highlight loaded ahead) to 92 to 98, and to 93 to 106 with
  the column kept (103 to 105 in a first run). Finding the highlight's
  position is not the cause: 16 to 40 µs a move. With the column kept,
  each move between rows is two focus changes, the focus engine's and the
  correction, each starting the rest timer and the loads around the
  highlight again. Not measured apart.
- A geometry reader on every row, to count the posters a row shows, cost
  about 40 dropped frames per walk down and up (about 127 against 88). The
  count now comes from the window's width, read once.
- The memory now lets go of the poster shown longest ago first, where
  `NSCache` lets go in no set order. On this walk that made no measurable
  difference (12, 31 and 53 not ready with `NSCache`); it is kept because
  the order is then known.
- The next row ahead follows the direction of the scroll: the row under
  on the way down, the row above on the way up. Loading only the row
  under found 46 of 112, 65 of 123 and 72 of 123 not ready.

### Frames against main, 2026-11-25 evening

The same simulator and fixture server. Main is `7b0a4998`, the proposal's
commit, whose app is main's, built with this branch's benchmark file so
both measure the same way. Runs alternated main, branch, main, branch in
one hour, at a load average of 2 to 7; other agents' simulators ran on
the Mac for parts of the evening, and runs taken then are left out.

The benchmark changed first. Each probe read walks the app's
accessibility tree on its main thread, and the reads of the poster counts
and the trace sat inside the window between the two frame counts, so they
were counted as missed frames: standing still read 8 to 27 dropped
frames. The frame counts are now read last before a walk and first after
it, and the trace outside it (`gapsBefore`, `gapsAfter`). Main measured
the old way had 2 reads inside the window, the branch 6.

| Walk | Build | Dropped frames (hitch ms) over frames counted |
|------|-------|-----------------------------------------------|
| Along the posters | main | 36 (668) / 413, 34 (741) / 409, 38 (722) / 409; 36 (700) / 411, 36 (706) / 410, 34 (717) / 411 |
| | branch | 85 (1536) / 389, 83 (1559) / 390, 94 (1619) / 351; 84 (1527) / 389, 78 (1465) / 396, 84 (1440) / 394 |
| Down and up the rows | main | 52 (995) / 573, 36 (708) / 589, 34 (643) / 623; 46 (868) / 611, 37 (755) / 619, 36 (708) / 620 |
| | branch | 91 (1632) / 563, 82 (1520) / 574, 84 (1564) / 571; 95 (1619) / 564, 75 (1358) / 579, 80 (1423) / 576 |
| Standing still | main | 1 (151) / 505, 2 (104) / 506, 3 (138) / 504; 2 (136) / 504, 2 (132) / 507, 1 (186) / 503 |
| | branch | 5 (276) / 499, 5 (211) / 470, 4 (251) / 500; 4 (164) / 505, 2 (134) / 505, 2 (160) / 503 |

Standing still is now as quiet as main. Moving, the branch misses about
twice the frames.

What each part costs, turned off one at a time with a launch argument
(since removed), on the walk along the posters and down and up, three
walks each, at a load average of 2 to 4:

| Turned off | Along the posters | Down and up the rows |
|------------|-------------------|----------------------|
| nothing | 86, 90, 86 | 91, 72, 80 |
| the card's blurred copy and shadow | 76, 85, 86 | 86, 76, 83 |
| the card's picture | 79, 85, 82 | 86, 76, 81 |
| the card's copy | 81, 80, 78 | 83, 83, 81 |
| the card's growing animation | 80, 71, 73 | 85, 73, 74 |
| the whole card (load average 9 to 11) | 55, 54, 59 | 61, 52, 54 |

And earlier, measured the old way: keeping the column with two focus
changes per move cost about 15 dropped frames per walk down and up; the
loads around the highlight, the trace probe and the fade did not change
the counts beyond the runs' spread.

A Time Profiler recording of the walk along the posters, main thread
only, found 13 500 samples on the branch against 9 600 on main. The
difference is SwiftUI's own work: per-frame updates driven by the display
link, 5 060 samples against 1 290, much of it the rows' lazy stacks
laying out and walking their `ForEach` again on each frame of the growing
animation; the app's own code is under 1% of the samples. Without the
growing animation the display link took 1 990.

What changed for frames:
- The benchmark reads described above.
- One focus move per move between rows in place of two (decision 6).

Tried and not kept:
- Blurring a copy an eighth of the size: no change beyond the spread.
- A growing animation of 0.15 s instead of 0.25 s: no fewer dropped
  frames.

What remained then: the card itself, about 30 dropped frames per walk
along the posters, which no single part of it explains, and about 15 more
from two and a half rows on screen where main shows one. Main changes
nothing on screen for a move along a row until the 0.8 s rest; the card
changes on every move. Decision 7 took the card's growth out of the
row's layout; "The card outside the row's layout" has what that bought.

### The card outside the row's layout, 2026-11-27

The same simulator, fixture server and walks (decision 7). Main is
`056a5fe2`, built with this branch's benchmark file, whose wait for the
card is left out since main has none. Other agents ran builds and
simulators on the Mac through the day, at load averages up to 250, so
every run waited until the one-minute load average was under 7 and the
five-minute one under 10; the runs taken under load are left out. Runs
alternated branch and main.

| Walk | Build | Dropped frames (hitch ms) over frames counted |
|------|-------|-----------------------------------------------|
| Along the posters | main | 34 (693) / 413, 37 (716) / 411, 31 (641) / 416; 33 (621) / 415, 31 (592) / 446, 34 (666) / 443 |
| | branch | 80 (1358) / 397, 72 (1269) / 376, 79 (1391) / 365; 80 (1449) / 394, 82 (1514) / 363, 79 (1406) / 371 |
| Down and up the rows | main | 47 (806) / 612, 34 (664) / 623, 36 (716) / 621; 44 (871) / 612, 32 (635) / 623, 32 (603) / 595 |
| | branch | 80 (1483) / 573, 65 (1135) / 591, 64 (1197) / 591; 74 (1394) / 582, 65 (1244) / 589, 72 (1220) / 557 |

Against 2026-11-25 the walk down and up went from 75 to 95 dropped frames
to 64 to 80, and the walk along the posters from 78 to 94 to 72 to 82, with
main about the same both days. The target, within about 15% of main
plus 15 frames for the extra rows, is about 40 along the posters and 60
down and up. Not met.

What each part costs now, turned off one at a time with a launch
argument (since removed), at the same load:

| Turned off | Along the posters | Down and up the rows |
|------------|-------------------|----------------------|
| nothing | 72 to 82 | 64 to 80 |
| the card's fade (it shows at once) | 74 to 79 | 64 to 69 |
| the card | 66 to 76 | 63 to 80 |
| the card, the offsets, the `zIndex` and the poster's shrink | 56 to 63 | 54 to 60 |

A Time Profiler recording of the walk along the posters, main thread
only, under load, found 14 700 samples on the branch, 8 600 on main, and
10 300 with the card, the offsets and the `zIndex` turned off. Turning off
the offsets and the `zIndex` alone did not change the count. The display
link's per-frame updates went from 5 200 samples to 2 000 without the
card; main has 1 200.

What this shows:
- The lazy stacks' own measuring is 22 samples of the display link's
  5 200. The display link's total is about what it was on 2026-11-25
  (5 060): the per-frame work moved from laying out the row to animating
  the card and the posters it moves aside, and walking the row's
  `ForEach` on each frame of it (470 samples against 55 on main).
- With no card and nothing moved aside, the branch still drops about 25
  frames more than main on each walk. That part is not the card: the
  rows under the focused one, the loads ahead, the column keeping and
  the debug probes are left, each of which measured within the runs'
  spread when turned off alone on 2026-11-25.
- The card costs about 10 frames per walk and the room it makes about 10
  more. SwiftUI animates each on the main thread, a frame at a time.
- Showing the card without its fade changes nothing beyond the spread.

Tried and not kept:
- The card inside the poster's button, as an overlay: the system card
  style clips it to the poster's width.
- The poster at no opacity under the card: the button left the
  accessibility tree.
- The card flattened with `drawingGroup`: the recordings failed while
  the Mac's disk was full, and it was not measured.

## What to check on the device

- Move along Recently added and a long category at a steady pace: each
  poster grows as the highlight reaches it, the posters after it slide
  aside in one movement, and the pictures are there.
- Rest on a poster: about a second later the facts and plot fade in, and
  the backdrop over the poster.
- Move down and up through ten rows: each row comes up under the tab bar
  in one movement with the two rows below it in view.
- Open a title from the third row and press Menu: the same poster is a card
  again at once.
- Instruments' Animation Hitches template on the device while browsing:
  under 5 ms/s is the target.
- Move down ten rows quickly and back up: posters not yet there are quiet
  shapes that fade in, with no name tiles flashing, and a poster seen a
  moment ago shows at once. With Reduce Motion on they appear without the
  fade.
- Instruments' Allocations on the device: decoded posters stay under 50 MB
  after ten minutes of browsing.

## Open after this change

- `title-detail-and-episode-picker/back-to-where-you-were` says "with that
  poster focused and its preview showing". `posters-open-the-title-page`
  modifies the same requirement; whichever change archives second says
  "card" there.
