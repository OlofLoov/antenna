# Proposal

## Why

Xtream providers ship thousands of movies and series next to live TV. TiviMate shows them as a flat list, and its users call its movie section "not really very good". People know how Netflix and Disney+ present a catalogue, and Antenna has no movie screen at all.

User stories served:
- "As a movie and series watcher, I want to browse my provider's movies and series with posters and details, like a streaming app."
- "As a watcher, I want to resume a movie or episode where I left off, on any of my devices, and keep a list of things to watch later."

## What Changes

- Movies and Series sections whenever an Xtream source exists. On iPhone the Movies tab has a Movies | Series switch, and Series never gets its own tab.
- A banner at the top that cycles through the newest titles.
- Rows for Continue watching (movies and series together), My list, Recently added, and one row per provider category.
- Genres, which are the provider's categories, open a grid: from the sidebar on iPad and Mac, chips on iPhone, a row of chips on Apple TV. All movies and Continue watching's See all open the same grid.
- Sorting by title or year on iPad and Mac. Apple TV and iPhone always show newest first.
- Playing from the banner and from posters, resuming, and the next unseen episode for a series.
- Adding to and removing from My list, on the banner and from a poster's menu.
- Saving the position while a movie or episode plays.
- A search button that opens Search set to movies or series.
- More info shows on the banner but does nothing until change `add-title-detail-and-episode-picker`.
- A stand-in for missing posters, and states for loading, empty, failed and partly failed.
- On Apple TV, Movies and Series show in the tab bar for any Xtream source, before it has answered.

Out of scope:
- The title detail page, episode picker and series page.
- Movies from M3U playlists.
- Ratings or artwork from outside databases.
- Downloads.
- Player controls for movies beyond starting at a position.
- Parental controls and hiding categories.
- Keeping the catalogue between launches. Offline, the section shows its error message.

## Capabilities

### New Capabilities
- `movies-and-series-browsing`: the Movies and Series sections on every platform, with the banner, rows, genre grids, My list, Continue watching, resume and position saving.

### Modified Capabilities
- `tvos-shell`: Movies and Series appear in the tab bar whenever an Xtream source exists, not only once a source has offered movies.

## Impact

- New Movies and Series screens on every platform; the iPhone, iPad and Mac Live screen's sidebar and tab bar gain their entries.
- Depends on: `xtream-vod-client`, `tvos-shell`, change `add-live-tv-on-iphone-ipad-mac`, change `add-search`, change `add-playback-engine` (seeking, reporting the position, leaving movie playback), change `add-watch-progress-sync` (storing and syncing watch progress and My list).
- Blocked on: the decision record that change `add-watch-progress-sync` names for storing watch progress and My list.
