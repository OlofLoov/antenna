## 1. Banner drag

- [x] 1.1 `BannerTouch` in AntennaCore holds the banner's touch state; only `.restartsOnInput` counts inputs, with a core test
- [x] 1.2 `ShelfBannerHost` writes the touch state only when it changes
- [x] 1.3 The iPhone and iPad banner swipe reports through a `GestureState`, once on touch down and once on lift or cancel, with an iPhone UI test that a scroll starting on the banner lets it move on again

## 2. Poster loads

- [x] 2.1 `PosterCache` lets a cancelled caller return at once and cancels the load when no caller waits, with a test
- [x] 2.2 `ShelfSync` sets one poster loader and one logo loader for the app's life

## 3. Verify

- [x] 3.1 Each scenario this change adds has a test citing `movies-and-series-browsing/browsing-stays-responsive`
- [x] 3.2 A before and after run of fast browsing on an iPhone simulator with 20 000 movies, 20 000 series and 50 000 channels is recorded in design.md
- [x] 3.3 The touched UI test classes pass on the iPhone simulator
- [x] 3.4 /opsx:verify passes
