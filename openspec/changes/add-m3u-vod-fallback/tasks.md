# Tasks

## 1. Sorting in AntennaCore

- [x] 1.1 Add `PlaylistEntryKind`, `Playlist.separatingMovies()` and `ShelfCatalogue(playlistMovies:sourceID:)`, and verify core tests citing `m3u-playlists/movies-and-episodes-in-a-playlist-are-recognized`, `m3u-playlists/playlist-movies-stay-out-of-live-channels` and `m3u-playlists/playlist-movies-show-in-movies`

## 2. Movies in the app

- [x] 2.1 Separate movies on every playlist load and keep them in memory for the shelf, and verify an integration test citing `m3u-playlists/playlist-movies-stay-out-of-live-channels`
- [x] 2.2 Load, show and play playlist movies in Movies, and show the tab on iPhone and Apple TV, and verify an integration test citing `m3u-playlists/playlist-movies-show-in-movies`
- [x] 2.3 Run the Movies and Live UI test classes on local simulators

## 3. Verify

- [x] 3.1 Each requirement has a test citing `<capability>/<requirement-slug>`
- [x] 3.2 `/opsx:verify` passes
