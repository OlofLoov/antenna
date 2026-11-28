# Tasks

## 1. The window and the line

- [x] 1.1 `PosterPrefetch`: `along` 6, `rowsAhead` 2, `aroundHighlight` for 2 rows ahead of the last move and 1 behind, `Trail.highlight` for the direction
- [x] 1.2 `PosterCache`: its own `session` with 6 connections a host, at most `prefetchLimit` (5) loads ahead at once, the rest in `PosterLine` newest first, a card starts its poster out of the line, `prefetch(replacing:)` for the highlight, `memoryLimit` 80 MB
- [x] 1.3 `PrefetchAroundHighlight` asks through `retarget` with the new window
- [x] 1.4 Unit tests: the window and the direction in `PosterPrefetchTests`, the memory bound, the line and the replacing ask in `PosterCacheTests`, the limit in `PosterCacheLimitTests`
- [x] 1.5 `testHitchesMovingDeepDownTheRows` in `ShelfLargeTVUITests`, and the walks measured before and after against a host that answers in half a second (design.md, "Measuring")

## 2. Verify

- [x] 2.1 Each requirement has a test citing `<capability>/<requirement-slug>`
- [x] 2.2 `/opsx:verify` passes
