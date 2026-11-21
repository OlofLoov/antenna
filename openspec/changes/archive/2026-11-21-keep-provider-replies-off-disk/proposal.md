# Keep provider replies off disk

## Why

A household setter-upper types an Xtream or playlist login once and
expects it to live in the Keychain and nowhere else. A review found that
panel calls, playlist downloads and Jellyfin calls went through the
system's shared web session. Its cache wrote replies to
`Caches/<app>/Cache.db` keyed by the full address, and an Xtream address
holds `password=` in its query. Anyone with a copy of the app's caches,
such as an unencrypted Mac backup, could read the login. After this
change no reply to a request that carries a login is written to disk,
and what earlier versions wrote is removed on the first launch.

## What Changes

- Every request that can carry a provider login goes through one session
  with no URL cache: Xtream panel calls, M3U link downloads, connecting a
  source, catch-up time zone lookups and Jellyfin calls. Stalker, Channels
  DVR, the guide and playback already had such sessions.
- The first launch of this version empties the shared URL cache once on
  iPhone, iPad, Mac and Apple TV.
- `scripts/check-rules.sh` fails when code outside the poster and logo
  caches uses the shared session.

Out of scope:
- Posters and channel logos stay on the shared cache. Their addresses come
  from the provider's lists and do not carry the account login, and Now
  Playing and Top Shelf read artwork from that cache.
- Stream addresses, which already play through sessions with no cache.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `source-management`: adds "Provider replies are not kept on disk".

## Impact

- `URLSession.provider` in AntennaCore, used by `XtreamClient` and
  `JellyfinClient` by default and by the app's loaders and connector.
- `ProviderCachePurge` in the app, run from `AntennaApp.init`.
- No data model, sync or dependency change.
