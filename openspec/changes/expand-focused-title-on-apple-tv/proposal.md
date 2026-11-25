## Why

The owner, browsing Movies on an Apple TV on 2026-11-25: "Instead of
displaying the selected content at the top when browsing, Netflix displays
it more inline, effectively making it easier to scroll through content."
Today the top 520 pt of Movies and Series show a preview of the poster the
highlight rests on, so one row fits under it and every move down scrolls a
row into a fixed slot. Netflix's Apple TV app grows the focused poster into
a wider card in its own row, with the backdrop, the name, the facts and a
line or two of plot, and the rows below stay in view.

The owner also asked: "The menu browsing can still get quite laggy, do we
need to fetch more content at initial load or how do we do it?" The title
lists already load whole when the section opens. Posters do not: each one
starts downloading only once its card is laid out on screen, so a swipe
along a row or down to the next row shows name tiles that turn into
pictures a moment later. A move down also waits 350 ms before the row
slides into place, even when the row is already in view.

After this change a viewer on Apple TV sees two and a half rows at a time,
the focused title opens up in place as they move, and posters ahead of the
highlight are already there when it gets to them.

## What Changes

- On Apple TV the poster with the highlight grows at once into a landscape
  card the height of a poster, in its row: the picture, the category, the
  name, and once the provider has answered, the facts and two lines of
  plot. The posters after it slide aside. The preview at the top of Movies
  and Series goes away, and the focused row rests just under the tab bar.
  A move down to a row already in view slides it up at once instead of
  after 350 ms.
- The 0.8 second rest still decides when the provider is asked about a
  title; posters passed quickly are never asked about. The card shows what
  the row knows at once and fades the rest in when the answer arrives.
- Back from a title page or the player, the poster it opened from has the
  highlight again and is expanded at once.
- On every platform, posters load ahead of the highlight or the scroll:
  the next posters in the direction of travel along a row, and the first
  posters of the rows just below. They are decoded at the card's size away
  from the main thread, as on screen.
- A benchmark records frames missed while moving along and down the rows
  on the `large` library, before and after, in design.md.

Out of scope:
- iPhone, iPad and Mac keep showing no preview and no expanded card.
- Fetching more of the title lists up front. They already load whole; see
  design.md, "What a move waits for".
- The title page, the banner and the genre grids look the same.
- Frame rates on a device. The owner checks the device with Instruments
  (design.md, "What to check on the device").

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `movies-and-series-browsing`: "Preview of the focused title on Apple TV"
  becomes "Expanded card for the focused title on Apple TV". "Browsing stays
  responsive" adds posters ahead of the highlight and a frame budget for
  moving through the rows. "Title details are asked once per title" says
  card where it said preview.

## Impact

- Apps: `ShelfTVScreen`, `ShelfTVFocusFollower`, `ShelfPreviewFocus`, the
  `ShelfView` poster card, `ShelfModel` (details readable per title),
  `PosterLoading` and `PosterCache` (prefetch), and a new expanded card
  component in `Apps/Shared/Components/Shelf/`. `ShelfPreview` goes.
- AntennaCore: a pure prefetch window over a row's titles, with tests.
- Boards: `TV-Movies-Expanded`, `TV-Movies-Expanded-Loading` and
  `TV-Movies-Expanded-Poster-Only` replace the three `TV-Movies-Preview`
  boards.
- UI tests in `ShelfPreviewTVUITests`, `ShelfRowsUpTVUITests` and
  `ShelfLargeTVUITests` move from the preview to the card.
- Works alongside `posters-open-the-title-page`, which makes a movie poster
  on Apple TV open its page instead of playing; the card does not depend on
  what select does.
- No new container, dependency or stored data, so the C4 diagrams stay as
  they are.
