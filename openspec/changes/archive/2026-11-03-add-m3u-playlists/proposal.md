## Why

Most users arrive with an M3U playlist link from a provider. The format is loosely specified: attribute quoting, group tags and catch-up hints vary by panel. The app has to turn any of these into a stable list of channels fast enough that playlists with tens of thousands of entries do not stall the UI. This serves the new user who wants "to add my IPTV subscription (a playlist link or provider login) in a few steps, so I am watching within minutes of installing" and the user with several subscriptions who wants "them merged into one channel list and one guide".

Written after the fact. It records behavior shipped in commit 082034b so later changes have a spec to revise.

## What Changes

- Read the `#EXTM3U` header attributes `url-tvg` and `x-tvg-url`, comma-separated.
- Read the `#EXTINF` attributes `tvg-id`, `tvg-name`, `tvg-logo`, `tvg-chno`, `group-title`, `catchup`, `catchup-days` and `tvg-rec`, quoted or unquoted, names matched without case, last duplicate winning.
- Use `#EXTGRP` as a group fallback.
- Derive stable, unique channel ids from each entry.
- Ignore unknown directives without losing the pending entry.

Out of scope:
- Downloading the playlist or importing a local file.
- `#EXTVLCOPT` and `#KODIPROP` headers such as user agent or referrer.
- Gzip or other compressed playlists.
- Classifying entries as live, movie or series.
- Deduplicating entries that share a URL.

## Capabilities

### New Capabilities
- `m3u-playlists`: parse an M3U playlist into channels and guide links.

### Modified Capabilities

## Impact

- AntennaCore: `M3UParser`, `Playlist`, `Channel`.
- The guide links the parser returns were discarded by the app until the `guide-data` capability used them.
