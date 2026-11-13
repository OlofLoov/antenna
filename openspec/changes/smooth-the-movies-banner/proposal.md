# Proposal

## Why

> The owner: "when browsing series or movies it would be nice if it was more like main stream services but perhaps we can't have info about the movie if we don't connect to an actual api describing them?"

> As a living-room viewer, I want the banner at the top of Movies to change titles the way Netflix or the TV app does, without the picture jumping or going blank.

The banner already shows the provider's plot, year, length, age rating and backdrop from the info call. What makes it feel cheap is how it gets there. On every page the picture drops to the placeholder color, then shows the title's poster blown up to fill the banner, then swaps to the backdrop once the info call answers. Titles without a backdrop keep a poster stretched across 1920 by 640 points, cut to a strip of its middle.

TMDB matching, Trending and person pages are planned in `add-title-metadata`, `add-discover-rows` and `add-browse-by-person`. This change uses only what the provider already sends.

## What Changes

- The banner fades from one title to the next: the picture and the words cross over in 0.6 seconds. The picture it shows stays until the next one has loaded, so the banner never drops to the placeholder between titles.
- The banner waits up to 1.5 seconds for a title's info call before it settles for the poster, so a title with a backdrop goes straight to it.
- The next title's info call and picture load while the current title shows.
- A title with only a poster shows it sharp at the right of a wide banner (iPad, Mac, Apple TV), over a blurred copy of itself filling the banner. The tall iPhone banner keeps the poster filling it.

Out of scope:
- A preview of the focused poster on Apple TV, the way the TV app shows a title's backdrop and plot as focus moves along a row. Listed as the next step in design.md.
- The title page. It already shows the backdrop, or the poster on the placeholder.
- Anything from TMDB.

## Capabilities

### New Capabilities

None.

### Modified Capabilities
- `movies-and-series-browsing`: "New titles up front" gains the crossfade, the wait for the backdrop and the poster-only banner.

## Impact

- Platforms: iPhone, iPad, Mac and Apple TV.
- AntennaCore: `BannerArt`, which picks the backdrop or the poster and says when to wait.
- Apps: `ShelfBanner.Art`, `ShelfBannerHost` and `ShelfModel` (which titles' info calls have answered).
- Provider load: unchanged. The banner already asked for the shown and the next title's info, once per title per session.
- Boards: new `TV-Movies-Poster-Only` and `iPad-Movies-Poster-Only`.
