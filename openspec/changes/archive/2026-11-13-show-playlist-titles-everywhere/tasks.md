# Tasks

## 1. One title offer

- [x] 1.1 Add `TitleOffer` and `TitleCounts`, store counts in `LastLoadStore`, read them in `SourceRefresher.status(of:)`, and verify app tests citing `m3u-playlists/movies-and-series-show-by-what-the-sources-offer` and `m3u-playlists/what-a-playlist-offered-is-remembered`

## 2. Every screen reads it

- [x] 2.1 iPhone tabs, iPad and Mac sidebar, restore and launch, Settings "Open on launch", and Search chips use the offer; replace `ShelfLibrary.hasXtream` with `ShelfLibrary.offer`
- [x] 2.2 Apple TV tab bar shows Movies and Series by their own offer, launch and Browse movies open Series when Movies is not offered, and Top Shelf links wait for playlist titles
- [x] 2.3 Siri and Shortcuts load playlist titles without a running library, and a playlist title's reference parses, with an app test citing `m3u-playlists/playlist-titles-show-on-every-platform`
- [x] 2.4 Add UI tests on iPad (sidebar with a playlist) and Apple TV (Series tab and a Search result with an episodes-only playlist), and run the touched UI test classes on local iPad and Apple TV simulators

## 3. Verify

- [x] 3.1 Each requirement has a test citing `<capability>/<requirement-slug>`
- [x] 3.2 `/opsx:verify` passes
