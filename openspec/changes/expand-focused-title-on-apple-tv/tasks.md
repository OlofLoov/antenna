## 1. Posters ahead of the highlight

- [ ] 1.1 Add `PosterPrefetch` to AntennaCore: the titles to load ahead of a focused or visible index in a row, in the direction of travel, and the first posters of the rows below, with tests
- [ ] 1.2 Add `PosterCache.prefetch`, which loads and decodes at the card's frame without a waiting caller and drops what scrolled away
- [ ] 1.3 Prefetch from the rows on every platform: ahead of the highlight on Apple TV, ahead of the visible posters on iPhone, iPad and Mac
- [ ] 1.4 Debug probe `shelf.debug.tiles`: how many times the highlight landed on a poster still showing its name tile; UI test `testMovingAlongARowLandsOnPictures`
- [ ] 1.5 Record the benchmarks after the prefetch in design.md

## 2. The expanded card

- [ ] 2.1 Make each title's details readable per title in `ShelfModel`, so a card redraws only for its own answer
- [ ] 2.2 Add `ShelfExpandedCard` in `Apps/Shared/Components/Shelf/` with previews for a backdrop, loading and poster only
- [ ] 2.3 Grow the focused poster into the card on Apple TV; posters after it move aside, with no animation under Reduce Motion
- [ ] 2.4 Remove `ShelfPreview` and the preview overlay; rest the focused row under the tab bar; keep the 0.8 s rest for asking and the focus return from a page or the player
- [ ] 2.5 Move `ShelfPreviewTVUITests`, `ShelfRowsUpTVUITests` and `ShelfLargeTVUITests` to the card; add `testAFastSwipeExpandsEachPosterAndAsksOnlyTheLast`
- [ ] 2.6 Update the Apple TV walk-through step for the rows to anchor on the card

## 3. Verify

- [ ] 3.1 Run the benchmarks after the card and record them in design.md
- [ ] 3.2 Every requirement this change modifies has a test citing `movies-and-series-browsing/<requirement-slug>`
- [ ] 3.3 Run the touched tvOS UI test classes on a local simulator, and build iOS and tvOS
- [ ] 3.4 `/opsx:verify` passes
