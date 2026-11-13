# Tasks

## 1. Series in AntennaCore

- [ ] 1.1 Add `EpisodeName`, `PlaylistSeries` and `Playlist.separatingOnDemand()`, count episodes in `SourceStatus`, and verify core tests citing `m3u-playlists/playlist-episodes-group-into-series` and `m3u-playlists/playlist-movies-stay-out-of-live-channels`

## 2. Series in the app

- [ ] 2.1 Keep playlist episodes and series in memory, load and play them in Series, and show the tabs, and verify an app test citing `m3u-playlists/playlist-series-show-in-series` and `m3u-playlists/playlist-movies-show-in-movies`
- [ ] 2.2 Run the Movies, Series and Title UI test classes on a local iPhone simulator

## 3. Verify

- [ ] 3.1 Each requirement has a test citing `<capability>/<requirement-slug>`
- [ ] 3.2 `/opsx:verify` passes
