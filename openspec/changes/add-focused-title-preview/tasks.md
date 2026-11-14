# Tasks

## 1. Proposal and boards

- [x] 1.1 Proposal, delta spec, design and tasks; `openspec validate add-focused-title-preview --strict`
- [x] 1.2 Boards `TV-Movies-Preview`, `TV-Movies-Preview-Loading`, `TV-Movies-Preview-Poster-Only`

## 2. Asking once

- [ ] 2.1 AntennaCore: `PreviewSchedule` with `rest`, focus events and the waiting title, tests citing `movies-and-series-browsing/preview-of-the-focused-title-on-apple-tv`
- [ ] 2.2 `ShelfModel.infos` (capped at 100), `loadDetails` filling it, `info(_:)` reading it, `refreshInfo(_:)` for Retry, and `preview(_:)` with one request in flight; app tests citing `movies-and-series-browsing/title-details-are-asked-once-per-title`
- [ ] 2.3 `shelf.debug.infoLoads` in the UI-testing shelf

## 3. The preview on Apple TV

- [ ] 3.1 `ShelfPreview.Television` and `PreviewContext`, with previews for a backdrop, loading and a poster only
- [ ] 3.2 `ShelfTVScreen`: the preview layer, the row anchor at y 616, the mask above it, no ground band while the preview shows
- [ ] 3.3 The rest task keyed on the focused title, the crossfade, and the banner's `paused`
- [ ] 3.4 Menu from a row and Back from a page, the plot as the focused poster's hint
- [ ] 3.5 `ShelfTVUITests`: rest shows the preview, a fast swipe asks nothing, up returns to the banner, Back restores the preview

## 4. Verify

- [ ] 4.1 Each requirement has a test citing `movies-and-series-browsing/<requirement-slug>`
- [ ] 4.2 The touched tvOS UI test classes pass on a local simulator
- [ ] 4.3 `/opsx:verify` passes
