# Design

## Context

Movies and Series take playlist sources since `add-m3u-vod-fallback` and `add-m3u-series`. Whether a screen offers them is decided in eight places, each with its own rule:

- iPhone tab bar, `RootView.CompactTabs.showsMovies`: Xtream, or a source whose `SourceRefresher` status counts movies or episodes.
- Apple TV tab bar, `ShellModel.offersMovies`: Xtream, or a playlist with movies or episodes in its last load in this run. Movies and Series show together, so a playlist of episodes shows an empty Movies tab.
- iPad and Mac sidebar, `LiveRegularView.sections`, and its restore and launch: `ShelfLibrary.hasXtream` or `kind == .xtream`.
- iPhone restore and launch in `CompactTabs.onAppear`, the "Open on launch" picker in `SettingsView`, and the Apple TV launch in `ShellModel.openOnLaunch`: `kind == .xtream`.
- Search chips, `SearchCorpus.hasTitles`: `ShelfLibrary.hasXtream` on every platform. The titles themselves already include playlist titles, since Search opens the library.
- Top Shelf links, `TopShelfLinks.titlesPending`: false without Xtream, so a link to a playlist title gives up before the titles load.
- Siri and Shortcuts without a running window, `AppIntentHost.titles`: Xtream sources only, through a `ShelfLoader` with no playlist loader.

`SourceStatus.movies` and `episodes` live only for the run, so at launch every playlist reads as having no titles until it loads again.

## Goals / Non-Goals

**Goals:**
- One value type answers "does this device offer movies, series, or either", and every place above reads it.
- The answer is right at launch, before the playlists load again.
- Apple TV never shows an empty Movies tab because a playlist has only episodes.

**Non-Goals:**
- Hiding Movies or Series for an Xtream source that has none.
- New screens or board changes.

## Decisions

### One value: `TitleOffer`

`TitleOffer` in `Apps/Shared/Persistence/TitleOffer.swift` is a `Sendable` struct with `movies` and `series`, and `any` for either. `TitleOffer(_ sources: [(id: UUID, kind: SourceKind)], counts: (UUID) -> TitleCounts?)` builds it: an `.xtream` source offers both; an `.m3u` or `.m3uFile` source offers movies when its counts have movies and series when they have episodes; other kinds offer nothing. `TitleCounts` is a `Codable` struct of two `Int`s.

A convenience `TitleOffer(records:refresher:)` reads `SourceRecord`s and `SourceRefresher.status(of:)`, and is what the iPhone, iPad, Mac and Settings screens call. `ShelfSync` publishes the same value on `ShelfLibrary.offer`, replacing `ShelfLibrary.hasXtream`, so Search and Top Shelf read it from the library they already hold.

Options considered:
1. **A value type built from sources and counts** (chosen). Pure, testable without views, and each screen supplies counts from what it already has.
2. **A property on `SourceRefresher`.** The refresher does not know the source kinds, and is nil in previews.
3. **Keep each screen's own check and fix them one by one.** That is how the gaps appeared.

### Where counts come from

`SourceRefresher` already records `movies` and `episodes` on each load. `LastLoadStore` gains `readTitles` and `writeTitles` under `settings.lastTitles.<sourceId>`, a JSON `TitleCounts` beside the last load date, and `forget` removes both. `SourceRefresher.status(of:)` fills `movies` and `episodes` from it for a source not loaded in this run, so the first frame after launch has the last known counts. Counts hold no link or login, so `UserDefaults` is allowed by the per-device state rule.

The Apple TV shell keeps its own counts per source from its loads, seeded from `Dependencies.storedTitles` (the refresher's status in the app, nothing in tests). `ShellModel.titleOffer` replaces `offersMovies`.

### Apple TV: Movies and Series each by their own offer

`ShellModel.tabs` lists Movies when `titleOffer.movies` and Series when `titleOffer.series`. A playlist of episodes shows Live, Guide, Series and Search. A tab that disappears while open falls back to Live, as Movies does today when the last Xtream source goes. "Open on launch: Movies" and onboarding's Browse movies open Movies when it is offered and Series otherwise.

Options considered: keep both tabs and fill an empty Movies tab with a "No movies" message (a tab that leads nowhere); show Series inside Movies as on iPhone (the TV boards draw them as two tabs). Hiding the empty tab keeps the board's tab bar.

### iPad and Mac sidebar

`LiveRegularView.sections` lists Movies when `offer.movies` and Series when `offer.series`. `LiveSection(_:offer:)` restores Movies or Series only when offered, else Live. The launch preference's Movies opens Movies, or Series when only series are offered. The section falls back to Live when its kind stops being offered.

### iPhone

The tab bar keeps one Movies tab with Series inside, shown when `offer.any`. Restore and the launch preference use the same value.

### Settings

"Open on launch" lists Movies when `offer.any`, on every platform.

### Top Shelf

Playlist titles belong in Top Shelf as Xtream titles do: Continue watching tiles come from watch progress, which playlist titles record. `TopShelfLinks.titlesPending` waits while `library.offer.any` and a shelf is still loading, so a tile for a playlist movie opens once the playlist's titles load.

### Siri and Shortcuts

`AppIntentHost.titles` without a running library loads playlist sources too, through a `ShelfLoader` that can load the playlist (`playlists: loader`). `TitleReference(parsing:)` in AntennaCore accepted only Xtream `vod` and `series` ids, so a playlist title found by Siri could not be played. It now also accepts `m3u.series.<16 hex>` as a series and `m3u.<16 hex>` as a movie. A live channel or episode id has the same `m3u.<16 hex>` form; no title lookup finds one, so Siri answers that the title is gone. The stored format of existing references does not change.

### Boards

No new element. Followed as drawn: `iPad`, `iPad-Movies`, `iPad-Series`, `iPhone-Movies`, `iPhone-Series`, `iPhone-Settings`, `iPad-Settings`, `iPhone-Search`, `iPad-Search`, `TV-Shell-Menu`, `TV-Movies`, `TV-Series`, `TV-Search`, `TV-Settings-Preferences`, `TV-TopShelf`. Design-system requirements followed: every screen has a board, deviations are named. The named deviation: with only series offered, the Apple TV tab bar and the iPad sidebar show Series without Movies, which no board draws; it is the drawn tab bar with one item left out, so no board is added.

## Risks / Trade-offs

- [Stored counts from a playlist that has since lost its titles] → Movies shows at launch and leaves when the playlist loads. The same happens today with any status.
- [A Movies section restored before the playlist loads] → it shows the loading state of the shelf, as an Xtream source does.
- [UI tests share `UserDefaults.standard` across launches] → the scripted refreshers already use their own suites, so stored counts do not leak between test classes.
