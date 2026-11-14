# Tasks

## 1. Proposal and boards

- [x] 1.1 Proposal, delta specs, design and tasks; `openspec validate add-banner-rating-and-trailer --strict`
- [x] 1.2 Boards `TV-Movies-Trailer`, `iPad-Movies-Trailer`, `iPhone-Movies-Trailer`

## 2. Ratings in AntennaCore

- [ ] 2.1 Xtream movie rows, series rows and info bodies read `rating`, else `rating_5based` doubled, dropping values above their scale; fixture tests citing `xtream-vod-client/ratings-on-a-ten-point-scale`
- [ ] 2.2 `ShelfDetails` gains `rating` and `trailerURL`; `BannerText.facts` adds `TitleMetadata.rating(details?.rating ?? title.rating)`; `TitleMetadata.spokenRating(_:)`; tests citing `movies-and-series-browsing/rating-and-trailer-on-the-banner`

## 3. The banner

- [ ] 3.1 `ShelfActions.trailer(_:of:)` with the rule from `TitleScreen.trailer(_:)`, and `TitleScreen` using it
- [ ] 3.2 `BannerContext.Actions.trailer`, `ShelfBanner.TrailerButton` (text on Apple TV, iPad and Mac, glyph on iPhone), placed between More info and My list in `Phone`, `Pad` and `ShelfTVBannerButtons`
- [ ] 3.3 The rating fact's spoken label in `ShelfBanner.Facts`
- [ ] 3.4 Focus back on Trailer after a trailer closes on Apple TV
- [ ] 3.5 Previews with a rating and a trailer on each platform; a UI-testing banner title with a playable trailer link
- [ ] 3.6 `ShelfUITests`, `ShelfRegularUITests` and `ShelfTVUITests`: the rating shows, Trailer opens the link or plays, and paging from My list still works

## 4. Verify

- [ ] 4.1 Each requirement has a test citing `<capability>/<requirement-slug>`
- [ ] 4.2 The touched UI test classes pass on local iPhone, iPad and Apple TV simulators
- [ ] 4.3 `/opsx:verify` passes
