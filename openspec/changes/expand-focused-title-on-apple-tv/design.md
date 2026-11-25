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
deleted. `TV-Movies`, `TV-Movies-Rows` and the iPhone, iPad and Mac boards
do not change. Series uses the same boards with `series.` identifiers.

Design-system requirements followed:
`design-system/apple-tv-content-stays-in-the-safe-area` (the rows and the
card's copy start at x 80), `design-system/controls-use-system-styles` (the
card is the poster's own button, with the system card focus),
`design-system/one-accent-color-per-profile` (the eyebrow is muted).

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

The card is drawn inside the poster's button (`ShelfExpandedCard.Expanding`
in `ShelfView.PosterCard`), which reads `isFocused`. It grows the moment
the button takes focus, in its own `withAnimation(.easeOut(0.25))`
transaction, so the `LazyHStack` slides the posters after it in the same
movement; with Reduce Motion the sizes change without animation. Only the
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
  which: when a poster in a row shows, the next 8 in its row; when a row
  shows, the first 8 posters of each of the 2 rows under it.
  `PosterCache.prefetch` loads and decodes them at the card's frame, the
  same key the card asks for, so the card finds them in memory. A card that
  asks while one loads joins it. Each row is a group; a newer call for the
  group stops the group's loads nobody waits for, so a fast swipe does not
  leave a queue. Prefetches run at utility priority.

The triggers are `onAppear` of a poster and of a row, which every platform
has, so iPhone, iPad and Mac load ahead of their scroll too. They read the
rows from the library in the action, not in a body, so a change to the
rows redraws nothing.

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

The implementation PRs add the numbers after each step.

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

## Open after this change

- `title-detail-and-episode-picker/back-to-where-you-were` says "with that
  poster focused and its preview showing". `posters-open-the-title-page`
  modifies the same requirement; whichever change archives second says
  "card" there.
