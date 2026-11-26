## 1. The picture whole

- [x] 1.1 `TitleArtPlacement` in AntennaCore with `phoneArea` and `cardHeight`, and its unit tests
- [x] 1.2 `TitlePage.Backdrop` places the picture over its blurred copy by that rule
- [x] 1.3 iPhone: the 16:9 area under the status bar and the 24 point band; iPad and Mac: the card's height; Apple TV: margin 120
- [x] 1.4 Previews with a 16:9 picture and a poster on iPhone, iPad, Mac and Apple TV
- [x] 1.5 `-ui-testing-poster-backdrop` for screenshots

## 2. The page in one go

- [x] 2.1 `TitleReveal` in AntennaCore and its unit tests
- [x] 2.2 `TitlePage.Reveal` and `TitlePage.Veil` around each layout's content
- [x] 2.3 UI tests on iPhone and iPad for a series that loads behind the mark

## 3. Verify

- [x] 3.1 Each requirement this change touches has a test citing `title-detail-and-episode-picker/what-the-title-is-about` or `title-detail-and-episode-picker/the-page-shows-in-one-go`
- [x] 3.2 `/opsx:verify` passes
