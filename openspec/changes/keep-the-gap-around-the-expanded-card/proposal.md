# Proposal

## Why

> As a viewer on Apple TV, I want the card a poster grows into to sit in its row like the posters do, with the same space on each side, and the highlight around the whole card, not around a poster-sized patch under it.

On the owner's Apple TV, the card a focused poster grows into touched the posters beside it, and the focus lift and shadow stayed at the poster's size under the card. Both came from how the card is drawn since `expand-focused-title-on-apple-tv` took it out of the row's layout:

- The card is lifted by 1.06 about its middle, so it reaches 17 pt past its slot on each side. The posters after it move aside by the card's unlifted extra width, so 3 pt of the row's 20 pt gap was left on each side.
- The poster's button kept the system card style. That style lifts the focused button by about an eighth, so under the card the poster's slot was lifted and shadowed at the poster's size, its platter reaching above and below the card, and a second highlight showed beside the card's own.

## What Changes

- The card grows from its slot's leading edge, and the posters after it move aside by the lifted card's extra width, so the row's gap stays on both sides of the card as drawn.
- In a row whose posters grow into cards, the poster's button only holds focus and draws no look of its own. The card's lift and shadow are the highlight. The poster under the card no longer shrinks, since nothing lifts it.
- The design-system exception list names the expanded card as a part the app draws.

Out of scope: the genre grids, Search, Continue watching and posters off Apple TV, which keep their system styles and draw no card. The frame-rate work of `expand-focused-title-on-apple-tv` stays as it is: the slots, the offsets and the card over the row's stack do not change.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `movies-and-series-browsing`: "Expanded card for the focused title on Apple TV" gains "The card keeps the row's spacing" and "The highlight is the card".
- `design-system`: "Controls use system styles" lists the expanded card among the parts the app draws, and its poster scenario separates posters that grow into a card.

## Impact

- Platforms: Apple TV. iPhone, iPad and Mac draw no card; their posters keep the borderless style and the pointer's hover at the poster's size.
- Code: `ShelfExpandedCard` (a `Geometry` for the card and its neighbours, the lift's anchor, the poster's button style), `ShelfView.PosterCard` and `ShelfView.Row`.
- Depends on `expand-focused-title-on-apple-tv`, archived.
