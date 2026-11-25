# Proposal

## Why

> The owner, testing on iPhone: "when clicking on something that is not in the previously seen list I would expect to come to the info page of the series or movie rather than actually starting it."

Today a movie poster starts the movie and a series poster opens the series' page. A viewer browsing Recently added or a genre row taps a movie to find out what it is, and it starts playing. The only way to a movie's page is More info on the banner or in the poster's menu, a long press.

After this change, selecting any poster opens the title's page, movie or series, on iPhone, iPad, Mac and Apple TV. The page has Play, the description, the cast and My list, so one more tap starts the movie. Titles the viewer already watched keep playing straight away: Continue watching resumes, and a movie in Recently watched plays again.

## What Changes

- A movie poster in a row, a grid, My list, search results or a person's page opens the movie's page, as a series poster already does.
- Continue watching still plays straight away, a movie from where it stopped and a series from its next episode.
- A movie in Recently watched still plays straight away; a series there still opens its page.
- The poster menu drops More info where the poster itself opens the page. It keeps My list everywhere, and keeps More info on Continue watching cards and on movies in Recently watched, where a tap plays.
- On Apple TV the Movies rows legend reads Click "Open" and hold "My list", as Series does.
- The banner keeps Play and More info.

Out of scope:
- The title page itself, its buttons and what Play does there.
- Which titles Continue watching and Recently watched list.
- The person page, which already opens a title's page from a poster.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `movies-and-series-browsing`: a new requirement, "A poster opens its page"; "Resume where you left off" and "Play a series from the next episode" name the places that still play.
- `title-detail-and-episode-picker`: "Open a movie's page" opens from a poster too; "Back to where you were" names Continue watching and Recently watched as the posters that play.
- `search`: "Pick a channel or title to watch" opens a movie's page; "Results grouped, best first" drops More info from a poster's menu.
- `control-hints`: "Each screen lists its own actions" gives Movies the Series legend.

## Impact

- Platforms: iPhone, iPad, Mac and Apple TV.
- Code: `ShelfActions.select` and the poster menus in `Apps/Shared/Views/Shelf/ShelfContent.swift`, the three search pick handlers (`RootView`, `LiveRegularView`, `SearchTVScreen`), the search result menu, and the Movies rows hints in AntennaCore.
- Tests: UI tests and screenshot walks that tap a movie poster to start playback go through the page's Play.
- Boards: the notes on `iPhone-Search`, `iPhone-Search-People`, `iPad-Search`, `iPad-Search-GuideLoading` and `TV-Search` that list More info in a poster's menu.
- Depends on `title-detail-and-episode-picker` and `movies-and-series-browsing` as they are. Blocked on nothing.
