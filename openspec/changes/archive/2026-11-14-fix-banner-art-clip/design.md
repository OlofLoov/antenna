# Design

## Context

`ShelfBanner.Art` put the picture in a `ZStack` over the placeholder color and clipped the stack:

```swift
ZStack {
    placeholder
    Image(decorative: image, scale: 1).resizable().scaledToFill()
}
.clipped()
```

A `scaledToFill` image answers the size it needs to fill the space it is offered, which is larger than that space when the shapes differ. A 2:3 poster offered 1920 by 640 answers 1920 by 2880. The stack takes the larger size, so `.clipped()` cuts to 1920 by 2880 and cuts nothing. The layouts in `ShelfBannerLayouts.swift` then frame the art:

- `Television` frames it at 640 pt and never clips after the frame, so the picture hangs 1120 pt above and below the banner, behind the tab bar and the rows, and moves with them.
- `Pad` puts the art in the same `ZStack(alignment: .topLeading)` as the copy, so the stack grows with the picture and the copy slides up out of the 330 pt card.
- `Phone` frames and clips after the frame, so it looked right only because of the order of its modifiers.

A backdrop is close to the banner's shape, so the bug shows when the banner falls back to the poster: for a title without a backdrop, and for every title until its info call answers with one. Each page brings a different picture, so the overflow changes on every turn.

`TitlePage.Backdrop`, `ShelfView.LandscapeArt` and `PosterTile` drew the same way. `PosterTile` with a picture that is not 2:3 grew the poster card.

## Decisions

### One view that takes its size from the color

`FilledArt` draws the background color, puts the picture in an overlay of the color and clips after that. A color takes exactly the space it is offered, an overlay is offered the color's size, and the clip cuts the overlay to that size. The picture can no longer size the view, wherever a layout places it.

Options considered:
- Add `.clipped()` after the frame in each layout (rejected): fixes `Television`, not `Pad`, whose copy shares the oversized stack, and every new layout has to remember it.
- `GeometryReader` around the image (rejected): more code for what the overlay gives.
- A color with the picture in an overlay, clipped (chosen).

The banner, the title page backdrop, poster tiles, Continue watching cards and episode pictures all use it.

### Testing it

A unit test renders `FilledArt` with a tall poster and a wide backdrop in a 300 by 100 frame between two white bands and checks the bands stay white. Previews show each banner layout with a tall striped poster and ground color around it, so the CI preview PNGs show any overflow. `PreviewArt` draws the stripes in code and hands them out through a poster loader, so the previews stay deterministic.

## Platforms

iPhone, iPad, Mac and Apple TV share the view.

## Boards

No board changes. `TV-Movies`, `iPad-Movies` and `iPhone-Movies` already draw the art inside the banner; this change makes the app match them.
