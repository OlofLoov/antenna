## Why

The owner, opening a movie on an iPhone on 2026-11-26: the title page "is
really not showing all the contents of the images, making it look like
rubbish". The iPhone page filled a frame taller than 16:9, so a 16:9
backdrop lost a fifth of its width, its top sat under the status bar and a
scrim covered its foot. A poster sent as the backdrop shrank to a small
picture in the corner. The iPad card, 380 tall at any width, cut the top
and bottom off a 16:9 backdrop.

The same day: "when entering a series or film some content shows, and once
more is loaded that data is shown instead or as well. Quite glitchy. I'd
rather have a loading animation using our logo instead."

Afterwards someone who opens a title sees its whole picture on every
device, and the page appears in one piece once its details are in, with the
Antuna mark tuning while they wait.

## What Changes

- iPhone: the backdrop gets an exact 16:9 area under the status bar. A
  blurred copy of the picture fills the status bar band and a short band
  below the picture, where it fades into the ground. The scrim no longer
  covers the picture.
- iPhone: a poster sent as the backdrop shows whole in the middle of that
  area, nearly its full height, with rounded corners.
- iPad and Mac: the card is 16:9 for its width, between 380 and 560 points
  tall. A 16:9 backdrop shows whole; in a card held at 560 it sits against
  the right, fading into its blurred copy under the copy. A poster shows
  whole at the right of the card.
- Apple TV: the movie page is unchanged for a 16:9 backdrop. The series
  band, 520 tall, shows a 16:9 backdrop whole at the right instead of a
  small picture in the corner. A poster shows whole at the right, larger.
- Everywhere: a picture within 8% of its area's shape fills it edge to
  edge; any other shows whole over its blurred copy.
- Every platform: while the details load the page stays hidden. After 0.3 s
  the mark tunes in the middle of the ground, with Back on iPhone and iPad.
  When the details arrive or fail the mark plays Got it and the page fades
  in whole. A load under 0.3 s goes straight to the page with no mark.
  Details known already show the page at once.

Out of scope:

- The Movies and Series banner. It keeps its own rule and draws exactly as
  before.
- Holding the page until the backdrop's picture has downloaded. It fades in
  over the black area when it arrives.
- The person page and the About page.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `title-detail-and-episode-picker`: "What the title is about" says the
  backdrop shows whole and changes the poster scenario; new requirement
  "The page shows in one go".

## Impact

- Boards: `iPhone-Title`, `iPhone-Series`, `iPad-Title`, `iPad-Series`,
  `TV-Title`, `TV-Series`.
- Apps: `TitlePage.Backdrop` moves to its own file and places the picture
  by a new AntennaCore rule, `TitleArtPlacement`; `TitlePage.Phone`,
  `TitlePage.Pad` and `TitlePage.Television` size their art from it and wrap
  their content in `TitlePage.Reveal`, driven by AntennaCore's
  `TitleReveal`. A Debug launch argument shows posters as backdrops for UI
  tests and screenshots.
- Tests: AntennaCore unit tests for both rules, iPhone and iPad UI tests
  for the loading mark.
- Depends on the mark's moments (`design-system/the-mark-moves-at-three-moments`).
  Blocked on nothing.
- No new container, dependency or stored data, so the C4 diagrams stay as
  they are.
