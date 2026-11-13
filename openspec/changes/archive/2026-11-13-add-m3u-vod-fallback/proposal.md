# Proposal

## Why

> As a viewer with a plain M3U playlist that lists movies next to its channels, I want the movies in Movies, not mixed into my live channel list.

Many playlists that are not Xtream panels still list on-demand files: `/movie/` links, `.mp4` and `.mkv` files, groups named "VOD | Action" or "Movies". Antenna treats every entry as a live channel, so movies sit between news channels in Live and there is no Movies tab. After this change those movies leave Live and show in Movies with the same rows, grid, banner and title page as an Xtream library.

## What Changes

- Sort each playlist entry as a live channel, a movie or a series episode, from its link, name and group.
- Movies leave the playlist's live channels, on every platform and in the onboarding checklist count.
- The Movies section lists a playlist's movies, with the entry's logo as the poster and its group as the category, and plays them from their link.
- The Movies tab on iPhone and on Apple TV shows when a playlist's last load had movies.

Out of scope:
- Series from a playlist. Episodes are recognized but stay in Live until a later change groups them into series with seasons.
- Details beyond the name, poster and category: playlists carry no year, plot or rating.
- Turning the sorting off per source.

## Capabilities

### New Capabilities

None.

### Modified Capabilities
- `m3u-playlists`: entries are sorted into live channels, movies and episodes; movies leave the live channels and show in Movies.

## Impact

- Platforms: iOS, iPadOS, macOS, tvOS.
- Depends on: `m3u-playlists`, `add-movies-and-series-browsing` (the Movies section and title page), `add-xtream-panel-links` (a panel link can still become Xtream for its full library).
- Data: no schema change. A favorite of a playlist entry that is now a movie no longer matches a live channel.
- Blocked on: nothing.
