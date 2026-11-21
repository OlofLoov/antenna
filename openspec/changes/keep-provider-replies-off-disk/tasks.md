## 1. No cache for provider requests

- [x] 1.1 `URLSessionConfiguration.provider` and `URLSession.provider` in AntennaCore, ephemeral with no URL cache
- [x] 1.2 `XtreamClient` and `JellyfinClient` default to it; `SourceLoader`, `ShelfLoader`, `SourceConnector`, `CatchupAddresses`, `JellyfinClients` and onboarding's `SourceSetup.live` use it
- [x] 1.3 A core test against a local panel proves a login call leaves nothing in the shared cache, and that a caching session would have kept it
- [x] 1.4 `scripts/check-rules.sh` refuses the shared session outside the poster and logo caches

## 2. Remove what earlier versions cached

- [x] 2.1 `ProviderCachePurge` empties the shared URL cache once, from `AntennaApp.init`, with a `UserDefaults` flag, with an app unit test

## 3. Verify

- [x] 3.1 Each requirement this change adds has a test citing `source-management/provider-replies-are-not-kept-on-disk`
- [x] 3.2 /opsx:verify passes
