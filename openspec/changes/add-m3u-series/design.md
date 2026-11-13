# Design

## Context

`PlaylistEntryKind` sorts a playlist entry into live, movie or episode. `Playlist.separatingMovies()` moves movies to `Playlist.movies`; episodes stay in `channels`. `SourceLoader` keeps a playlist's movies in `PlaylistMovies`, an in-memory store keyed by source id, and `ShelfLoader` builds the Movies catalogue from it. Series come only from Xtream: `ShelfModel.sourcesChanged` keeps `.xtream` sources for Series, and `ShelfLoader.load`, `details`, `info`, `episodes` and `episodeURL` all go through `XtreamClient`.

The title page (`TitleScreen`, `TitleModel`) shows a series from `TitleInfo.series(SeriesInfo)`: its episodes, grouped by `Episode.season`, feed the season picker and episode list. Playback of an episode asks `ShelfLoader.episodeURL(_:episode:)`. Progress and My list key a title by `ShelfTitle.id` and an episode by `Episode.id`.

## Goals / Non-Goals

**Goals:**
- Episodes leave Live and show as series with seasons, on the existing Series screens.
- Name parsing and grouping are pure functions in AntennaCore with tests.

**Non-Goals:**
- Other episode name forms ("1x02", "Season 1 Episode 2").
- Details beyond the name, poster, category and episode titles.

## Decisions

### Reading an episode name

`EpisodeName(_ name: String)` in AntennaCore (`Parsers/PlaylistSeries.swift`) finds the marker with the same pattern `PlaylistEntryKind.namesAnEpisode` uses, `S\d{1,2}\s?E\d{1,3}` not inside a word, so an entry sorted as an episode by its name always parses. The show is the text before the marker with trailing separators (space, `-`, `–`, `|`, `:`, `.`, `_`, `(`) trimmed; a show written with dots or underscores and no spaces ("The.Show.") has them turned into spaces. The title is the text after the marker with leading separators trimmed, nil when empty. A name whose show part is empty uses the entry's group, else the whole name.

The grouping key is the show lowercased with every run of characters other than letters and digits turned into one space, so "The Show", "the show" and "The.Show" group together.

Options considered:
1. **Marker only, `SxxEyy`** (chosen). The form panels write and the one the sorter already uses.
2. **Also `1x02` and "Season 1 Episode 2".** More shows found, but the sorter would need the same rules or entries would sort as live and parse as episodes. Left for a change that extends both.
3. **Group by the entry's group instead of the name.** Panels put many shows in one group ("Series | Netflix"), so a group is not a show.

### Grouping

`PlaylistSeries(episodes: [Channel], sourceID: UUID)` builds:

- One `ShelfTitle` per show, kind `.series`, in the order each show first appears. Id `m3u.series.<16 hex>`, 64-bit FNV-1a over the grouping key and the source id, so the same show in two playlists gets two ids, as two Xtream sources do. Name is the show as first written; poster is the first episode's logo; category is the first episode's group.
- Categories are the groups of the series in first-seen order.
- A `SeriesInfo` per series id with its episodes. Each `Episode` keeps the entry's id (`m3u.<hash>`, which holds no link), `episodeID` 0 (only Xtream links use it), the season and number, the title or "Episode <n>", the link's file extension, and the logo as its thumbnail. Episodes sort by season then number with nil first, ties in playlist order, as `SeriesInfo` documents for Xtream. Two entries with the same season and number both stay, since a playlist can list one episode in two languages.
- An episode recognized by a `/series/` link without a marker forms a series named after the entry, with no season or number.

`ShelfCatalogue(series:)` and `info(for:)` give the loader what it needs.

### Playlist split

`Playlist.separatingMovies()` becomes `separatingOnDemand()`: movies go to `movies` and episodes to a new `episodes` list, each in playlist order. The two callers (`SourceLoader.keepMovies`, `SourceConnector`'s playlist check) change with it.

### Where series live after a load

`PlaylistMovies` keeps, per source, the episode entries and the grouped `PlaylistSeries` next to the movies, built once per load in `SourceLoader.keepMovies`. `link(of:in:)` looks in movies and then episodes. Links stay in memory only.

Options considered: group on each shelf load (repeats the work for every banner and page request); keep series on `LiveModel` (couples Live to the shelf); in the existing store (chosen).

### Loader and screens

- `ShelfLoader.load(_:kind: .series)` for a playlist answers the grouped catalogue; `details` answers `ShelfDetails(series:)`, so the banner says how many seasons; `info` answers `.series(SeriesInfo)`; `episodes` answers the series' episodes; `episodeURL` looks the link up by `Episode.id`.
- `ShelfModel.sourcesChanged` takes `.m3u` and `.m3uFile` sources for Series too.
- `SourceStatus` gains `episodes`, set on each load. The iPhone Movies tab shows when a playlist's last load had movies or episodes (one condition in `RootView.CompactTabs.showsMovies`). On Apple TV, `ShellModel` counts a playlist with movies or episodes, and the Movies and Series tabs show together as before.

### Boards

No new element. Followed as they are: `iPhone-Series`, `iPad-Series`, `TV-Series`, `iPhone-Title`, `iPad-Title`, `TV-Title`. Design-system requirements followed: every screen has a board, deviations are named. The named deviation: a playlist series' banner and title page show no year, plot or backdrop, and its episodes no description or length, because the playlist has none.

## Risks / Trade-offs

- [A show spelled differently across entries ("Show" and "Show US")] → two series. The key ignores case and punctuation only.
- [A favorite saved on an episode while it was in Live] → shows as missing. Series have My list instead.
- [Apple TV with a playlist that has episodes and no movies] → the Movies tab shows and is empty, as it does for an Xtream source with no movies.
- [A large playlist] → grouping is one pass over the episodes plus a sort per series, run off the main actor with the parse.
