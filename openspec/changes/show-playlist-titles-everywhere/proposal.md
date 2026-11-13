# Proposal

## Why

> As a viewer whose only source is a playlist with movies and shows, I want to find them on my iPad, my Mac and my Apple TV the way I do on my iPhone.

`add-m3u-vod-fallback` and `add-m3u-series` put a playlist's movies and episodes in Movies and Series, but only the iPhone tab bar and the Apple TV tab bar learned to show them. The iPad and Mac sidebar still hides Movies and Series without an Xtream source, Search on every platform hides the Movies and Series chips, the "Open on launch" preference does not offer Movies, the last session's Movies or Series tab reopens as Live, and a Top Shelf tile for a playlist movie waits for titles that never load. On Apple TV a playlist with episodes and no movies shows a Movies tab with nothing in it.

After this change every screen uses one rule. Titles show with an Xtream source, or with a playlist whose last load had movies or episodes. A playlist with only episodes shows Series without an empty Movies section.

## What Changes

- The iPad and Mac sidebar shows Movies when a source has movies and Series when a source has series, playlists included.
- Search shows the Movies and Series chips on iPhone, iPad, Mac and Apple TV when a playlist has titles.
- "Open on launch" offers Movies with a playlist that has titles, and the app reopens on Movies or Series when the user left it there.
- The Apple TV tab bar shows Movies only when a source has movies and Series only when a source has series. An Xtream source shows both, as before.
- What the last load of each playlist had is remembered on the device, so the tabs and the launch screen are right before the playlist loads again.
- Top Shelf links to a playlist movie or episode open it, as they do for Xtream titles.
- Siri and Shortcuts find playlist titles when the app is not running.

Out of scope:
- Hiding Movies or Series for an Xtream source that has none; the provider can add titles at any time.
- New screens or board changes.

## Capabilities

### New Capabilities

None.

### Modified Capabilities
- `m3u-playlists`: playlist titles show on every platform's Movies, Series, Search, launch preference, session restore and Top Shelf, and a playlist with only episodes shows Series without Movies.

## Impact

- Platforms: iOS, iPadOS, macOS, tvOS.
- Depends on: `add-m3u-vod-fallback`, `add-m3u-series` and `tighten-playlist-entry-kinds` (archived).
- Data: no schema change. Two counts per source (movies and episodes from the last load) join the last load time in `UserDefaults`; no link or login.
- Blocked on: nothing.
