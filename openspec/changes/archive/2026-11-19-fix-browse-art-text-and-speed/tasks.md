# Tasks

## 1. Pictures, the full text and the banner (one PR)

- [x] 1.1 `ArtFit.choose` in AntennaCore and `ArtFitTests`
- [x] 1.2 `FittedArt` for the banner and the title page backdrop; `FittedArtTests` measure a square in a tall and a wide picture
- [x] 1.3 `TitleAboutText` in AntennaCore from a title's metadata and from an episode, with tests
- [x] 1.4 `TitleAbout` view: a full-screen cover on Apple TV that the remote scrolls, a sheet elsewhere; More opens it on Apple TV, and the expanded page shows Cast and Director in full elsewhere
- [x] 1.5 Description in an episode row's menu, through `EpisodesContext.Actions.describe`
- [x] 1.6 `BannerPager.rotates(hold:)`; on Apple TV each focus move restarts the wait; tests
- [x] 1.7 Boards `TV-Title-About` and `iPhone-Title-About`; notes on `TV-Title`, `TV-Series`, `TV-Movies`, `TV-Movies-Poster-Only`, `iPad-Movies-Poster-Only`
- [x] 1.8 Previews for `FittedArt`, `TitleAbout` on each platform; tvOS UI test opens More and closes it with Menu

## 2. Speed (one PR)

- [x] 2.1 `ShelfTitle.newestFirst` sorts dates with indices; `ShelfIndex` and its `@concurrent` build
- [x] 2.2 `ShelfModel` swaps in the index off the main actor with the sources' new states; `settled()` waits for it
- [x] 2.3 Lookup forms of `ContinueWatching.items` and `RecentlyWatched.list`; `ShelfActivity` uses them and keeps positions by key
- [x] 2.4 Grids read sorted lists kept by `ShelfModel` until the index changes
- [x] 2.5 `PosterCache` decodes off its actor; signposts `shelf load`, `shelf index`, `poster`
- [x] 2.6 `PlaylistRetryGate` for missing playlist series
- [x] 2.7 `ShelfBrowsingPerformanceTests` on 50 000 movies and 10 000 series

## 3. Verify

- [x] 3.1 Each requirement has a test citing `<capability>/<requirement-slug>`
- [x] 3.2 `/opsx:verify` passes
