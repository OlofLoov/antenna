# 0034. Top Shelf extension: favorites and continue watching

- Status: Draft
- Date: 2026-11-04
- Depends on ADRs: 0002, 0003, 0004, 0005, 0006
- Builds on specs: 0005, 0006, 0007, 0011, 0013, 0014, 0015, 0029, 0033
- Needs from other specs: 0015 plays or resumes from a shelf link, holding the request at launch; 0007 offers a channel logo lookup that never fetches; 0011 or 0029 exposes the Continue watching list the app can read.
- Blocked on: an ADR for a storage area shared by the Apple TV app and its Top Shelf extension (an App Group) and the snapshot file the app writes there, because the extension cannot open the app's database or guide cache; and the ADR 0029 is blocked on, for watch progress.
- Platforms: tvOS
- User stories: US-22, US-12, US-20

## Summary

For Apple TV viewers who start from the Home screen. When they highlight Antenna's icon, the Top Shelf (the row of tiles above the app icons) shows their favorite channels with what is on now, and the movies and episodes they are part way through. Selecting a channel tile opens Antenna playing that channel; selecting a movie or episode resumes it. The shelf shows only what the user has in Antenna, never suggested or bundled content, and it updates when Antenna runs, not on its own.

## Design

Boards: `docs/design/boards/TV-TopShelf.dc.html`, `docs/design/boards/TV-TopShelf-Empty.dc.html`.
Design rules that apply: DR-3, DR-4, DR-7, DR-8, DR-11, DR-12, DR-13, DR-14.
Not drawn: a shelf with only Favorites; a shelf with only Continue watching.

Layout, sizes, states and identifiers come from the boards and are settled in the implementation plan, not here.

## Problem

An Apple TV user who highlights Antenna on the Home screen sees nothing, while other TV apps show what to watch next. Antenna knows the user's favorites (0005, 0013), what is on (0014) and what they are part way through (0011), and one press could tune or resume. There is no Top Shelf extension yet, 0015 left it out, and the extension cannot read the app's data directly.

## Scope

In:
- A Top Shelf extension for the Apple TV app with two rows: Favorites and Continue watching.
- Favorite channel tiles titled with the channel name and the programme on now, with a bar showing how far into the programme it is.
- Continue watching tiles for movies and episodes in progress, with how far the user got.
- A single "Add favorites in Antenna to see them here" tile when there is nothing to show.
- The app writing a small summary of this for the extension each time favorites, sources, the guide or progress change.
- Selecting a tile: play the channel or resume the title, whether Antenna was running or not.
- A separate shelf per Apple TV user (0033).

Out (explicitly):
- The large carousel shelf with video previews.
- A fixed picture on the shelf when the user has no data.
- Adding or removing favorites from the shelf.
- Programme artwork on channel tiles.
- Opening Antenna at a channel from Siri, Spotlight or web links.
- Widgets on iPhone, iPad and Mac.
- Settings to hide a row or change how many tiles show.
- How the app's navigation handles a tune or resume request; 0015 owns that.

## User flow

1. On the Home screen the user highlights Antenna's icon. The shelf shows Favorites, one tile per favorite channel with its name, the programme on now and a progress bar. Below, Continue watching shows titles in progress.
2. The user moves into the shelf and selects a favorite. Antenna opens full screen on that channel.
3. Selecting a Continue watching tile opens Antenna and resumes the title where the user left off.
4. A favorite whose guide has run out shows its name alone until Antenna next runs.
5. With no favorites and nothing in progress, the shelf shows one tile, "Add favorites in Antenna to see them here". Selecting it opens Antenna normally.
6. After the user changes favorites, watches something, or the guide refreshes, the shelf is up to date the next time the Home screen shows it.

## Acceptance criteria

### AC-6 Favorites show what is on now
Given the user has favorite channels and the guide knows what is on
When they highlight Antenna on the Home screen
Then a Favorites row lists the favorites in the user's order, each titled "<channel> · <programme on now>" with a bar showing how far into the programme it is.

### AC-6a A channel with no guide left shows its name
Given a favorite whose guide data ends before now
When the shelf is shown
Then its tile is titled with the channel name alone and has no progress bar.

### AC-2 Continue watching shows titles in progress
Given the user is part way through a movie and an episode
When they highlight Antenna on the Home screen
Then a Continue watching row lists them most recent first, the episode titled with its season and episode ("S2 E4"), each with a bar showing how far the user got.

### AC-6b A row with nothing in it is left out
Given the user has favorites but nothing in progress, or the reverse
When the shelf is shown
Then only the row with content appears, and there is no "add favorites" tile.

### AC-8 An empty shelf says how to fill it
Given the user has no favorites and nothing in progress
When the shelf is shown
Then one tile reads "Add favorites in Antenna to see them here" and selecting it opens Antenna normally.

### AC-3a The shelf keeps up with the app
Given Antenna is running
When the user changes favorites, watches something, deletes a source, or the guide refreshes
Then the shelf shows the change the next time the Home screen shows it, including changes made just before Antenna went to the background.

### AC-5 No passwords or links leave the app
Given sources whose stream, logo or poster links carry a username or password
When Antenna writes the shelf's summary for the extension
Then the summary and the tile images hold no link, channel identity, username or password, only names, programme titles, times, progress and the images themselves.

### AC-10 Select a tile to watch
Given a favorite channel tile or a Continue watching tile on the shelf
When the user selects it, with Antenna running on any screen or not running at all
Then Antenna plays that channel, or resumes that title where the user left off, instead of what it would otherwise show at launch.

### AC-10a A tile that no longer matches opens Antenna as it was
Given a tile for a favorite the user has since removed, or the "add favorites" tile, or a damaged link
When the user selects it
Then Antenna opens on the screen it was on, or launches normally, with nothing played and no error shown.

### AC-11a The paywall and setup come first
Given Antenna is locked behind the paid unlock (0024) or has no sources yet
When the user selects a shelf tile
Then the paywall or setup is shown as on a normal launch, and after buying or adding a source Antenna launches normally, without playing the tile's channel.

### AC-15 Each Apple TV user has their own shelf
Given two Apple TV users, each with their own favorites
When one switches user and highlights Antenna
Then the shelf shows only the current user's favorites and progress.

## Edge cases

- Offline: the shelf reads only local files, so it keeps showing; programme titles stop advancing once the 12 hours of guide in the summary run out, until Antenna runs again.
- A huge source: the shelf carries at most 20 favorites and 10 titles, so its size does not grow with the source.
- A failed write (storage full, shared area unavailable) leaves the previous shelf in place and retries on the next change.
- Damaged or outdated summary, for example after an app update: the shelf is blank until Antenna runs again.
- Login not yet synced: those favorites are left off and come back when the login arrives.
- First launch: the shelf is blank until every source has loaded once.
- Favorites added on another device reach the shelf only after Antenna runs on this Apple TV.
- Favorites that are waiting for their source to load: the shelf stays blank rather than showing the add-favorites tile.
- Decided: when the paid unlock lapses, Antenna clears the shelf summary; the shelf shows only the add-favorites tile, which opens the paywall.
- M3U channels with no guide id get a new identity when the playlist is reordered, which breaks old tiles until the next write, as with favorites themselves (0005).
- Nothing on the shelf is content Antenna ships; names and titles come from the user's own sources (App Review 5.2.3).

## Test plan

| Criterion | Layer |
|-----------|-------|
| AC-6 | core + integration |
| AC-6a | core |
| AC-2 | integration |
| AC-6b | core |
| AC-8 | core + integration |
| AC-3a | integration |
| AC-5 | integration |
| AC-10 | ui |
| AC-10a | ui |
| AC-11a | ui |
| AC-15 | device (two users on an Apple TV; the Home screen is out of reach of UI tests) |

## Open questions

- The empty shelf shows one instruction tile (AC-8). Apple suggests a blank shelf when there is nothing to show; switching would change AC-8.
- "<channel> · <programme>" puts the channel first so truncation cuts the programme. Programme title only would change AC-6.
- Decided: the bar on favorite tiles shows programme progress using the system's watch-progress bar (DR-7), though some users may read it as how far they watched.
- 20 favorites, 10 titles and a 12-hour guide window are guesses. Can be decided in the plan.
- The 30-second batching of writes trades freshness against disk writes. Can be decided in the plan.
- Is the extension's shared storage per Apple TV user? Checked on a device before acceptance; if it is shared, AC-15 and 0033 change.
- Should a shelf tile also make the channel's group the current one? This spec leaves the group alone. Can be decided in the plan.

## Notes for the plan

- Target `AntennaTopShelf` (app extension, `com.apple.tv-top-shelf`, bundle id `se.codecrave.antenna.tv.topshelf`, sources in `Apps/TopShelf/`, embedded in `AntennaTV`, depends on AntennaCore only, no bundled resources). App Group `group.se.codecrave.antenna` on both, plus the user-management entitlement as 0033. `AntennaTV` declares URL scheme `antenna`. The section mapping compiles into the `AntennaTV` test bundle too, since an extension cannot host tests.
- AntennaCore holds the versioned snapshot (`TopShelfSnapshot`: version, written-at, favorites with name, tile file and programmes, titles with title, detail, tile file, progress, updated-at, and the count of unresolved favorites), the pure `sections(from:now:)`, the link format `antenna://topShelf/<uuid>` and `antenna://topShelf/empty`, and item ids: a version 5 UUID over the source id and a SHA-256 of the channel or title id. SHA-256 is pure Swift in AntennaCore (ADR-0005 keeps it Foundation only), tested against FIPS 180-4 vectors. Ids are derived, never stored.
- The writer (`Apps/Shared/TopShelf/`, tvOS only) writes `TopShelf/snapshot.json` (atomic rename last), `TopShelf/tiles/<itemID>.png` and `TopShelf/empty.png`, then calls `topShelfContentDidChange()`. It never fetches: artwork comes from 0011's poster cache and the channel logo cache 0007's implementing PR adds (a lookup by channel that returns nil without fetching). Composition and file IO stay off the main actor. A failed write logs only the error case name.
- Writes batch in a 30-second window from the first trigger, not extended by later ones; entering the background flushes inside a background task. No write while any source is still loading; the trigger waits. Triggers also include a source finishing loading and six hours passing while Antenna is open. Tiles fall back to the channel's initials without a logo, and to the title in text without artwork.
- Caps: 20 favorites in catalogue order, 10 titles by most recent, programmes overlapping now to now + 12 h, `snapshot.json` under 256 KB. Programme start is inclusive, stop exclusive, as 0014.
- Tiles are 908 by 512 px: logo centered within 60% of width and height; initials in bold at 200 px; backdrop aspect-fill; poster aspect-fit in the 60% box; title text at 60 px bold, three lines; the empty tile a 200 px star outline. Colors from the board (`#26344A`, `#1E3A5F`, `#F2F4F8`, `#A7B0BF`). Board deviations: the system draws focus (DR-2), the system colors the progress bar (DR-3, DR-7), and channel numbers are omitted (DR-6).
- Provider: `TVTopShelfSectionedContent`, `.hdtv` image shape, file URLs at 1x and 2x, play action for items and display action for the empty tile; no network requests. A missing tile drops the item; an empty section is omitted; nothing at all returns nil content.
- 0015 amendments, drafted in the old text's appendix: `ShellNavigator.tune(to:)` plays a channel key as after `showLive()`, doing nothing when it does not resolve; `play(titleID:sourceID:)` resumes a title per 0011; a request made before the shell exists is held until the channel's source loads within 0015's launch deadline, replaces the last-channel tune, and results in one load in total, or is dropped. 0011 or 0029 exposes the Continue watching list as a function the writer can call.
- Item identifiers for unit tests: `topShelf.section.favorites`, `topShelf.section.continueWatching`, `topShelf.item.<itemID>`, `topShelf.emptyItem`. Deep links in UI tests use `-antenna.openURL <url>` with a recording navigator.

## Dropped

- Split earlier (kept for history): AC-3 into AC-3a, AC-3b and AC-3c, because it bundled triggers, the batching window and the background write; the 22:00 case of AC-6a became AC-6c.
- Dropped earlier: AC-12 was the same case as AC-10a; AC-11b restated an obligation that belongs to 0015.
- Merged into AC-6: AC-1.
- Merged into AC-3a: AC-1a, AC-3c.
- Moved to Edge cases: AC-8a.
- Merged into AC-10: AC-11.
- Moved to the implementation plan: AC-3b, AC-4, AC-5a, AC-6c, AC-7, AC-9, AC-13, AC-14.
