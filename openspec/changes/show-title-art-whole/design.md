## Context

The title page drew its backdrop with `FittedArt`, the banner's rule: fill
the frame, or show the picture whole at the bottom right, at most half the
frame's width, when filling would hide more than half of it. The frames did
not suit the pictures. On a 402 wide iPhone the frame was the status bar
plus 226 points, about 1.4:1, so a 16:9 backdrop lost a fifth of its width,
its top 62 points sat under the status bar and an 80 point scrim covered
its foot. A poster as backdrop showed small in the corner. The iPad card was
380 tall at any width, about 2.3:1 at 866 wide, and cut a 16:9 picture's
top and bottom. The Apple TV series band, 1920 by 520, showed a 16:9
picture at half the width in the corner.

The page also drew while its details loaded: the name from the catalogue,
a spinner in the details line, the poster where the backdrop goes and, for
a series, the episode loader. When the details came in, each part changed
in turn.

## Boards and design-system requirements

- `iPhone-Title`, `iPhone-Series`: the backdrop at 16:9 with Back over it.
  The boards draw the 220 tall art under the status bar; the app now keeps
  the status bar band for a blurred copy and gives the picture its own 16:9
  below it. The boards are not redrawn.
- `iPad-Title`, `iPad-Series`: the card with the copy over the left scrim.
  The boards draw it 300 and 240 tall; the app sizes it 16:9 between 380
  and 560.
- `TV-Title`, `TV-Series`: unchanged in layout.
- `design-system/the-scrim-blends-into-the-art`: the hero scrims stay.
- `design-system/the-mark-moves-at-three-moments` and
  `design-system/reduce-motion-stills-the-mark`: Tuning while the details
  load, then Got it. No board draws the loading title page; it is the
  ground with the mark in the middle, as on the Apple TV loading screen.

## Decisions

### 1. A rule of the title page's own, in AntennaCore

`TitleArtPlacement.place(pictureWidth:pictureHeight:in:alignment:margin:)`
returns the picture's box in the area and one of three looks:

- `fills` when filling the area cuts at most 8% (`mostCut`), so a 1.85:1
  picture in a 16:9 area fills.
- `whole` for any other picture at least as wide as tall: across the area's
  width, or down its height against the side `alignment` names.
- `framed` for a picture taller than wide: inset by `margin`, rounded, with
  a shadow.

`phoneArea(width:top:)` is the iPhone's 16:9 area under the status bar and
`cardHeight(width:)` the iPad and Mac card. `shown(in:)` is the share of
the picture inside the area, which the tests read.

Options considered: change `ArtFit` and `FittedArt` for both the banner and
the title page, or keep the banner's rule and give the page its own. The
owner said the banner works well on iPhone, so it keeps `ArtFit` and
`FittedArt` untouched and the page gets the new rule.

### 2. iPhone: a 16:9 area under the status bar, no scrim on the picture

The art frame is the status bar, then `width * 9 / 16`, then a 24 point
band. A blurred copy darkened by the ground at 35% fills the frame; the
picture sits in the 16:9 area, alignment `center`, margin 12. The scrim is
24 points tall and covers only the band under the picture.

Options considered: keep the art under the status bar and cut its top, or
lengthen the scrim inside the picture. Both hide part of the picture.

### 3. iPad and Mac: a card 16:9 for its width, held between 380 and 560

At 866 wide the card is 487 tall and a 16:9 picture fills it. Below 676
wide it stays 380 so the copy fits. Above 996 it stays 560 so the words
stay in view in a wide window, and a 16:9 picture shows whole at the right
with its left edge fading into the blur under the copy. Alignment
`trailing`, margin 28. The page reads its width through a GeometryReader
around the page, so the first frame has the right height.

### 4. Apple TV: the same rule, aligned right

Alignment `trailing`, margin 120. A 16:9 picture on the 1920 by 1080 movie
page fills as before; on the 520 tall series band it is 924 wide at the
right. A poster is 840 tall at the right, inset 120.

### 5. The page waits for its details, behind the mark

`TitleReveal` is the stage: `waiting` (ground alone), `tuning` (the mark),
`gotIt`, `page`. A page that opens with its details known starts at `page`.
After `delay`, 0.3 seconds, `waiting` becomes `tuning`. When the load ends,
`waiting` goes to `page` and `tuning` to `gotIt`, which holds for half of
Got it's length (0.6 s, 0.2 s with Reduce Motion) before the page fades in
over 0.25 s. Retry on a shown page keeps it shown; the details line has its
own loading indicator for that.

`TitlePage.Reveal` runs the stages and wraps each layout's content: the
whole page on iPhone and Apple TV, and the scroll view under the toolbar on
iPad and Mac, so the toolbar's Back stays. On iPhone the veil shows the
glass Back at the top leading corner. The mark is `BrandMark.Letter`, 96
points on iPhone, 112 on iPad and Mac, 180 on Apple TV, identified as
`title.loadingMark` and read as "Loading details".

The content is not built while it is hidden, so Apple TV's focus goes to
Play when the page appears, through the layout's own task.

Options considered: build the page hidden and fade it in, which keeps
hidden buttons focusable on Apple TV; or wait for the backdrop's picture
too, which would need the picture loaded outside the page. The picture
fades in over its black area when it arrives.

### 6. Debug launch argument for posters as backdrops

`-ui-testing-poster-backdrop` with `-ui-testing-store-shots` makes every
scripted backdrop its title's poster, for screenshots of that case.

## Risks

- A provider that answers in 0.35 s shows the mark for a moment and then
  Got it. The 0.3 s delay keeps most cached and local answers free of it.
