# Proposal

## Why

> As a viewer whose news channel streams from a link ending in `.mp4`, I want it to stay in Live, not show up in Movies.

Since `add-m3u-vod-fallback`, a playlist entry whose link ends in a video file extension is a movie. Some providers serve live channels, and looping 24/7 channels, from `.mp4` links. Those channels left Live and showed in Movies as titles that never end. After this change an entry that looks live in any other way stays in Live, and only a stronger on-demand sign moves it.

## What Changes

- An entry with catch-up attributes, a guide id, a group named like a live group (News, Sports, Live, 24/7), or an `#EXTINF` duration of -1 or 0 stays live, even when its link ends in `.mp4`, `.mkv`, `.avi`, `.mov` or `.m4v`.
- A `movie` or `series` folder in the link, a season and episode marker in the name, or a VOD, Movies or Films group still decides, whatever the live signs say.
- The file extension decides only for an entry with no live sign.

Out of scope:
- Checking a guide id against the loaded guide. The playlist is sorted before the guide arrives.
- A per-source or per-entry switch to move an entry by hand.

## Capabilities

### New Capabilities

None.

### Modified Capabilities
- `m3u-playlists`: the order of the rules that sort an entry into live channel, movie or episode.

## Impact

- Platforms: iOS, iPadOS, macOS, tvOS.
- Depends on: `add-m3u-vod-fallback` (archived), which added the sorting.
- Data: no schema change. Entries that were movies and are now live show in Live again, with their favorites.
- Blocked on: nothing.
