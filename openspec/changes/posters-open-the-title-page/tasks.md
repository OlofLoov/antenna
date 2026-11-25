# Tasks

## 1. Proposal

- [x] 1.1 Proposal, delta specs, design and tasks
- [x] 1.2 Board notes on `iPhone-Search`, `iPhone-Search-People`, `iPad-Search`, `iPad-Search-GuideLoading`, `TV-Search` and `TV-Hints-Movies`

## 2. Posters open the page

- [ ] 2.1 `ShelfActions.plays(_:in:)`, `select` opens unless it plays, `resume` for Continue watching, `recentlyWatched` row id
- [ ] 2.2 `ShelfPoster` shows More info only where the poster plays; `ShelfContinueCard` calls `resume`
- [ ] 2.3 The three `SearchPicks.title` closures open the page; `SearchTitleResult` drops More info
- [ ] 2.4 `ControlHintScreen.titleRows(.movie)` reads Click "Open" and hold "My list"; the String Catalog loses "More info and My list"
- [ ] 2.5 Doc comments on `TitleRoute.Origin`, `ShelfPoster`, `MoreInfoMenuItem` and the search picks say what the code does now
- [ ] 2.6 Unit tests in `ShelfReturnFocusTests` and `ControlHintsTests`
- [ ] 2.7 UI tests and walks on iPhone, iPad, Mac and Apple TV that tapped a movie poster to play go through the page or Continue watching; run the touched classes on a local simulator

## 3. Verify

- [ ] 3.1 Each requirement has a test citing `<capability>/<requirement-slug>`
- [ ] 3.2 `/opsx:verify` passes
