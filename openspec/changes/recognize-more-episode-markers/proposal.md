# Proposal

## Why

> As a viewer with a playlist of shows, I want episodes named "Show 1x02" to land in Series like the ones named "S01E02", so I can pick a season and an episode instead of finding them in Movies.

Many playlists write the season and episode as "1x02" or "01x02", and some spell it out as "Season 1 Episode 2". The app reads only "S01E02", so those entries show up as movies, one poster per episode. After this change they group into series with their seasons and numbers.

## What Changes

- "1x02", "01x02" and "1x102" in an entry name mark an episode, as "S01E02" does.
- "Season 1 Episode 2", "Season 1, Ep 2" and similar spellings mark an episode too.
- Names that only look like a crossed number, such as "4x4 Off-Road", "24x7" or "1920x1080", stay what they were.

Out of scope:
- "Ep 2" or "Episode 2" with no season. These entries stay movies or live channels.
- Xtream series, which come with their seasons and episodes from the panel.
- Moving entries that are already sorted on a device. They move on the playlist's next load.

## Capabilities

### New Capabilities

None.

### Modified Capabilities
- `m3u-playlists`: a new requirement names the season and episode markers the playlist rules read.

## Impact

- Platforms: iOS, iPadOS, macOS, tvOS. AntennaCore only, no app code.
- Depends on: `m3u-playlists` requirements "Movies and episodes in a playlist are recognized" and "Playlist episodes group into series", which use the marker.
- Data: none. The last-load counts a playlist remembers update on its next load.
