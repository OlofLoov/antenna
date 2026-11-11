# Tasks

## 1. Section entry

- [x] 1.1 Show Movies and Series for any Xtream source on every platform, with the iPhone switch, and update the tvOS tab bar, and verify with UI tests citing `movies-and-series-browsing/movies-and-series-appear-when-your-provider-has-them` and `tvos-shell/the-tabs-in-order`

## 2. Banner and rows

- [x] 2.1 Pick the four newest titles in the core package and build the banner with rotation, pausing, paging and Reduce Motion, and verify with core and UI tests citing `movies-and-series-browsing/new-titles-up-front`
- [x] 2.2 Order Recently added and category rows with merging by category name in the core package, and verify with a core test citing `movies-and-series-browsing/rows-in-a-predictable-order`
- [x] 2.3 Add the poster cache keyed on a URL hash with the name tile fallback, and check the 50 MB and 500 MB limits
- [ ] 2.4 Build the genre, My list, All and See all grids with sorting on iPad and Mac and a separate screen on Apple TV, and verify with a UI test citing `movies-and-series-browsing/browse-a-genre-or-sort-the-lot`
- [ ] 2.5 Check the two-second budget with 20 000 items in 400 categories on Apple TV 4K and iPhone 15

## 3. My list and Continue watching

- [ ] 3.1 Add and remove My list entries from the banner and the poster menu, and verify with integration and UI tests citing `movies-and-series-browsing/keep-a-list-for-later`
- [ ] 3.2 Build Continue watching from saved positions with the 2% and 95% rules and Next episode, and verify with core and integration tests citing `movies-and-series-browsing/continue-watching`

## 4. Playing

- [ ] 4.1 Seek to the saved position before the first frame, and verify with an integration test citing `movies-and-series-browsing/resume-where-you-left-off`
- [ ] 4.2 Load a series' episodes and start the first unfinished one, with the no-episodes and failed states, and verify with core and UI tests citing `movies-and-series-browsing/play-a-series-from-the-next-episode`
- [ ] 4.3 Save the position every 30 seconds and on pause, stop, background and end, and verify with an integration test citing `movies-and-series-browsing/your-place-is-saved-as-you-watch`

## 5. Series, failures and search

- [ ] 5.1 Apply the section to series with last-changed order and season counts, and verify with core and UI tests citing `movies-and-series-browsing/series-work-the-same-way`
- [ ] 5.2 Show the failed-source banner, "Could not load movies" with Retry, "Nothing here yet" and waiting sources, and verify with a UI test citing `movies-and-series-browsing/when-sources-fail`
- [ ] 5.3 Open Search set to movies or series from the section on iPhone, iPad and Mac, and verify with a UI test citing `movies-and-series-browsing/search-from-the-section`

## 6. Verify

- [ ] 6.1 Each requirement has a test citing `movies-and-series-browsing/<requirement-slug>`
- [ ] 6.2 `/opsx:verify` passes
