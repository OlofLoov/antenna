# Tasks

## 1. Sorting in AntennaCore

- [ ] 1.1 Keep the `#EXTINF` duration on each parsed channel, in memory only
- [ ] 1.2 Reorder `PlaylistEntryKind` with the live signs gating the extension rule, and verify core tests citing `m3u-playlists/movies-and-episodes-in-a-playlist-are-recognized`, including a fixture where a news channel's link ends in `.mp4`

## 2. Verify

- [ ] 2.1 Each requirement has a test citing `<capability>/<requirement-slug>`
- [ ] 2.2 `/opsx:verify` passes
