# Tasks

## 1. Proposal

- [x] 1.1 Proposal, delta specs, design and tasks
- [x] 1.2 Board notes on `iPhone-Search`, `iPhone-Search-People`, `iPad-Search`, `iPad-Search-GuideLoading`, `TV-Search` and `TV-Hints-Movies`

## 2. Posters open the page

- [x] 2.1 `ShelfActions.plays(_:in:)`, `select` opens unless it plays, `resume` for Continue watching, `recentlyWatched` row id
- [x] 2.2 `ShelfPoster` shows More info only where the poster plays; `ShelfContinueCard` calls `resume`
- [x] 2.3 The three `SearchPicks.title` closures open the page; `SearchTitleResult` drops More info
- [x] 2.4 `ControlHintScreen.titleRows(.movie)` reads Click "Open" and hold "My list"; the String Catalog loses "More info and My list"
- [x] 2.5 Doc comments on `TitleRoute.Origin`, `ShelfPoster`, `MoreInfoMenuItem` and the search picks say what the code does now
- [x] 2.6 Unit tests in `ShelfReturnFocusTests` and `ControlHintsTests`
- [x] 2.7 UI tests and walks on iPhone, iPad, Mac and Apple TV that tapped a movie poster to play go through the page or Continue watching; run the touched classes on a local simulator

## 3. Verify

- [x] 3.1 Each requirement has a test citing `<capability>/<requirement-slug>`
- [x] 3.2 `/opsx:verify` passes
