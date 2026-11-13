# Design

## Context

`M3UParser` turns every entry into a `Channel`, and `SourceLoader.load` hands the list to Live. Movies and Series come from `ShelfLoader`, which only knows Xtream: `ShelfModel.sourcesChanged` keeps `.xtream` sources, and the iPhone Movies tab and the Apple TV Movies and Series tabs show only with an Xtream source (`ShelfLibrary.hasXtream`, `ShellModel.offersMovies`). `ShelfTitle` ids are what watch progress and My list store, synced through CloudKit.

## Goals / Non-Goals

**Goals:**
- Movies of a plain playlist leave Live and show in Movies with the existing shelf UI.
- Sorting is a pure function in AntennaCore with tests.

**Non-Goals:**
- Series from a playlist. Grouping episodes into series and seasons needs a name parser and a new episode source for the title page; a later change.
- Year, plot and rating for playlist movies.

## Decisions

### Where sorting lives

`PlaylistEntryKind(_ channel:)` in AntennaCore (`Parsers/PlaylistEntryKind.swift`) sorts one parsed entry. `Playlist.separatingMovies()` moves movies to a new `Playlist.movies` list. The parser itself is not changed, so another change working on header parsing does not collide and every caller that parses for other reasons (import preview, file re-import) still sees every entry.

Options considered:
1. **Sort after parsing** (chosen). One extra pass over the entries, no parser change.
2. **Sort inside `M3UParser`.** Saves the pass, but every parser caller gets the split, including the import preview that counts entries.
3. **Sort in the app.** Breaks the rule that parsing logic lives in AntennaCore.

Order of rules: folder names first, because Xtream panels name them exactly; then the episode marker, so an episode's `.mp4` does not make it a movie; then the file extension; then the group. A group rule alone would catch "Vodafone" if it matched prefixes, so it compares the group's first word.

### Where movies go after a load

`SourceLoader` separates movies for `.m3u` and `.m3uFile` loads and leaves them in `PlaylistMovies`, an in-memory store keyed by source id (`Persistence/PlaylistMovies.swift`). `ShelfLoader` reads it for a playlist source, and loads the playlist through `SourceLoader` when Movies opens before Live has loaded it. Links stay in memory: they can hold the login, so they are never written to SwiftData, UserDefaults or logs.

Options considered: download the playlist again when Movies opens (a second download of a file that can be tens of megabytes); keep the movies on `LiveModel` and pass them across (couples Live to the shelf); a shared in-memory store (chosen).

### Titles and playback

`ShelfCatalogue(playlistMovies:sourceID:)` maps each movie to a `ShelfTitle` with the entry's id (`m3u.<hash>`, which holds no link), name, logo, group and file extension. Categories are the groups in first-seen order. `ShelfLoader.details` and `info` answer a `VODInfo` with only the file extension, so the banner and title page show the name, poster and category. `movieURL` looks the link up in `PlaylistMovies` by id.

### Showing the tab

- iPhone: `CompactTabs.showsMovies` is `shelves.hasXtream` or any source whose `SourceRefresher` status has movies. `SourceStatus` gains `movies`, set on each load.
- Apple TV: `ShellModel.offersMovies` becomes computed from an Xtream source or a playlist whose last load had movies.
- iPad and Mac show the Movies section as before.
- `ShelfModel` for Movies takes `.xtream`, `.m3u` and `.m3uFile` sources; Series stays Xtream only.

### Boards

No new element. The Movies screens follow `iPhone-Movies`, `iPhone-Movies-Rows`, `iPhone-Movies-Grid`, `iPad-Movies`, `TV-Movies` and their grid and rows boards as they are, with fewer details on the banner. Design-system requirements followed: every screen has a board, deviations are named. The named deviation: a playlist movie's banner and title page show no year, length or plot, because the playlist has none.

## Risks / Trade-offs

- [A live channel whose link ends in `.mp4`, such as a looping channel] → shows in Movies instead of Live. The rule follows the task's list; a per-source switch is out of scope.
- [A favorite of an entry that is now a movie] → stops matching in Live. Movies have My list instead.
- [A playlist source in the Movies section that fails to load] → the section shows the failure banner beside the Xtream sources, as an Xtream failure does.
- [Episodes stay in Live] → until the series change lands.
