# Tasks

## 1. Xtream client fields

- [x] 1.1 Decode cast, director, rating and the trailer link for movies and series, and verify decoder tests for a full body, a 0 rating, a YouTube id and a bad link
- [x] 1.2 Decode each episode's description and picture, and verify decoder tests with and without them

## 2. Rules in AntennaCore

- [x] 2.1 Add the details line and labels, and verify core tests for full and missing fields
- [x] 2.2 Add season grouping with Specials and Other, and verify core tests and the 5 000-episode benchmark
- [x] 2.3 Add the play-target rule and button labels, and verify core tests for in progress, after finished, wrapping, nothing started, all watched and no episodes

## 3. Opening the page

- [x] 3.1 Open a movie's page from More info on the banner and in the poster menu, with one details request, and verify UI tests
- [ ] 3.2 Open a series' page from posters, the banner and search, keep Continue watching playing straight away, and verify UI tests
  - Open: posters, the banner and Continue watching are done and tested. Search is built by change `add-search`, which has not started, so there is no search result to open a page from yet.
- [x] 3.3 Hide the Apple TV tab bar and clock on the page, and verify a UI test that swiping up does not reach the bar

## 4. Page content

- [x] 4.1 Show backdrop, details, badges, description with More, cast and director, leaving out missing fields, and verify UI tests
- [x] 4.2 Add the season picker and the episode list with progress, Watched and UP NEXT, and verify UI tests including keyboard and VoiceOver
- [x] 4.3 Add loading and error states with Retry, the waiting-login line and the empty and unreadable episode lines, and verify integration and UI tests
- [x] 4.4 Add Trailer on iPhone, iPad and Mac through an injected opener, and verify it is absent on Apple TV

## 5. Playing and My list

- [ ] 5.1 Add Play and Resume for a movie and the return to the page with progress updated, and verify integration and UI tests with a stand-in player
- [ ] 5.2 Play an episode, save progress as it plays and return with the episode in view, and verify integration and UI tests
- [ ] 5.3 Add My list on the page in agreement with the banner, and verify a test of fast repeated presses

## 6. Going back

- [ ] 6.1 Return to the section at the same scroll position with the starting poster focused or in view, and to Search with the query kept, and verify UI tests on every platform

## 7. Verify

- [ ] 7.1 Each requirement has a test citing `<capability>/<requirement-slug>`
- [ ] 7.2 `/opsx:verify` passes
