# Design

## Context

`ShelfBannerHost` builds the banner's state from `ShelfModel.details`, filled by the Xtream info call (`get_vod_info`, `get_series_info`) for the shown title and the next one. The art address was `details?.backdropURL ?? title.posterURL`, so it started as the poster and changed to the backdrop when the call answered. `ShelfBanner.Art` set its image to nil each time the address changed, then loaded the new one. Paging swapped everything at once, with no animation.

`fix-banner-art-clip` (merged) keeps any picture inside the banner. This change is about what picture shows and how the banner moves.

## Decisions

### What the user sees when the banner moves

The copy and the picture fade across together in 0.6 seconds (`ShelfBanner.crossfade`, ease in and out). The picture of the old title stays until the new picture has loaded, then fades across. Without a loaded picture the banner keeps showing the last one rather than the placeholder.

Options considered:
- Slide the banner sideways, like a pager (rejected): Netflix and the TV app fade their heroes, a slide under Reduce Motion has to become a fade anyway, and a sliding full-bleed picture on Apple TV is a lot of movement behind the tab bar.
- Fade (chosen). Reduce Motion already stops the banner moving by itself, and a fade is what Apple's guidance asks motion to become with Reduce Motion on, so the fade stays when the user pages by hand.

The copy fades by `.animation(_:value:)` on the copy column, keyed on the banner's text. That leaves the buttons' identity alone, so focus on Apple TV stays on Play or More info while the title changes. The picture fades by giving each picture its own identity (`.id(art)`) and an opacity transition.

### Waiting for the backdrop

`BannerArt.choose` in AntennaCore returns the backdrop once the info call has answered with one, the poster once the call has answered without one or the banner has waited `BannerArt.patience` (1.5 seconds), and nil before that. Nil tells `ShelfBanner.Art` to keep the picture it has. `ShelfModel.answered` records each title whose call has answered or failed. The host starts the 1.5 second timer when a title shows.

1.5 seconds: an Xtream panel answers an info call in well under a second when it is healthy. A slow panel should not hold the first title on the placeholder for long.

The next title's info call already ran while the current title showed. The host now also loads the next title's picture into the poster cache, so the fade starts as soon as the page turns.

### A title with only a poster

A 2:3 poster cut to a 3:1 banner shows a strip across the poster's middle, often a face cut at the eyes. On a banner wider than 1.2 times its height (iPad, Mac, Apple TV) the poster shows whole at the right, 70% of the banner's height, with a rounded corner and a shadow, over the same poster blurred to fill the banner and dimmed with the ground color at 35%. The copy and its scrim stay at the left, where the boards put them. The iPhone banner is 390 by 520, close to the poster's shape, so the poster fills it as before.

The width test is in `ShelfBanner.Picture` from the banner's size, not a parameter, so no layout passes a flag.

Options considered:
- Fill with the poster (rejected): the cut-off strip described above.
- Poster at the right over the placeholder color (rejected): a flat block of color across a 1920 point banner looks unfinished.
- Poster over a blurred copy of itself (chosen): what the TV app and Plex do for art without a backdrop.

### Provider load

Unchanged. The banner asks the info call for the shown title and the next one, once each per session, as before. The extra work is one poster or backdrop download for the next title, which the user would load a few seconds later anyway.

## Platforms

iPhone, iPad, Mac and Apple TV share the banner. Only the poster-only arrangement differs, by the banner's shape.

## Boards

- `TV-Movies-Poster-Only` (new): the Apple TV banner for a title with only a poster.
- `iPad-Movies-Poster-Only` (new): the same on the iPad and Mac card.
- `TV-Movies`, `iPad-Movies` and `iPhone-Movies` stand for titles with a backdrop. The crossfade is motion and has no board; this file describes it.

Design-system requirements followed: `design-system/one-accent-color` (no new color), `design-system/text-meets-contrast-minimums` (the copy keeps its 0.72 scrim over the blurred poster).

## Next step: a preview of the focused poster on Apple TV

The TV app shows the focused title's backdrop and plot at the top of the screen as focus moves along a row. Antenna could do it with the info call it already makes, asked after focus rests on a poster for about 0.8 seconds and kept per title, so fast scrolling asks nothing. It needs its own board (where the preview sits once the banner has scrolled away, and how the rows move down to make room), so it is left for its own change.
