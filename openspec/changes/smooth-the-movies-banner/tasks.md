# Tasks

## 1. Boards

- [ ] 1.1 `TV-Movies-Poster-Only` and `iPad-Movies-Poster-Only`

## 2. Core

- [ ] 2.1 `BannerArt.choose`: the backdrop, the poster after the info call answers or 1.5 seconds pass, nil before that

## 3. App

- [ ] 3.1 `ShelfModel.answered` records banner titles whose info call answered or failed
- [ ] 3.2 `ShelfBannerHost` waits for the backdrop, pages with the crossfade and loads the next title's picture
- [ ] 3.3 `ShelfBanner.Art` keeps its picture until the next one loads, then fades across; the copy fades with it
- [ ] 3.4 A poster on a wide banner shows whole at the right over a blurred copy of itself
- [ ] 3.5 Previews of the Apple TV banner with a poster and with a backdrop

## 4. Verify

- [ ] 4.1 Each requirement has a test citing `<capability>/<requirement-slug>`
- [ ] 4.2 `ShelfUITests` and `ShelfTVUITests` pass on local simulators
- [ ] 4.3 `/opsx:verify` passes
