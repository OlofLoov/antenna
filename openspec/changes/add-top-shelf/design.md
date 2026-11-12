# Design

## Context

Boards: `openspec/specs/design-system/boards/TV-TopShelf.dc.html`, `TV-TopShelf-Empty.dc.html`.

Design-system requirements that apply: "One accent color", "Text stays above the platform caption floor", "A current programme always shows its progress", "Channels without a logo show initials", "Accessibility identifiers follow the board", "Nothing fake and nothing bundled", "Text meets contrast minimums", "Nothing shows before the paywall".

Not drawn yet: a shelf with only Favorites, and a shelf with only Continue watching.

The extension cannot open the app's database or guide cache. The shared App Group and the snapshot file need a decision, recorded here with the options considered, before work starts (see proposal Impact).

## Goals / Non-Goals

**Goals:**
- A versioned snapshot written by the app and read by an extension that makes no network requests.
- Section mapping and link format in AntennaCore, testable without the extension.

**Non-Goals:**
- Navigation inside the app after a link arrives, which `tvos-shell` owns.
- Making a shelf tile also change the current group. This change leaves the group alone; it can be decided at implementation.

## Decisions

- Target `AntennaTopShelf` (app extension, `com.apple.tv-top-shelf`, bundle id `se.codecrave.antenna.tv.topshelf`, sources in `Apps/TopShelf/`, embedded in `AntennaTV`, depends on AntennaCore only, no bundled resources). App Group `group.se.codecrave.antenna` on both. `AntennaTV` declares URL scheme `antenna`. The section mapping compiles into the `AntennaTV` test bundle too, since an extension cannot host tests.
- AntennaCore holds the versioned snapshot (`TopShelfSnapshot`: version, written-at, favorites with name, tile file and programmes, titles with title, detail, tile file, progress, updated-at, and the count of unresolved favorites), the pure `sections(from:now:)`, the link format `antenna://topShelf/<uuid>` and `antenna://topShelf/empty`, and item ids. Item ids are a version 5 UUID over the source id and a SHA-256 of the channel or title id. SHA-256 is pure Swift in AntennaCore (AntennaCore imports Foundation only), tested against FIPS 180-4 vectors. Ids are derived, never stored.
- The writer (`Apps/Shared/TopShelf/`, tvOS only) writes `TopShelf/snapshot.json` (atomic rename last), `TopShelf/tiles/<itemID>.png` and `TopShelf/empty.png`, then calls `topShelfContentDidChange()`. It never fetches. Artwork comes from the poster cache of `add-movies-and-series-browsing` and the channel logo cache `add-tv-channel-overlay` adds (a lookup by channel that returns nil without fetching). Composition and file IO stay off the main actor. A failed write logs only the error case name.
- Writes batch in a 30-second window from the first trigger, not extended by later ones. Entering the background flushes inside a background task. No write while any source is still loading; the trigger waits. Triggers also include a source finishing loading and six hours passing while Antenna is open. Tiles fall back to the channel's initials without a logo, and to the title in text without artwork.
- Caps: 20 favorites in catalogue order, 10 titles by most recent, programmes overlapping now to now + 12 h, `snapshot.json` under 256 KB. Programme start is inclusive and stop exclusive, as in `guide-data`.
- Tiles are 908 by 512 px: logo centered within 60% of width and height; initials in bold at 200 px; backdrop aspect-fill; poster aspect-fit in the 60% box; title text at 60 px bold, three lines; the empty tile a 200 px star outline. Colors from the board (`#26344A`, `#1E3A5F`, `#F2F4F8`, `#A7B0BF`). Board deviations: the system draws focus ("Focus is the lifted white card"), the system colors the progress bar ("One accent color", "A current programme always shows its progress"), and channel numbers are omitted ("Channel rows share one anatomy").
- Provider: `TVTopShelfSectionedContent`, `.hdtv` image shape, file URLs at 1x and 2x, play action for items and display action for the empty tile, no network requests. A missing tile drops the item. An empty section is omitted. Nothing at all returns nil content.
- `tvos-shell` amendments: `ShellNavigator.tune(to:)` plays a channel key as after `showLive()`, doing nothing when it does not resolve; `play(titleID:sourceID:)` resumes a title as `add-movies-and-series-browsing` does; a request made before the shell exists is held until the channel's source loads within the shell's launch deadline, replaces the last-channel tune, and results in one load in total, or is dropped. `add-movies-and-series-browsing` or `add-watch-progress-sync` exposes the Continue watching list as a function the writer can call.
- Item identifiers for unit tests: `topShelf.section.favorites`, `topShelf.section.continueWatching`, `topShelf.item.<itemID>`, `topShelf.emptyItem`. Deep links in UI tests use `-antenna.openURL <url>` with a recording navigator.
- The bar on favorite tiles shows programme progress using the system's watch-progress bar, though some users may read it as how far they watched.
- The Home screen is out of reach of UI tests, so the shelf after a profile switch is checked through the snapshot the app writes: it holds the current profile's rows only (change `add-profiles`).

## Risks / Trade-offs

- Open question: the empty shelf shows one instruction tile. Apple suggests a blank shelf when there is nothing to show; switching would change the empty-shelf requirement.
- Open question: "<channel> · <programme>" puts the channel first so truncation cuts the programme. Programme title only would change the favorites requirement.
- Open question: 20 favorites, 10 titles and a 12-hour guide window are guesses. Can be decided at implementation.
- Open question: the 30-second batching of writes trades freshness against disk writes. Can be decided at implementation.
- [M3U channels with no guide id get a new identity when the playlist is reordered] → old tiles stop matching until the next write, as favorites themselves do.
- [Names and titles on the shelf] → they come only from the user's own sources, never shipped content (App Review 5.2.3).

## Implementation decisions

- SHA-256 already existed in AntennaCore for the Stalker device identity (`Stalker/Digest.swift`). SHA-1 joins it there, since a version 5 UUID is defined over SHA-1. Item ids are `UUIDv5(namespace, "<source uuid>/<sha-256 hex of the id>")` under a fixed namespace in `TopShelfItemID`.
- The snapshot builder lives in AntennaCore next to the format (`TopShelfSnapshot(favorites:titles:unresolvedFavorites:now:)`), so the caps, the 12-hour window and the "no link or identity" rule are proved by core tests and the app only gathers inputs.
- Continue watching on the shelf takes titles in progress only. A series offered as "Next episode" in the app is left out: its bar would read as finished, and the requirement names titles in progress.
- A snapshot over 256 KB halves the programmes kept per favorite until it fits, so the programme on now always survives.
- `unresolvedFavorites` above zero with nothing else to show gives a blank shelf, not the add-favorites tile. A cleared snapshot (unlock lapsed) has zero and gives the tile.
- `add-tv-channel-overlay` shipped logos through `AsyncImage`, with no logo cache of its own. The writer reads a logo from `URLCache.shared`, which `AsyncImage` fills, and never sends a request. `PosterCache.cached(for:)` reads memory and disk only.
- The hand-off sits behind `TopShelfStoring` in AntennaCore. `TopShelfFolder` is the App Group folder, and tests use a temporary folder or an in-memory fake. Without the App Group, as in an unsigned simulator build, `TopShelfFolder.shared()` is nil and nothing is written.
- A favorite counts as unresolved when its source exists and has not loaded with channels, which covers a source still loading, waiting for its login, offline or failed. A favorite whose channel is gone from a loaded source does not count, so it cannot keep the shelf blank forever.
- An episode's "S2 E4" comes from the series' episode list once the app has loaded it. Before that the tile shows the series name alone.
- `TopShelfSync` lives on the shell, under the profile gate, so it reads the current profile's catalogue and Continue watching. A profile switch rebuilds the shell, whose first change starts a write.
- A lapsed unlock clears the summary from the window root (`TopShelfLock`), since the shell is not built while the paywall shows. It also runs at launch when the app starts locked.
- The App Group entitlement is declared in `project.yml` for `AntennaTV` and `AntennaTopShelf`, since XcodeGen writes the entitlements files. The extension's provider uses the completion-handler `loadTopShelfContent`, because the async override cannot return the non-Sendable content under strict concurrency.
- `Apps/TopShelf/TopShelfItems.swift` builds the sectioned content and compiles into `AntennaTVTests` as well; `ContentProvider.swift` only reads the shared folder and calls it. Channel and title tiles set both the play and the display action to their link; the add-favorites tile sets only the display action.
- The C4 container diagram gains the Top Shelf extension and the shelf folder (App Group files) it reads.
