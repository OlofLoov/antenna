## Why

Xtream providers expose movies and series through five more `player_api.php` actions. Browsing them needs categories, lists, per-title details, episodes and playable links, with stable ids and tolerant decoding, and none of it existed. This serves the movie and series watcher who wants "to browse my provider's movies and series with posters and details, like a streaming app", and the series watcher who wants "to pick a season and episode and see what each one is about".

## What Changes

- Movie and series category lists, title lists, movie details and series details with episodes.
- Pure decode functions over response data and the server host, so lists and details can be tested without a network.
- Raw numeric ids for requests and links, and title ids (`xtream#<host>#vod#<id>`, `#series#`, `#episode#`) for storage and identity across devices, with parsing back.
- Playable links for movies and episodes.
- Tolerant decoding: loose types, strict whole-number integers, skipping broken and duplicate rows, never crashing.
- Every Xtream call, live included, reports refused logins, transport failures and decoding failures as typed errors that carry no credentials or URLs. **BREAKING** for `xtream-live-source` callers: 401 and 403 now report a refused login, and decoding failures no longer surface as raw decoder errors.
- The account info gains an `auth` field.

Out of scope:
- Any UI, caching and images.
- Movies from M3U playlists.
- Catch-up and timeshift links.
- Stalker.
- Interpreting `user_info.status` ("Disabled", "Expired").
- How callers show cancellation.
- A logger in AntennaCore; the app applies the guide's redaction when it logs.

## Capabilities

### New Capabilities
- `xtream-vod-client`: list and decode an Xtream provider's movies, series and episodes.

### Modified Capabilities

## Impact

- `xtream-live-source`: refused logins, decoding errors, strict integers, broken-row skipping and credential encoding now follow this change. Both capabilities were written up together after the fact, so the live requirements state the result directly and no delta is kept here.
- AntennaCore: `XtreamClient` gains six calls and four decode functions; new `VODItem`, `VODInfo`, `Series`, `SeriesInfo`, `Episode`, `DecodedList` and `XtreamTitleID`; `XtreamError` gains `unauthorized`, `transport` and `decoding`.
- Depends on `xtream-live-source`. Consumed by `add-first-run-onboarding`, `add-movies-and-series-browsing`, `add-search` and `guide-data`, none of which block it.
