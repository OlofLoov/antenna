# Design

## Context

The owner's sentence reads two ways, and both were checked.

1. A page or player opened over the Movies or Series section lets the section show through. Not the case: every layout sets the section's opacity to 0 while a page is open, `TitlePage.Phone`, `.Pad` and `.Television` draw `Palette.ground` behind themselves, and `ShelfPlayerView` puts `Color.black` under the picture.
2. A picture that does not fill the screen shows something other than black around it. This one is real. `PlayerSurfaceView` set `Palette.ground` (#0B0E13) as the background of its `AVPlayerLayer` on a Mac and of its view on iOS and tvOS. The surface fills the screen and both engines draw into it with `.resizeAspect`: Apple's player through the layer, the demuxer through its `AVSampleBufferDisplayLayer` sublayer, which has no background of its own, and the `FrameHold` layer, which has none either. The bars were the ground color on every platform and both paths. On an OLED TV that reads as gray-blue next to the black of the film's own bars.

A third reading fits "a movie that is not in full screen" too: a title page whose art does not fill the screen. `TitlePage.Backdrop` put the poster on `TitlePage.placeholder` (#22304A) when the details had no backdrop. Before PR #367 the details never loaded, so every page the owner opened looked like this.

## Decisions

### Black for every picture

`PlayerSurfaceView` is black on all platforms. It is the one surface for movies, episodes, trailers, live TV, multi-view tiles and the onboarding preview. Options considered:
- Black only for movies and episodes, with a color parameter (rejected): live channels in 4:3 have the same bars, and a second look for the same surface is a choice nobody asked for.
- Black everywhere (chosen). Before the first frame the area is black instead of ground; the spinner and status lines sit over it as before.

### Black behind a poster-only page

`TitlePage.Backdrop` uses black as the `FilledArt` background. That covers a page with no backdrop and the moment before a backdrop loads. `TitlePage.placeholder` stays for the banner and episode stills. The banner's blurred-poster framing was considered for the page and left out: the owner asked for black, and the page's gradients already fade the art into the ground color.

## Boards

- `TV-Title`, `TV-Title-Cast`, `TV-Title-Scores`, `iPad-Title`, `iPad-Title-Scores`, `iPhone-Title`, `iPhone-Title-Cast`, `iPhone-Title-Scores`: the art fallback fill is black, and the notes say so.
- `iPhone-Title-Player-Transport`, `iPad-Title-Player-Transport`, `TV-Title-Player-Transport`: the notes say the bars are pure black.

Follows `design-system/visual-changes-update-the-boards-in-the-same-change`.

## Platforms

All four. The surface and the title page are shared code.

## Tests

The bars are a layer color, so they are checked by a unit test on the surface's view (iOS) and by the preview PNGs for the title page. The real-device look on an OLED TV was not checked.
