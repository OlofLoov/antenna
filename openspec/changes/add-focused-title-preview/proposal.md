# Proposal

## Why

From the owner, after the banner work: "when browsing series or movies it would be nice if it was more like main stream services". `smooth-the-movies-banner` named the next step: the preview Apple's TV app shows at the top of the screen for the poster the highlight rests on.

> As a living-room viewer browsing Movies on Apple TV, I want to see what a poster is about when I stop on it, without opening its page and pressing Menu to come back.

Today a poster in a row shows its picture and nothing else. To read a plot the viewer clicks into the title page and backs out again. The provider's info call already gives the backdrop, year, length, age rating and plot, and the banner already asks for it.

After this change, when the highlight rests on a poster in a Movies or Series row for 0.8 seconds, the top of the screen shows that title's backdrop, name, facts and plot. Moving quickly along a row asks the provider nothing.

## What Changes

- On Apple TV, focus in a Movies or Series row turns the top of the screen into a preview of the focused title: backdrop, eyebrow, name, facts and up to three lines of plot. The focused row sits just under it.
- The preview changes 0.8 seconds after the highlight stops on a poster, with the banner's 0.6-second fade. Posters passed on the way are not asked about.
- The provider's info call is made once per title per session, only after a rest, one at a time. The answer is kept, so the banner, the preview and the title page share it.
- A title with only a poster shows the banner's poster-only arrangement. While the info call is out, the name and eyebrow show at once and the plot fades in when it answers.
- Menu from a row scrolls back to the banner and puts the highlight on the tab bar, as Menu does today. Back from a title page lands on the same poster with its preview already showing.
- VoiceOver reads the focused poster as today, with the plot as its hint once it is known.

Out of scope:
- iPad and Mac hover. design.md says why.
- The poster grid (See all, a genre, My list, All movies) and Search results. They keep the grid without a preview.
- Anything from TMDB (`add-title-metadata`).
- Trailers playing in the preview.

## Capabilities

### New Capabilities

None.

### Modified Capabilities
- `movies-and-series-browsing`: a new requirement for the focused title's preview on Apple TV, and one for asking the provider once per title.

## Impact

- Platforms: Apple TV only. iPhone, iPad and Mac are unchanged.
- AntennaCore: `PreviewSchedule`, which decides from focus events and times which title the preview shows and which title to ask about next.
- Apps: `ShelfTVScreen` (the preview layer and the row position), `ShelfModel` (keeps answers per title, one preview call at a time), `ShelfBannerHost` (pauses while the preview shows), a new `ShelfPreview.Television` component.
- Provider load: at most one info call per title per session, and only for titles the viewer stopped on. Today the banner asks for its four titles and each title page asks again; after this change the title page reuses a kept answer.
- Boards: new `TV-Movies-Preview`, `TV-Movies-Preview-Loading`, `TV-Movies-Preview-Poster-Only`.
- Depends on the archived `smooth-the-movies-banner` (the crossfade, `BannerArt`, the poster-only picture) and `add-control-hints` (the Movies rows' legend stays bottom right, under the preview).
- Works alongside `add-banner-rating-and-trailer`: if that lands first, the preview's facts line carries the provider rating too.
