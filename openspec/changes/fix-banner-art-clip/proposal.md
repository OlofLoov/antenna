# Proposal

## Why

> The owner, on Movies and Series: the banner title that changes by itself "is now just scrolling between them presented in an ugly way cause the picture being scrolled is outside the actual box".

A banner picture that is not the banner's shape draws outside the banner. On Apple TV a poster used as banner art reaches hundreds of points above and below the 640 pt banner, behind the rows, and moves with them as focus scrolls the screen. On iPad the picture also pushes the banner's copy up and out of the card.

## What Changes

- Banner art fills the banner and is cut to it on iPhone, iPad, Mac and Apple TV, whatever the picture's shape, while the banner pages by hand or by itself.
- The same holds for the title page backdrop, posters, Continue watching cards and episode pictures, which drew the same way.

Out of scope:
- How the banner moves between titles. `smooth-the-movies-banner` adds the crossfade.

## Capabilities

### New Capabilities

None.

### Modified Capabilities
- `movies-and-series-browsing`: "New titles up front" says the art stays inside the banner.

## Impact

- Platforms: iOS (iPhone, iPad), Mac, tvOS.
- Code: one artwork view in `Apps/Shared/Components/Poster/` used by the banner, the title page, poster tiles, Continue watching cards and episode pictures.
- No board changes, since the boards already draw the art inside the banner.
