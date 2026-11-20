# Tasks

## 1. My list in words

- [x] 1.1 `ShelfBanner.MyListButton` and `TitlePage.MyListButton` read "Add to My list" or "Remove from My list", no glyph
- [x] 1.2 iPhone banner in two rows with the worded Trailer; drop `TrailerGlyphButton`
- [x] 1.3 iPhone title page: Play across the width, My list and Trailer under it; iPad banner buttons free of the copy's width; labels fixed to their width on iPad and Apple TV
- [x] 1.4 Boards for the banner and the title page on iPhone, iPad and Apple TV
- [x] 1.5 `TitleUITests.testMyListOnThePageAgreesWithTheBanner`, `ShelfUITests.testTheBannerShowsTheRatingAndTrailerOpensTheLink`, `ShelfTVUITests.testTheBannerAddsToMyList` and `TitleTVUITests.testSampleScoresTakeNoFocus` check the words

## 2. No outlines

- [x] 2.1 `FocusCard` turns the highlight hover effect on only while focused, in the card's shape
- [x] 2.2 The overlay's Watch, favorite and Add to multi-view use the system styles; drop `PanelButtonStyle`
- [x] 2.3 LIVE behind live takes the badge's surface fill; boards `iPhone-Player-Timeshift` and its RTL twin
- [x] 2.4 `scripts/check-rules.sh` fails on a stroke or border in a button's label
- [x] 2.5 `ShellUITests.testRowsAtRestHaveNoOutline`

## 3. Verify

- [x] 3.1 Each requirement has a test citing `<capability>/<requirement-slug>`
- [x] 3.2 `/opsx:verify` passes
