# Large libraries stay quick

## Why

A movie and series watcher with a big provider, 100 000 movies and 30 000
series whose list rows carry the cast, should be able to keep Search or a
person's page open, sort All movies by title on an iPad or Mac, watch a
two-hour movie and browse for an evening on an Apple TV HD without the
screen pausing or the app running out of memory. A review of those paths
on 2026-11-21 measured where the time and memory go:

- The people index took 6.2 s and 205 MB per build and was built again on
  every info answer while Search or a person's page showed, with builds
  overlapping.
- Sorting All by Title or Year took 1.2 to 1.5 s on the main thread.
- Each progress save every 30 s made a new synced record and deleted the
  old one, and read every progress, list and search record two to four
  times on the main thread.
- Apple TV Search joined every title into one list on each redraw and
  handed unchanged results to the screen every 5 s.
- Once the poster folder was full, every new poster listed and sorted the
  whole folder. Banner, preview and title page backdrops decoded at full
  size into the cache the posters share.
- Every poster on an Apple TV screen redrew on each info answer and each
  progress read.
- Episode lists stayed for every series asked about, and a Continue
  watching card asked for its series' details a second time.

## What Changes

- The people index reads the list rows once per change of titles, points
  at titles by position, and puts the info answers' names on top in a
  separate, small step. A build for titles that changed is cancelled.
- Title and Year orders are built away from the main thread from sort keys
  computed once per title, and a grid shows when its list is ready.
- A progress save updates the title's entry in place and deletes only
  other copies. The screens read again once per burst of saves, and only
  for saves of progress, My list or recent searches.
- Search keeps one list of movies and series per change of titles, skips
  results that did not change, and searches people away from the main
  thread.
- The poster folder trims to 80% of its limit. Backdrops decode at the
  size of the window. Each Apple TV poster reads only its own description
  and progress.
- Episode lists past the 100 kept info answers are dropped, except for
  series with saved progress, and a Continue watching card asks through
  the same once-per-title path as the banner and the page.

Out of scope:
- A copy of the catalogue on disk so launch skips the download.
- Per-window copies of the library on Mac and iPad, Keychain reads and
  the URL cache, which another change handles.
- Live TV and the guide.

## Capabilities

### Modified Capabilities

- `movies-and-series-browsing`: Browsing stays responsive gains scenarios
  for 100 000 movies and 30 000 series with cast, a person's page, sorting,
  the banner's picture and a long Apple TV session. Title details are
  asked once per title covers Continue watching cards.
- `watch-progress-sync`: Progress is saved and read back says a save
  updates the one entry.
- `search`: a new requirement, Typing keeps up with a large library.

## Impact

- AntennaCore: `PeopleIndex`, `PersonName`, `ShelfIndex`, `ShelfGrid`,
  `WatchProgress`.
- Apps: `ShelfLibrary`, `ShelfModel`, `ShelfActivity`, `ActivityStore`,
  `SearchModel`, the Search screens, `PosterCache`, the banner, preview and
  title page art, `ShelfPreviewFocus`, `ShelfContent`.
- No new kind of synced record and no schema change. No new dependency.
