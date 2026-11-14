# Proposal

## Why

From last night's report, the owner wants the Movies and Series banner to carry what the title page already shows: the provider's rating and the trailer.

> As a movie and series watcher, I want to see how a title rates and watch its trailer from the banner, without opening its page first.

The title page shows "★ 7.4" in its details line and offers Trailer when the provider sends a link (`title-detail-and-episode-picker/what-the-title-is-about`, `title-detail-and-episode-picker/trailer`). The banner asks the provider's info call for the same title but keeps only the year, length, age rating, plot and backdrop, so the rating and the trailer link are dropped on the way.

After this change the banner's facts line reads "2024 · 2 h 08 min · ★ 7.4", and a Trailer button sits next to More info whenever the title page would offer one.

## What Changes

- The banner's facts line gains the provider's rating, written as on the title page: a star and the number out of ten with one decimal. VoiceOver reads "rated 7.4 out of 10".
- The rating comes from the list row as soon as the banner shows, and from the info call once it answers.
- Xtream rows and info bodies that send only `rating_5based` get it doubled onto the ten-point scale. Series rows read their rating too. A rating above its scale is dropped.
- A Trailer button on the banner, between More info and My list, on iPhone, iPad, Mac and Apple TV. It follows the title page's rule: on iPhone, iPad and Mac it opens the link outside the app; on Apple TV it shows only for a link the app can play and plays it full screen, so a YouTube link gets no button there.
- On iPhone the button is a glyph only, so the row of buttons still fits 390 pt.

Out of scope:
- TMDB, IMDb or other scores on the banner (`add-title-metadata` puts them on the title page only).
- Opening YouTube trailers on Apple TV. design.md lists what that would take.
- Ratings on posters in rows.
- The focused-poster preview (`add-focused-title-preview`). Its facts line uses the same `BannerText`, so it gets the rating with no extra work.

## Capabilities

### New Capabilities

None.

### Modified Capabilities
- `movies-and-series-browsing`: a new requirement for the rating and Trailer on the banner.
- `xtream-vod-client`: a new requirement for reading ratings on a ten-point scale.

## Impact

- Platforms: iPhone, iPad, Mac and Apple TV.
- AntennaCore: `ShelfDetails` gains `rating` and `trailerURL`; `BannerText.facts` adds the rating through `TitleMetadata.rating`; the Xtream wire types read `rating_5based` and the series row rating.
- Apps: `ShelfBanner.TrailerButton`, `BannerContext.Actions.trailer`, `ShelfBannerHost` building the action as `TitleScreen` does, and the button in the three banner layouts.
- Provider load: unchanged. The banner already makes the info call that carries both fields.
- Boards: new `TV-Movies-Trailer`, `iPad-Movies-Trailer`, `iPhone-Movies-Trailer`.
- Depends on the archived `add-title-detail-and-episode-picker` (the trailer rule and `TrailerLink`) and `smooth-the-movies-banner`.
- Works alongside `add-title-metadata`: design.md says how the provider rating and the TMDB score share the screen.
