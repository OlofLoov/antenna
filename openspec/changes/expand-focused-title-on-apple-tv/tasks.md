## 1. Posters ahead of the highlight

- [x] 1.1 Add `PosterPrefetch` to AntennaCore: the next 3 posters in a row in the direction of travel, and the posters the row below shows first, with tests
- [x] 1.2 Add `PosterCache.prefetch`, which loads and decodes at the card's frame without a waiting caller and drops what scrolled away
- [x] 1.3 Prefetch from the rows on every platform: ahead of the highlight on Apple TV, ahead of the visible posters on iPhone, iPad and Mac
- [x] 1.4 Debug probes `shelf.debug.posterAsks` and `shelf.debug.posterMisses`: posters cards asked for, and those not yet in memory; `-ui-testing-no-prefetch` to compare
- [x] 1.5 Keep 50 MB of posters in memory on every platform, Apple TV included, and decode each at its card's resting size with no focus headroom
- [x] 1.6 Show a quiet placeholder in the poster's shape while it loads and fade the poster in over 0.2 s, with no fade for a poster in memory and none under Reduce Motion; draw it on `TV-Movies-Expanded-Loading`
- [x] 1.7 Let a card off screen drop its picture, so the cache holds the only decoded posters
- [x] 1.8 Test that a card whose poster is in memory draws it without waiting for a load, and one whose poster is not shows the placeholder (`PosterLoadingTests`)
- [x] 1.9 Record the benchmarks with and without the prefetch in design.md, at 50 MB
- [x] 1.10 Find why each walk down and up finds more posters not ready: a debug probe for where posters go (`shelf.debug.posterTrace`); the rows by the highlight load around its column; a row coming into view loads nothing along it for 0.5 s; a finished load is no longer wanted

## 2. The expanded card

- [x] 2.1 Make each title's details readable per title in `ShelfModel`, so a card redraws only for its own answer
- [x] 2.2 Add `ShelfExpandedCard` in `Apps/Shared/Components/Shelf/` with previews for a backdrop, loading and poster only
- [x] 2.3 Grow the focused poster into the card on Apple TV; posters after it move aside, with no animation under Reduce Motion
- [x] 2.4 Remove `ShelfPreview` and the preview overlay; rest the focused row under the tab bar; keep the 0.8 s rest for asking and the focus return from a page or the player
- [x] 2.5 Move `ShelfPreviewTVUITests`, `ShelfRowsUpTVUITests` and `ShelfLargeTVUITests` to the card; add `testAFastSwipeExpandsEachPosterAndAsksOnlyTheLast`
- [x] 2.6 Update the Apple TV walk-through step for the rows to anchor on the card
- [x] 2.7 Keep the highlight's column on a move up or down (`ShelfColumn`, `ShelfModel.focusRequests`), with `testDownAndUpTheRowsKeepsTheColumn`
- [x] 2.8 Steer a move between rows with each row's default focus, so it is one focus move, and keep the correction for the moves it misses
- [x] 2.9 Read the benchmark's probes outside the measured walk; measure each part of the card against main and record it in design.md
- [x] 2.10 Draw the card over the focused poster's fixed slot, outside its button, and move the posters after it by offsets (`ShelfCardRoom`, decision 7), with `ShelfCardRoomTests`
- [x] 2.11 Measure the card outside the row's layout against main and record it in design.md
- [ ] 2.12 Bring the walks along the posters and down and up within about 15% of main plus the cost of the extra rows
- [x] 2.13 Bisect the frames outside the card (the rows below, the loads ahead, the column keeping, the probes) and record them in design.md
- [x] 2.14 Write the column once the highlight rests along a row, and draw the card from the row over its stack with no `zIndex`

## 3. Verify

- [x] 3.1 Run the benchmarks after the card and record them in design.md
- [x] 3.2 Every requirement this change modifies has a test citing `movies-and-series-browsing/<requirement-slug>`
- [x] 3.3 Run the touched tvOS UI test classes on a local simulator, and build iOS and tvOS
- [x] 3.4 `/opsx:verify` passes
