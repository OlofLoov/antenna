## 1. Posters ahead of the highlight

- [x] 1.1 Add `PosterPrefetch` to AntennaCore: the titles to load ahead of a focused or visible index in a row, in the direction of travel, and the first posters of the rows below, with tests
- [x] 1.2 Add `PosterCache.prefetch`, which loads and decodes at the card's frame without a waiting caller and drops what scrolled away
- [x] 1.3 Prefetch from the rows on every platform: ahead of the highlight on Apple TV, ahead of the visible posters on iPhone, iPad and Mac
- [x] 1.4 Debug probes `shelf.debug.posterAsks` and `shelf.debug.posterMisses`: posters cards asked for, and those not yet in memory; `-ui-testing-no-prefetch` to compare
- [x] 1.5 Keep 400 MB of posters in memory on Apple TV
- [x] 1.6 Record the benchmarks with and without the prefetch in design.md

## 2. The expanded card

- [x] 2.1 Make each title's details readable per title in `ShelfModel`, so a card redraws only for its own answer
- [x] 2.2 Add `ShelfExpandedCard` in `Apps/Shared/Components/Shelf/` with previews for a backdrop, loading and poster only
- [x] 2.3 Grow the focused poster into the card on Apple TV; posters after it move aside, with no animation under Reduce Motion
- [x] 2.4 Remove `ShelfPreview` and the preview overlay; rest the focused row under the tab bar; keep the 0.8 s rest for asking and the focus return from a page or the player
- [x] 2.5 Move `ShelfPreviewTVUITests`, `ShelfRowsUpTVUITests` and `ShelfLargeTVUITests` to the card; add `testAFastSwipeExpandsEachPosterAndAsksOnlyTheLast`
- [x] 2.6 Update the Apple TV walk-through step for the rows to anchor on the card

## 3. Verify

- [x] 3.1 Run the benchmarks after the card and record them in design.md
- [x] 3.2 Every requirement this change modifies has a test citing `movies-and-series-browsing/<requirement-slug>`
- [x] 3.3 Run the touched tvOS UI test classes on a local simulator, and build iOS and tvOS
- [x] 3.4 `/opsx:verify` passes
