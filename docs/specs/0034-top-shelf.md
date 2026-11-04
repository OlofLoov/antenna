# 0034. Top Shelf extension: favorites and continue watching

- Status: Draft
- Date: 2026-11-04
- Depends on ADRs: 0002, 0003, 0004, 0005, 0006
- ADR needed: an App Group (`group.se.codecrave.antenna`) shared by the tvOS app and a Top Shelf extension, and a snapshot file the app writes into it for the extension to read, because the extension cannot open the app's SwiftData store (ADR-0002) or its guide cache (0014's pending storage ADR). Criteria below assume that outcome and name the snapshot `TopShelfSnapshot`.
- Blocked on: the App Group ADR above; 0011's ADR for `WatchProgressRecord` (AC-2 reads those records); a 0015 revision adding the three `ShellNavigator` criteria drafted in the Appendix (`tune(to:)`, `play(titleID:sourceID:)`, held request at launch), which move to 0015 when this spec is accepted; 0007's implementing PR, for the logo cache lookup by `Channel` named under Required of other specs. The core layer (AC-6 to AC-9) can be implemented and tested before any of these.
- Platforms: tvOS
- Builds on specs 0005 and 0013 (favorites and their resolution), 0014 (guide queries), 0011 (Continue watching list, position records, poster cache), 0015 (`ShellNavigator`, launch and loading states), 0006 (root chooser), 0007 (channel logo loading). 0029 (continue watching) and 0033 (tvOS profiles) are being written in parallel PRs and are cited by number only; where this spec names a 0011 criterion for continue watching, 0029 may take it over.
- Written without an interview. Every decision is listed under Open questions for the owner to overturn.

## Design

Boards: `docs/design/boards/TV-TopShelf.dc.html` (two sections, a logo tile, initials tiles, a guide-exhausted item, continue watching tiles with one artwork fallback) and `docs/design/boards/TV-TopShelf-Empty.dc.html` (no favorites, nothing in progress). Item identifiers (`topShelf.section.favorites`, `topShelf.section.continueWatching`, `topShelf.item.<itemID>`, `topShelf.emptyItem`) are comments on the boards (DR-11). They are `TVTopShelfItem.identifier` values checked by unit tests; XCUITest cannot reach the Home screen.
Design rules that apply: DR-3, DR-4, DR-7, DR-8, DR-11, DR-12, DR-13, DR-14. Deviations: DR-2, the system draws focus on the Home screen and the app has no say, so the white card does not apply; DR-3 and DR-7, the progress bar under a tile is drawn by the system from `playbackProgress` in the system's colour, so the accent on the board shows where it sits, not what colour it will be; DR-6, the channel row anatomy does not apply because a Top Shelf item has one image and one title line, so the number is omitted and the programme title follows the name after " · ".
Tile colours, read from the boards and checked by the impl-reviewer rather than by tests: channel tiles and the empty tile sit on `#26344A`; the title-text fallback tile sits on `#1E3A5F`; initials and fallback title text are `#F2F4F8`; the empty tile's star outline is `#A7B0BF`.
States on the boards: favorites with a logo tile and with initials tiles, progress bars, a favorite whose guide is exhausted (name alone, no bar, `TV-TopShelf.dc.html`, fourth tile), continue watching with backdrop tiles and the title-text fallback, the empty item (`TV-TopShelf-Empty.dc.html`).
Not drawn: a shelf with only the Continue watching section (the Favorites section is absent, the rest is as drawn); a shelf with only the Favorites section. Top Shelf has no loading or error state the app can draw: until the extension's completion handler fires the system keeps the previous shelf, and on any failure the extension returns no content and the system shows the Home screen without a shelf.

## Problem

An Apple TV user who highlights Antenna on the Home screen sees nothing, while every other TV app shows what to watch next. The user has favorites (0005, 0013), a guide (0014) and titles in progress (0011) that could answer "what is on my channels right now" and "where was I" before the app opens, and one press could tune or resume. The app has no Top Shelf extension, 0015 lists it as out of scope, and the extension cannot read the app's SwiftData store or guide cache directly.

## Scope

In:
- A tvOS app extension target `AntennaTopShelf` in `project.yml`, extension point `com.apple.tv-top-shelf`, bundle id `se.codecrave.antenna.tv.topshelf`, sources in `Apps/TopShelf/`, embedded in `AntennaTV`, depending on `AntennaCore`. Its principal class is a `TVTopShelfContentProvider` subclass. The mapping from `[TopShelfSection]` to `TVTopShelfSectionedContent` is a function in `Apps/TopShelf/` compiled into the `AntennaTV` test bundle as well as the extension, because an app extension product cannot host tests.
- `Apps/TV/Info.plist` declares `CFBundleURLTypes` with the scheme `antenna`.
- The App Group `group.se.codecrave.antenna` in both `Config/AntennaTV.entitlements` and the extension's entitlements, plus the user-management entitlement with `runs-as-current-user` on both so the container is per profile (0033).
- `TopShelfSnapshot` in AntennaCore: `Codable`, `Sendable`, versioned. Fields: `version: Int`, `writtenAt: Date`, `favorites: [TopShelfChannel]`, `continueWatching: [TopShelfTitle]`, `unresolvedFavoriteCount: Int` (0013/AC-8's `unresolvedFavorites.count` at write time). `TopShelfChannel`: `itemID: UUID`, `name: String`, `tileFile: String`, `programmes: [TopShelfProgramme]` (`title`, `start`, `stop`). `TopShelfTitle`: `itemID: UUID`, `title: String`, `detail: String?`, `tileFile: String`, `progress: Double`, `updatedAt: Date`.
- `TopShelfItemID` in AntennaCore: `make(sourceID: UUID, channelID: String) -> UUID` and `make(sourceID: UUID, titleID: String) -> UUID`, a version 5 UUID over the source id and the SHA-256 of the channel or title id, with a different namespace per kind. The hash is a pure-Swift SHA-256 kept in AntennaCore, because ADR-0005 limits the package to Foundation and CryptoKit is not part of it; a test checks it against the FIPS 180-4 vectors. Item ids are derived, never stored; on a link the app recomputes them over the current favorites and Continue watching records.
- `TopShelfContent.sections(from: TopShelfSnapshot, now: Date) -> [TopShelfSection]` in AntennaCore: pure, returns `TopShelfSection` (`identifier`, `title`, `items: [TopShelfItem]`) and `TopShelfItem` (`identifier`, `title`, `tileFile`, `progress: Double?`, `link: URL`). `TopShelfSnapshot.decode(_ data: Data) -> TopShelfSnapshot?` is `nonisolated`, does not throw and returns nil for anything it cannot use.
- `TopShelfLink` in AntennaCore: `url(for itemID: UUID) -> URL` producing `antenna://topShelf/<uuid>`, `emptyURL` (`antenna://topShelf/empty`) and `itemID(from: URL) -> UUID?`.
- `TopShelfWriter` in the app layer (`Apps/Shared/TopShelf/`, `#if os(tvOS)`): builds the snapshot from the catalogue (0013), `GuideStore` (0014) and the Continue watching list (0011/AC-4), composes 908 by 512 px tile images, writes `TopShelf/snapshot.json`, `TopShelf/tiles/<itemID>.png` and `TopShelf/empty.png` into the App Group container, and calls `TVTopShelfContentProvider.topShelfContentDidChange()`. Artwork comes only from the app's image cache (0011/AC-18b's poster cache for posters and backdrops; the channel logo cache that 0007's implementing PR introduces for channel rows). The writer never issues a network request; a channel whose logo is not cached at write time gets the initials tile and is re-composed at the next write. The writer does not write while any source is in a non-terminal 0010/AC-16 state; a trigger during that time is held and fires when the last source reaches a terminal state. The background trigger honours this too and leaves the previous snapshot in place.
- Write triggers, deferral and coalescing (AC-1a, AC-3a to AC-3c), caps (AC-4), stale handling (AC-6a), secrets rule (AC-5), failed writes (Edge cases).
- Deep links from the shelf into the running app and into a cold launch through `ShellNavigator` (AC-10 to AC-11a).
- The empty item when there is nothing to show (AC-8).

Out (explicitly):
- Carousel and inset Top Shelf layouts with video previews. A later spec if wanted.
- A static Top Shelf image in the asset catalog. The shelf is empty until the user has data (DR-12).
- Adding or removing favorites from the shelf (not possible in Top Shelf).
- Programme artwork on favorite tiles (needs 0014's `Programme.iconURL` cached; a 0014 follow-up).
- Deep links from anywhere other than the Top Shelf (Siri, Spotlight, universal links): a later spec.
- iOS, iPadOS, macOS widgets with the same content: a later spec, which may reuse `TopShelfSnapshot`.
- Where the guide persists (0014's ADR) and where positions persist (0011's ADR).
- Settings to hide either section or change caps: Settings spec.
- The behaviour of `tune(to:)`, `play(titleID:sourceID:)` and the held request inside the shell: 0015, via the Appendix.

Required of other specs:
- 0015 adopts the Appendix criteria: `ShellNavigator.tune(to: LastChannelKey)`, `play(titleID: String, sourceID: UUID)`, a request held until the shell exists, and AC-2a and AC-2b yielding to a held `tune(to:)`.
- 0011 (or 0029) exposes the Continue watching list as a pure function the writer can call with the current records, and its position writes (0011/AC-16) count as an AC-3a trigger.
- 0007's implementing PR exposes the channel logo cache as a lookup by `Channel` that returns the cached bitmap or nil without fetching.
- 0033 states that the extension carries the same user-management entitlement as the app.

## User flow

1. On the Home screen the user moves focus to Antenna's icon. The shelf above shows "Favorites" with one tile per favorite channel, each titled with the channel name and the programme on now, and a progress bar for that programme. Below it, "Continue watching" shows titles in progress with their positions.
2. The user swipes up into the shelf, moves across the tiles and presses select on a favorite. Antenna opens full screen on that channel.
3. Pressing select on a Continue watching tile opens Antenna and resumes that title at its saved position.
4. A favorite whose guide data has run out shows the channel name alone until the app next runs and refreshes the snapshot.
5. With no favorites and nothing in progress, the shelf shows one tile: "Add favorites in Antenna to see them here". Select opens Antenna as a normal launch.
6. After the user adds or removes a favorite, watches a title, or the guide refreshes while the app is open, the shelf is updated the next time the Home screen shows it.

## Acceptance criteria

Each criterion is testable in isolation and has a stable id. Do not renumber.

### AC-1 Favorites in the snapshot
Given a loaded catalogue whose `rows(in: .favorites)` (0013/AC-8) yields channels Y then X, Y with a cached logo and X without, and a `GuideStore` with programmes for Y covering 20:00 to 22:00 and 22:00 to 23:30 and nothing for X
When `TopShelfWriter.write(now: 21:34)` runs
Then the snapshot at `<App Group container>/TopShelf/snapshot.json` decodes to `favorites` [Y, X] in that order; Y's `programmes` holds exactly the programmes from `programmes(for:in:)` over 21:34 to 09:34 the next day, so both; X's `programmes` is empty; each entry's `name` equals the channel's `name`; each `itemID` equals `TopShelfItemID.make(sourceID:channelID:)` for that channel; each `tileFile` names an existing PNG under `TopShelf/tiles/`; `writtenAt` equals `now`; `version` equals `TopShelfSnapshot.currentVersion`.

### AC-1a Deferred write
Given a trigger while source S is still loading (0010/AC-16 non-terminal)
When S finishes 40 seconds later on the injected clock
Then exactly one write follows, within 30 seconds of S finishing, and none before.

### AC-2 Continue watching in the snapshot
Given the Continue watching list of 0011/AC-4 holding a movie at 42% with 52 minutes left and a series at 78% on season 2 episode 4, ordered by `updatedAt` descending
When `TopShelfWriter.write(now:)` runs
Then `continueWatching` lists them in the same order with `title` equal to the title's name, `detail` nil for the movie and "S2 E4" for the series, `progress` 0.42 and 0.78 within 0.01, `updatedAt` from the record, `itemID` equal to `TopShelfItemID.make(sourceID:titleID:)`, and a `tileFile` naming an existing PNG.

### AC-3a Triggers
Given the writer observing the app
When any one of these occurs: a `FavoriteRecord` is inserted, deleted or changed; a `SourceRecord` is deleted; the catalogue is rebuilt after a source finishes loading; `GuideStore.progressStream()` emits `.loaded`; the Continue watching list changes; 6 hours pass on the injected clock since the last completed write while the scene is active
Then exactly one write and one `topShelfContentDidChange()` call follow within 30 seconds on the injected clock.

### AC-3b Coalescing
Given a trigger at t = 0
When further triggers occur at t = 10, 20 and 40 seconds
Then writes happen at t = 30 and t = 70 and at no other time: the window starts at the first trigger, is not extended by later ones, and a trigger after it closes starts a new one. The number of `topShelfContentDidChange()` calls equals the number of completed writes.

### AC-3c Background
Given a pending window
When the scene enters the background
Then the write completes inside a background task before it expires, `topShelfContentDidChange()` is called once, and the pending window is cancelled.

### AC-4 Caps
Given 35 resolved favorites, 14 continue watching titles and 400 programmes per favorite channel in the guide
When the snapshot is written
Then `favorites` holds the first 20 in 0013/AC-8 order, `continueWatching` the first 10 by `updatedAt` descending, each channel's `programmes` only those overlapping `now` to `now + 12 h`, and `snapshot.json` is under 256 KB.

### AC-5 No secrets or URLs in the shared container
Given a catalogue with an M3U channel whose `id` embeds its stream URL with a query string credential, an Xtream channel, a logo URL with a username in it and a continue watching title with a poster URL
When the snapshot is written
Then the bytes of `snapshot.json` contain no `streamURL`, no `Channel.id`, no `logoURL`, no poster URL, no username or password, and no substring `://`; no `UserDefaults` key written by the writer contains a `Channel.id`; no file under `TopShelf/` other than PNGs and `snapshot.json` exists.

### AC-5a Stable item ids
Given a snapshot written with favorite Y under `itemID` i
When the snapshot is written again with Y still a favorite, then after Y was removed, then after Y was re-added
Then the second write keeps i for Y and overwrites `tiles/<i>.png` in place; the third write omits Y and deletes `tiles/<i>.png`; the fourth write gives Y the id i again.

### AC-6 Sections from a snapshot
Given a snapshot with favorites [Y (programmes 20:00 to 22:00 "Match of the Day", 22:00 to 23:30), X (no programmes)] and continue watching [M (0.42), S (0.78, "S2 E4")]
When `TopShelfContent.sections(from:now: 21:34)` runs
Then it returns two sections in order: `topShelf.section.favorites` titled "Favorites" with items `topShelf.item.<Y.itemID>` (title "<Y.name> · Match of the Day", `progress` 0.78 within 0.01, that is elapsed over duration clamped to 0...1) and `topShelf.item.<X.itemID>` (title "<X.name>", `progress` nil); then `topShelf.section.continueWatching` titled "Continue watching" with items titled "<M.title>" (`progress` 0.42) and "<S.title> · S2 E4" (`progress` 0.78); every item's `link` equals `TopShelfLink.url(for: itemID)` and its `tileFile` the snapshot's.

### AC-6a Guide exhausted
Given the snapshot of AC-6
When `sections(from:now:)` runs at 23:45, after Y's last programme stops
Then Y's item title is "<Y.name>" and its `progress` is nil.

### AC-6b One section
Given a snapshot with favorites and no continue watching, and one with continue watching and no favorites
When `sections(from:now:)` runs
Then the first yields only `topShelf.section.favorites` and the second only `topShelf.section.continueWatching`; neither yields `topShelf.emptyItem`.

### AC-6c Programme boundary
Given the snapshot of AC-6
When `sections(from:now:)` runs at 22:00 exactly
Then Y's item title names the 22:00 programme and its `progress` is 0 (start inclusive, stop exclusive, as 0014/AC-4).

### AC-7 Provider output
Given a snapshot and tiles in a temporary App Group directory injected into the provider
When `loadTopShelfContent(completionHandler:)` runs
Then the handler receives a `TVTopShelfSectionedContent` whose sections and items match AC-6 one to one: `TVTopShelfItemCollection.title`, `TVTopShelfSectionedItem.identifier`, `title`, `playbackProgress` (0 when `progress` is nil), `imageShape == .hdtv`, `imageURL(for: [.screenScale1x])` and `imageURL(for: [.screenScale2x])` both equal to the `file://` URL of the tile inside the injected directory, `playAction?.url` equal to `link`, and `displayAction` nil; a `URLProtocol` stub registered by the test that fails and records any request records none.

### AC-8 Empty item
Given a snapshot whose `favorites` and `continueWatching` are both empty and whose `unresolvedFavoriteCount` is 0
When `sections(from:now:)` runs
Then it returns one section `topShelf.section.favorites` titled "Favorites" with one item `topShelf.emptyItem` titled "Add favorites in Antenna to see them here", `progress` nil, `tileFile` `empty.png`, and `link` equal to `TopShelfLink.emptyURL`, which is `antenna://topShelf/empty` and for which `itemID(from:)` returns nil; the provider maps it with `displayAction` set to that link and `playAction` nil.

### AC-8a Nothing resolvable
Given a snapshot whose `favorites` and `continueWatching` are both empty and whose `unresolvedFavoriteCount` is above 0
When `sections(from:now:)` runs
Then it returns [] and the provider hands back nil content, so a user whose favorites all wait on a source is not told to add favorites.

### AC-9 No snapshot or malformed snapshot
Given no `snapshot.json`, an empty file, a file that is not JSON, a JSON document missing `favorites`, a snapshot whose `version` is above `currentVersion`, a snapshot whose `version` is below `currentVersion`, and a snapshot naming a `tileFile` that does not exist
When `TopShelfSnapshot.decode` and then the provider run on each
Then `decode` returns nil for the first six and the handler receives nil content for them; for the seventh the item is dropped and the rest of its section is returned, a section whose items are all dropped is omitted, and when both sections are omitted the handler receives nil content; `decode` does not throw and the provider calls no API that can trap on decoded values.

### AC-10 Link while the app runs
Given the shell on any tab, `shell.loading` included, a favorite resolving to channel C of source S, a Continue watching title T of source S, i = `TopShelfItemID.make(sourceID: S, channelID: C.id)` and j = `make(sourceID: S, titleID: T.id)`
When the app receives `onOpenURL` with `TopShelfLink.url(for: i)`
Then `ShellNavigator.tune(to:)` is called once with `LastChannelKey(sourceID: S, channelID: C.id)` and no other navigator call is made; with `url(for: j)` `play(titleID:sourceID:)` is called once with T's ids and no other navigator call is made. What the shell does next is 0015's (Appendix A-1, A-2).

### AC-10a Unknown or empty link
Given the running shell
When the app receives `antenna://topShelf/<uuid matching no current favorite or title>`, including an id that matched a favorite at the time the shelf was rendered and has since been removed (AC-5a's third write), `antenna://topShelf/empty`, or `antenna://topShelf/not-a-uuid`
Then no navigator call is made, no `load(_:)` is recorded, the selected tab is unchanged and no alert or `shell.empty` appears.

### AC-11 Link at cold launch
Given the app not running, a stored last channel L (0015/AC-8), and a favorite resolving to channel C of source S
When the app is launched with `TopShelfLink.url(for: TopShelfItemID.make(sourceID: S, channelID: C.id))` and S finishes loading 3 seconds later
Then the recording navigator receives exactly one `tune(to:)` with `LastChannelKey(sourceID: S, channelID: C.id)`, before the shell appears; what the shell does with the held request, including not tuning L and the single `load(_:)`, is Appendix A-3.

### AC-11a Link without entitlement or sources
Given no entitlement, or an entitlement and no `SourceRecord`, at launch or in the running app with the paywall or onboarding shown
When a shelf link arrives
Then the paywall (ADR-0006) or onboarding (0006/AC-1) is shown or stays as on a plain launch, and the link is discarded: after a purchase or an added source the shell launches per 0015/AC-2a or AC-2b with no `tune(to:)` call.

### AC-13 Tiles
Given favorites with a cached logo of 400 by 200 px, with a cached logo of 2000 by 300 px, and with no cached logo and name "Eurosport 1"; a continue watching title with a cached backdrop, one with only a cached poster and one with neither; and the empty tile
When tiles are composed
Then every PNG is 908 by 512 px; a logo is drawn centred, aspect preserved, inside a box of at most 60% of the tile's width and 60% of its height; the no-logo tile shows `Channel.initials(for:)` (0013/AC-7, "E1") centred in bold at 200 px; the backdrop fills its tile with aspect fill; a poster is centred with aspect fit inside the same 60% box; the title with neither shows its name centred at 60 px bold, wrapped to at most three lines and truncated with an ellipsis; the empty tile shows a star outline 200 px tall at 1.5 px line weight, centred. Dimensions, placement bounds and the fallback path taken are asserted; colours are the Design section's and are checked by the impl-reviewer.

### AC-14 Extension build
Given `project.yml`
When the project is generated and the tvOS scheme built
Then a target `AntennaTopShelf` of type `app-extension` for tvOS exists with `NSExtensionPointIdentifier` `com.apple.tv-top-shelf`, is embedded in `AntennaTV`, depends on the `AntennaCore` package and no other, has no asset catalog or bundled resource other than its Info.plist; both entitlement files declare `com.apple.security.application-groups` containing `group.se.codecrave.antenna` and `com.apple.developer.user-management` containing `runs-as-current-user`; and `AntennaTV`'s Info.plist declares `CFBundleURLSchemes` containing `antenna`.

### AC-15 Per-profile shelf
Given two tvOS profiles, each with its own favorites in the app
When the user switches profile and highlights Antenna
Then the shelf shows the current profile's favorites and nothing of the other's.

## Dropped

- AC-12 (removed favorite still on the shelf): the same inputs and layer as AC-10a's first case, now named there. The Edge cases entry on dangling ids stays.
- AC-3 is split into AC-3a, AC-3b and AC-3c; it bundled triggers, the window and the background write, and did not say whether the window was a debounce or a throttle.
- AC-6a's 22:00 case is AC-6c; two Whens hid two assertions.
- AC-11b (link abandoned): it restated the second sentence of Appendix A-3, which is a 0015 obligation, and contradicted A-3's Given by asserting no `tune(to:)` call.

## Appendix: criteria proposed for 0015

These are drafted here so that AC-10 and AC-11 have something to point at. They belong to 0015 and move there, with 0015's numbering, when this spec is accepted. They are not test obligations of this spec.

- A-1 `tune(to:)`. Given the shell on any tab with a loaded catalogue. When `ShellNavigator.tune(to: key)` is called and `key` resolves per 0013/AC-15. Then the fake engine records one `load(_:)` with that channel's URL and the shell shows `shell.player` as after `showLive()` (0015/AC-14c); a key that does not resolve makes no `load(_:)` call and changes nothing.
- A-2 `play(titleID:sourceID:)`. Given the shell on any tab. When `ShellNavigator.play(titleID:sourceID:)` is called for a title with a saved position. Then playback starts per 0011/AC-10a and leaving it returns per 0011's exit rule.
- A-3 Held request. Given `tune(to: key)` requested while the shell does not exist or while `key`'s source has not finished loading. When the shell appears and `key`'s source finishes loading within the 0015/AC-2b deadline. Then A-1 runs once and 0015/AC-2a's last-channel tune does not; if the deadline passes or the source finishes without the channel, the held request is dropped and 0015/AC-2a (deadline waived if its source has finished) or AC-2b applies, with one `load(_:)` in total.

## Edge cases and failure modes

- Offline: the extension reads files only, so the shelf is unaffected. The guide stops advancing when the snapshot's 12 hours run out (AC-6a) until the app runs again.
- Slow or huge source (tens of thousands of channels): the snapshot carries at most 20 channels and their 12 hours of programmes (AC-4); the writer reads the catalogue already built by 0013 and never iterates the full channel list. A write never blocks the main actor: composition and file IO run off it, and the atomic rename of `snapshot.json` is the last step so the extension never reads a partial file.
- Failed write (App Group container unavailable because the group is not provisioned, disk full, PNG encoding failure): the previous `snapshot.json` and tiles stay untouched, no `topShelfContentDidChange()` call is made, the error case name alone is logged, and the next trigger retries.
- Malformed data: AC-9. A programme with `stop <= start` is dropped by 0014/AC-6 before it reaches the writer; the core function also skips any such programme in a snapshot.
- App update that raises `currentVersion`: the old snapshot decodes to nil (AC-9) and the shelf is empty until the app's first run after the update rewrites it.
- Credential not yet synced: the source contributes no channels (0004/AC-10), so its favorites are in `unresolvedFavorites` (0013/AC-8), absent from the snapshot and counted in `unresolvedFavoriteCount`, which keeps the empty item away (AC-8a). They return when the credential arrives and the catalogue rebuilds (AC-3a).
- First launch with an empty store: no snapshot exists until every source has reached a terminal state once, so the shelf is empty (AC-9); after the first write with no favorites the empty item shows (AC-8).
- Sources still loading: no write happens until every source is terminal (AC-1a), so a small source finishing first never produces a shelf without the large source's favorites; the previous snapshot stays until then.
- App left in the foreground for a day: the 6 hour trigger in AC-3a keeps the 12 hour programme window ahead of the clock.
- Favorites added on another device: `FavoriteRecord` syncs through CloudKit (0005/AC-4) only while the Apple TV app runs. The shelf shows the state as of the app's last run on this Apple TV.
- Entitlement lapsed: the snapshot stays (ADR-0006 preserves favorites) and a shelf link lands on the paywall (AC-11a).
- Source deleted: its favorites leave the snapshot at the AC-3a write; their tiles are removed (AC-5a).
- Dangling id: a tile rendered before a favorite was removed links to an id that matches nothing; the app opens with no tune (AC-10a). If the favorite was re-added the id matches again (AC-5a) and the tune succeeds.
- Logo and poster URLs may carry credentials (AC-5's Given). Item ids are derived from `Channel.id` by hashing and no id, key or URL is persisted outside SwiftData for this feature (ADR-0002 adds no record, ADR-0003). If a cache miss is ever logged it is logged through 0014/AC-15's `redacted(_:)`.
- Programme titles and channel names are user data from the source and ship nowhere else; nothing in the extension bundle is content (DR-12, App Review 5.2.3). The empty item names the app's own feature and no provider.
- Time zones and clock changes: programme times in the snapshot are absolute dates; `sections(from:now:)` compares instants.
- VoiceOver: the system reads the item title; the title therefore carries the channel name first.

## Test plan

Snapshot decoding, `sections(from:now:)`, title and progress rules, item id derivation, link round trips and caps over fixture snapshots are swift-testing tests in AntennaCore. The writer runs against an in-memory `ModelContainer`, a fake catalogue, a fake `GuideStore`, a fake image cache, an injected clock, a temporary directory standing in for the App Group container and a recording `topShelfContentDidChange` hook. The provider mapping runs in the `AntennaTV` test bundle with the directory injected. Deep links use 0015's `-antenna.uiTest` launch arguments plus `-antenna.openURL <url>` fired on appear, with a fake engine and a recording `ShellNavigator`. Profiles and the rendered shelf are checked on a device.

| Criterion | Layer | Test |
|-----------|-------|------|
| AC-1 | integration (writer, fake catalogue, guide store and image cache) | TBD |
| AC-1a | integration (writer, fake sources with completion delay, injected clock) | TBD |
| AC-2 | integration (writer, fake continue watching list) | TBD |
| AC-3a | integration (writer, injected clock, parameterised over triggers) | TBD |
| AC-3b | integration (writer, injected clock) | TBD |
| AC-3c | integration (writer, fake scene phase) | TBD |
| AC-4 | integration (writer) + core (snapshot size over a fixture) | TBD |
| AC-5 | integration (writer, byte scan of the written file, defaults and directory listing) | TBD |
| AC-5a | integration (writer, four writes) | TBD |
| AC-6 | core (`TopShelfContent`) | TBD |
| AC-6a | core (`TopShelfContent`) | TBD |
| AC-6b | core (`TopShelfContent`) | TBD |
| AC-6c | core (`TopShelfContent`) | TBD |
| AC-7 | integration (provider mapping with injected directory and a `URLProtocol` stub) | TBD |
| AC-8 | core + integration (provider mapping) | TBD |
| AC-8a | core + integration (provider mapping) | TBD |
| AC-9 | core (`decode`, parameterised) + integration (provider mapping) | TBD |
| AC-10 | ui (shell with launch arguments, recording navigator; on a content tab and on `shell.loading`) | TBD |
| AC-10a | ui (parameterised over the four URLs) | TBD |
| AC-11 | ui (fake sources with completion delay, injected defaults, recording navigator) | TBD |
| AC-11a | ui (no entitlement; no sources; cold launch and running app) | TBD |
| AC-13 | integration (tile composer, dimensions and fallback path) | TBD |
| AC-14 | integration (parse `project.yml`, the entitlement plists and Info.plist) + tvOS build in CI | TBD |
| AC-15 | device | manual, two profiles on Apple TV 4K |

## Open questions

- Empty state: this spec shows one instructional item (AC-8). The alternative is returning nil content so the shelf is blank. The item helps discovery; the blank shelf is what Apple's own guidance suggests when there is nothing to show.
- Title shape: "<name> · <programme>" puts the channel first so truncation eats the programme title. The alternative is programme title only, relying on the logo tile for identity, which fails for logo-less channels with the same initials.
- Progress on favorite tiles reuses the system's playback progress bar for programme progress (DR-7). Some users may read it as a watch position.
- Caps of 20 favorites and 10 titles and a 12 hour programme window are guesses. The snapshot stays small at these values; raise them if device testing shows the shelf scrolls comfortably.
- The 30 second throttle trades shelf freshness against disk writes during a favorites editing session. A background write is immediate.
- `runs-as-current-user` on an extension: assumed to give a per-profile App Group container. If a device test shows a shared container, the snapshot needs a per-profile key, which needs 0033.
- Should a shelf link to a channel also commit its group as current (0007/AC-22)? This spec leaves the current group untouched.
- Removing the snapshot when the entitlement lapses: this spec keeps it. The paywall is reached either way.
- A pure-Swift SHA-256 in AntennaCore is about a hundred lines to keep ADR-0005's Foundation-only rule. The alternative is to let the App Group ADR amend that rule and import CryptoKit.
- Item ids are a hash of `Channel.id`. For M3U channels without `tvg-id` that id is positional (0001), so a playlist reorder changes the id and dangles any tile rendered before the next write. Same limitation as favorites themselves (0005 edge cases).
