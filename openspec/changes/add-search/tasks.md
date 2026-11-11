# Tasks

## 1. Index and matching in the core package

- [x] 1.1 Build the search index and the token matcher with case and accent folding, and verify with a core test citing `search/find-things-the-way-you-type-them`
- [x] 1.2 Add number-prefix matching with leading zeros stripped, and verify with a core test citing `search/find-a-channel-by-its-number`
- [ ] 1.3 Add ranking bands, section order, counts and highlight ranges, and verify with core and UI tests citing `search/results-grouped-best-first`
  - Open: the core rules and their tests are in. The UI tests come with the screens in group 2.
- [x] 1.4 Add the seven-day horizon, on-air state and catch-up marks at query time, and verify with a core test citing `search/seven-days-of-guide`
- [ ] 1.5 Add the 500-row and four-programme caps, and verify with core and UI tests citing `search/very-long-result-lists`
  - Open: the caps and their core tests are in. The UI tests come with the screens in group 2.
- [x] 1.6 Check the index and query budgets in a debug `swift test`

## 2. Search screens

- [ ] 2.1 Build the Apple TV Search tab on the system search screen, the iPad and Mac Search section, and the iPhone Search tab, with a 300 ms debounce
- [ ] 2.2 Add the kind chips with counts and grayed-out empty chips, and verify with a UI test citing `search/narrow-to-one-kind`
- [ ] 2.3 Add clear, and verify with a UI test citing `search/clear-the-field`
- [ ] 2.4 Show no-results and still-loading states, and verify with a UI test citing `search/nothing-found`
- [ ] 2.5 Add Command-F, arrows, Return and Escape, and verify with a UI test citing `search/search-with-a-keyboard`

## 3. Picking results

- [ ] 3.1 Play a picked channel or title, switching to All channels when needed and keeping the query, and verify with a UI test citing `search/pick-a-channel-or-title-to-watch`
- [ ] 3.2 Open the guide at a later programme on Apple TV and show the "Later" line in Live elsewhere, and verify with a UI test citing `search/pick-a-programme`

## 4. Recent searches

- [ ] 4.1 Store recents per device through an injected store, ten newest first with case merged, and verify with integration and UI tests citing `search/recent-searches`

## 5. Verify

- [ ] 5.1 Each requirement has a test citing `search/<requirement-slug>`
- [ ] 5.2 `/opsx:verify` passes
