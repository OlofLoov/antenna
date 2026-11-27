# Design

## Context

Decision 7 of `expand-focused-title-on-apple-tv` keeps every poster in its
212 pt slot, draws the card over the focused slot in an overlay of the
row's lazy stack, and offsets the posters after it by 354 pt, the card's
566 pt less a poster. The card lifts itself by 1.06 about its middle, since
it sits outside the button. The poster's button keeps the system card
style, and the poster shrinks to 0.9 under the card so the system's lift
keeps it inside.

On the device:
- Drawn at 1.06, the card is 600 by 337 and reaches 17 pt past its slot on
  each side. With the posters moved aside by 354, 3 pt of the 20 pt gap is
  left before and after it.
- The card style lifts the whole button with its platter and shadow, to
  about 238 by 356, past the card's 337 pt height, so a poster-sized
  highlight showed beside the card's own shadow.

## Boards

`TV-Movies-Expanded`, `TV-Movies-Expanded-Loading` and
`TV-Movies-Expanded-Poster-Only` already draw the card with the row's gap on
both sides and one shadow, around the card. They do not change.

Design-system requirements followed:
`design-system/controls-use-system-styles` (the expanded card joins the
parts the app draws), `design-system/apple-tv-content-stays-in-the-safe-area`
(the first card's leading edge stays at x 80, and its copy inside it).

## Decisions

### 1. Where the lifted card sits

Options:
- **No lift.** The card at 566 by 318, the posters moved by 354. Exact gaps,
  but the focused card would sit flat beside the resting posters.
- **The lift about the middle, the posters moved by the lifted width.** The
  gap after the card is right; the 17 pt before it still covers the
  previous gap.
- **The lift from the slot's leading edge and about the row's middle, the
  posters moved by the lifted extra width.** Chosen. The card's leading edge
  is the slot's, so the gap before it is the row's; the posters after it
  move by 600 less 212, 388 pt, so the gap after it is too.

`ShelfExpandedCard.Geometry` gives the lifted size, the offset aside, the
card's frame over a slot and each poster's frame. The row's overlay, the
posters' offsets and the row's trailing room all read it, and the unit
tests check its gaps.

### 2. Which view draws the highlight

Options:
- **The card inside the button, with the system card style.** The style
  clips its label to the label's frame (tried in the first change).
- **The card inside the button, with `hoverEffect(.highlight)`.** The
  system lift and tilt would wrap the card, but the card would be a child
  of the lazy stack again and need a `zIndex` over the posters after it,
  which decision 7 removed for frame time.
- **The button only holds focus, the card draws the lift and shadow.**
  Chosen. In a row with a card room and a card source the poster's button
  takes `FocusHolderStyle`, so no system lift, platter or shadow is drawn
  at the poster's size. The card already drew its lift and shadow; they
  are now the only highlight. The tilt with the remote is not drawn on the
  card.

The poster under the card stays drawn at full size, since nothing lifts it
and the opaque card covers its slot with room on every side. Its 0.9 shrink,
and its animation, are gone. Focus, the column keeping, VoiceOver and the
UI tests' `hasFocus` still read the poster's button.

## Performance

Nothing laid out changes: the slots, the offsets (388 pt instead of 354),
the trailing room and the card over the stack are as in decision 7. Each
focus move animates one fewer view (the poster's shrink) and the system
card style's lift no longer runs on the button under the card. Neither
adds main thread work per frame.

## Identifiers

`ShelfExpandedCard.Geometry`, `View.cardPosterButtonStyle()`.
`ShelfExpandedCard.under` is removed.

## What to check on the device

- Move along Recently added: the card has the same space before and after
  it as the posters have between them, and no lighter edge or second
  shadow shows above, below or beside it.
- The first poster of a row: the card starts at the row's margin, and its
  copy is inside the safe area.
