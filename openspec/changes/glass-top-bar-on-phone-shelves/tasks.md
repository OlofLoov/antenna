# Tasks

## 1. Proposal and boards

- [x] 1.1 Proposal, design, delta specs for `movies-and-series-browsing` and `design-system`
- [x] 1.2 Boards `iPhone-Movies`, `iPhone-Movies-Grid` and `iPhone-Movies-Trailer` draw the glass bar and the inset banner card
- [x] 1.3 Boards `iPhone-Movies-Rows` and `iPhone-Movies-Discover` draw the same bar with rows scrolled under it

## 2. Bar and card

- [ ] 2.1 `ShelfTopBar` component: the name, the genre button slot and the profile slot in one 44 pt row, `<prefix>.bar`
- [ ] 2.2 `ShelfGenreButton` in the glass button style with `ShelfCategoryLabel`, no fill or stroke of its own
- [ ] 2.3 `ShelfCompactScreen` puts the bar in `safeAreaBar(edge: .top)`, stops ignoring the top safe area and drops the 420 pt pinned copy
- [ ] 2.4 `ShelfBanner.Phone` drops its `top` content and becomes a 480 pt card, inset 16 pt, clipped to the large corner
- [ ] 2.5 Delete `HeroTopScrim`, its preview and its tests; previews of the bar over a white and a dark picture
- [ ] 2.6 Unit test: the genre button is glass with no background, overlay, border or shadow
- [ ] 2.7 UI tests: the banner starts below the bar, the bar reads the open list, and the bar stays put when the rows scroll
- [ ] 2.8 Before and after screenshots on a local iPhone simulator with light and dark art; check a narrow iPad window

## 3. Verify

- [ ] 3.1 Each requirement has a test citing `<capability>/<requirement-slug>`
- [ ] 3.2 `/opsx:verify` passes
