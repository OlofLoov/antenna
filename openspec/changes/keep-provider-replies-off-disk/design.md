# Design

## Context

`SourceLoader`, `ShelfLoader`, `SourceConnector`, `CatchupAddresses`,
`JellyfinClients`, onboarding's `SourceSetup.live`, `XtreamClient` and
`JellyfinClient` defaulted to `URLSession.shared`. Nothing set up
`URLCache.shared`, so it ran at the system default (512 KB in memory,
20 MB on disk). A localhost experiment showed a `player_api.php` reply
with no cache headers stored in `Cache.db` with the full address,
password included, as `request_key`. Replies up to about 1 MB qualify:
`get_vod_info`, `get_series_info`, category lists, account info and
small `get.php` playlists.

The guide, Stalker, Channels DVR and playback already used ephemeral
sessions with `urlCache = nil`.

No screen changes, so no board applies.

## Decisions

### One provider session

Options:
1. Set `URLCache.shared` to memory only at launch. Every request in the
   process would still be cached in memory, posters would lose their disk
   cache, and the rule would depend on launch order.
2. Set `cachePolicy` per request in `XtreamClient` and the loaders. Easy
   to miss on the next call site.
3. One `URLSession.provider` in AntennaCore, ephemeral with `urlCache =
   nil` and `.reloadIgnoringLocalCacheData`, and every login-carrying
   request defaults to it.

Chosen: 3. It matches the guide and Stalker sessions. Cookies stay in
memory for the run (ephemeral storage), as some panels behind a proxy
set one between calls. Timeouts stay at the system defaults the shared
session had, so slow panels behave as before.

### What keeps the shared session

`PosterCache` and `LogoCache`. Poster and logo addresses come from the
provider's lists and carry no account login, and `NowPlaying` and
`TopShelfWriter` read artwork from `URLCache.shared`. The rules check
allows only those two files.

### Removing the old cache

`ProviderCachePurge.run()` calls `URLCache.shared.removeAllCachedResponses()`
once and records `sources.providerCachePurged` in `UserDefaults.standard`.
Running it on every launch would also drop the posters the cache holds
for Now Playing and Top Shelf. It runs in `AntennaApp.init`, before any
screen loads, on all four platforms.

### Pinning it

`ProviderSessionTests` runs `XtreamClient` with its default session
against `FixtureServer` and checks that `URLCache.shared` holds nothing
for the address the server saw. Run with `.shared`, the same test fails.
A second test runs a session with a cache against the same panel and
finds the reply, so the first test would see a stored reply if there
were one. `scripts/check-rules.sh` refuses `URLSession.shared`,
`URLSession = .shared` and `session: .shared` outside `PosterCache.swift`
and `LogoCache.swift`.
