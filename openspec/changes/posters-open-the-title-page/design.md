# Design

## Context

`ShelfPoster` calls `ShelfActions.select(_:in:)`, which plays a movie (`play(title, .poster(row:))`) and opens a series' page (`open(title, .poster(row:))`). Every poster in a row, a grid and My list is a `ShelfPoster`, Recently watched included. Continue watching uses `ShelfContinueCard`, which calls `play` itself. The poster's context menu has More info for a movie, the only way to a movie's page short of the banner.

Search picks a title through `SearchPicks.title`, built three times with the same switch: `CompactTabs.picks` in `RootView` (iPhone, narrow iPad), `searchPicks` in `LiveRegularView` (iPad, Mac) and `SearchPicks.shell` in `SearchTVScreen` (Apple TV). `SearchTitleResult` has its own menu with More info on a movie.

The person page already opens a title's page from any poster through `library.push`, so it needs nothing.

## Decisions

### Which posters still play

Options considered:
- Every poster opens the page, Continue watching included (rejected): Continue watching is there to resume, and the brief keeps it playing.
- Every poster except Continue watching opens the page (rejected): the owner's words were "something that is not in the previously seen list". Recently watched is the list of things seen before, and a finished movie there is one the viewer picks to watch again.
- Every poster except Continue watching and a movie in Recently watched (chosen). A series in Recently watched keeps opening its page, as it does today, since Play there picks the episode.

`ShelfActions` gets `static let recentlyWatched = "recentlyWatched"`, the row id `ShelfRowsContent` already sets, and `static func plays(_ title: ShelfTitle, in row: String) -> Bool`, true only for a movie in that row. `select` plays when `plays` is true and opens the page otherwise. `ShelfRowsContent` uses the constant for the row's `shelfRow`, so the two cannot drift.

`ShelfContinueCard` calls a new `ShelfActions.resume(_:in:)`, which plays from `.poster(row:)`, so a unit test can pin what the card does without a view.

### The poster menu

`ShelfPoster` shows `MoreInfoMenuItem` only when `ShelfActions.plays` is true. My list stays on every poster. `ShelfContinueCard` keeps its menu as it is. `SearchTitleResult` drops More info, since a search result always opens the page. The `<prefix>.menu.info` identifier stays on the cards that keep the item.

### Search opens the page

The three `SearchPicks.title` closures become `library.openPage(title, from: .search, in: title.kind)` for both kinds. On Apple TV, `SearchTVScreen` already calls `cameBack()` when the page closes, which is the path a series has taken since search shipped, so the picked result gets focus back. The `onChange(of: playback.playing == nil)` handler stays for channels.

### Apple TV focus and the preview

A movie page opened from a poster goes through `ShelfLibrary.openPage(_:from: .poster(row:), in:)`, as a series page does today. `closePage` sets `returning` to the route's spot, and `ReturnFocus` on the poster takes focus back. `ShelfPreviewFocus` already shows the preview at once for a title whose details are cached, which the page has just fetched. Nothing in that path depends on the kind, so movies get the series behavior with no change to `ReturnFocus` or `ShelfLibrary`.

### The `playing(_:from:)` bookkeeping

`ShelfActions.section`'s `play` records `playedFrom` when the origin is a poster, so focus goes back to that poster once playback ends. After this change only Continue watching cards and movies in Recently watched reach `play` with a poster origin, and those are exactly the cards a viewer should land on when playback ends. A movie played from its page keeps `playedFrom` nil, because `openPage` clears it, and the viewer comes back to the page. The bookkeeping stays as it is.

### Apple TV hints

`ControlHintScreen.titleRows(.movie)` gets the Series list: Click "Open", hold "My list", Back "Tab bar". The two kinds stay separate screens, since the legend always shows on a move between Movies and Series. The legend describes the posters; a Continue watching card under it still plays, as on Series today. "More info and My list" leaves the AntennaCore catalog.

## Platforms

iPhone, iPad, Mac and Apple TV share `ShelfPoster`, `ShelfActions` and `SearchTitleResult`. The search handlers differ per shell and all three change.

## Boards

Followed: `iPhone-Movies`, `iPad-Movies`, `TV-Movies` (the rows), `iPhone-Title`, `iPad-Title`, `TV-Title` (the page a poster opens). Nothing on them is redrawn. Updated in this change: the notes on `iPhone-Search`, `iPhone-Search-People`, `iPad-Search`, `iPad-Search-GuideLoading` and `TV-Search` no longer list More info in a poster's menu, and `TV-Hints-Movies` reads Click "Open" and Hold "My list". The poster menu itself is a system context menu and is not drawn.

Design-system requirements followed: `movies-and-series-open-content-first`, `focus-moves-where-the-remote-points`, `accessibility-identifiers-follow-the-board`.

## Tests

- `ShelfReturnFocusTests` (Apps/Tests): a movie poster in a row opens the page and plays nothing; a series poster opens the page; a movie in Recently watched plays; `resume` plays from Continue watching and gives the card focus back after; closing a movie page opened from a poster gives that poster focus back.
- `ControlHintsTests` (AntennaCore): Movies rows read Click "Open" and hold "My list".
- UI tests and walks that tap a movie poster to play it open the page and press Play there, or use Continue watching where the test is about resuming.
