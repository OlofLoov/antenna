## 1. Measure

- [x] 1.1 Add the `large` shelf script (`UITestingShelfLarge`), posters and backdrops from `-ui-testing-poster-host`, Office answering 5 seconds after Cabin
- [x] 1.2 Add the redraw counts and the frame-gap counter behind `shelf.debug.*`, Debug builds only
- [x] 1.3 Add `ShelfLargeTVUITests` with the hitch benchmarks behind `TEST_RUNNER_ANTENNA_BENCHMARKS=1` and record the numbers before the fix in design.md

## 2. Stop redrawing on every move

- [x] 2.1 Give `ShelfActions` an identity so two made for one section compare equal, and make `ShelfRowsContent` equatable
- [x] 2.2 Move the focused row and title reads, the row placement and the preview's rest into `ShelfTVFocusFollower`
- [x] 2.3 Wrap the Apple TV banner in an equatable `ShelfTVBanner`
- [x] 2.4 Replace the rows' mask with a layer of the ground color under the preview
- [x] 2.5 UI test `testMovingAcrossPostersRedrawsNoRow` and unit test `actionsCompareEqual`

## 3. Focus

- [x] 3.1 Remember the poster a title played from in `ShelfLibrary` and give it focus back when playback ends; keep the rows in place while the player is open
- [x] 3.2 Put the highlight on Play when it comes down from the tab bar onto the banner or the rows
- [x] 3.3 UI tests `testBackFromAMoviePlayedFromARowFocusesItsPoster` and `testDownFromTheBarAfterSeriesLandsOnPlay`, unit tests in `ShelfReturnFocusTests`

## 4. Verify

- [x] 4.1 Run the benchmarks after the fix and record the numbers in design.md
- [x] 4.2 Run `ShelfLargeTVUITests`, `ShelfRowsUpTVUITests`, `ShelfPreviewTVUITests`, `ShelfTVUITests`, `TitleTVUITests` and `ShellUITests` on a local tvOS simulator
- [x] 4.3 `/opsx:verify` passes
