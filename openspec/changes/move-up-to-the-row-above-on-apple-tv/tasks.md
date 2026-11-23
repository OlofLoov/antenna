## 1. Place the row above at once

- [ ] 1.1 Report each row's top on screen next to its height in `ShelfRowReport`
- [ ] 1.2 Add `ShelfRowPlacement` with `wait(top:)` and `anchor(rowHeight:)`, and use them in `ShelfTVScreen`
- [ ] 1.3 Unit tests in `ShelfRowPlacementTests`
- [ ] 1.4 UI tests in `ShelfRowsUpTVUITests` that move down and up through the rows of Series and Movies, and press up twice quickly

## 2. Verify

- [ ] 2.1 Each changed scenario has a test citing `movies-and-series-browsing/preview-of-the-focused-title-on-apple-tv`
- [ ] 2.2 `/opsx:verify` passes
