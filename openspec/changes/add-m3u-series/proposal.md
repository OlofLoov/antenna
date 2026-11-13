# Proposal

## Why

> As a viewer with a playlist that lists every episode of a show, I want the show in Series with its seasons, not hundreds of episode rows in my live channel list.

`add-m3u-vod-fallback` recognizes playlist episodes (a `/series/` link or an "S01E02" marker in the name) but leaves them in Live, one row per episode. A playlist with a few shows buries the channels. After this change the episodes leave Live and show as series in the Series part of Movies, with the same title page and episode picker an Xtream series has.

## What Changes

- Episodes of a playlist leave its live channels, as movies already do.
- Episodes group into series by the show name read from the entry name, with the season and episode numbers from its "S01E02" marker.
- The Series section lists a playlist's series with the first episode's logo as the poster and its group as the category. The title page shows the seasons and episodes, and an episode plays from its link.
- The Movies tab on iPhone and the Movies and Series tabs on Apple TV show when a playlist's last load had movies or episodes.

Out of scope:
- Episode names in other forms, such as "1x02" or "Season 1 Episode 2".
- Plot, year, rating and backdrop for playlist series: the playlist has none.
- Merging a playlist series with the same show from another source.

## Capabilities

### New Capabilities

None.

### Modified Capabilities
- `m3u-playlists`: episodes leave the live channels and group into series shown in Series.

## Impact

- Platforms: iOS, iPadOS, macOS, tvOS.
- Depends on: `add-m3u-vod-fallback` and `tighten-playlist-entry-kinds` (archived), which recognize episodes; `add-title-detail-and-episode-picker`, whose title page and episode picker show the series.
- Data: no schema change. Series and episode ids are built from names and hold no link. A favorite of an episode in Live no longer matches a channel.
- Blocked on: nothing.
