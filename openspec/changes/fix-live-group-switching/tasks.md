# Tasks

## 1. Fix

- [x] 1.1 `Catalogue` stores its group list and a `revision`; `CataloguePolicy` stores the locks that apply now
- [x] 1.2 `LiveBrowsingPerformanceTests`: a group move, the guide for the rows on screen and a favorite over 50 000 channels, under CI budgets (tv-channel-overlay/picking-a-group-shows-its-channels)
- [x] 1.3 The overlay's columns declare where focus enters them, and the group column scrolls to the shown group
- [x] 1.4 `OverlayChannelList`, one per group, equatable on catalogue revision, group and entry row
- [x] 1.5 `LogoCache` and `LogoImage` in place of `AsyncImage` for channel logos on every platform
- [x] 1.6 Favorites on Apple TV swap into the catalogue without indexing the channels again; an unchanged reload leaves `channels` alone
- [x] 1.7 The chips row is lazy; catalogue builds and logo downloads are signposted
- [x] 1.8 `-ui-testing-large-catalogue` and `ChannelOverlayLargeUITests`

## 2. Verify

- [x] 2.1 Each requirement has a test citing `<capability>/<requirement-slug>`
- [x] 2.2 `ChannelOverlayUITests`, `ChannelOverlayLargeUITests`, `GuideUITests` and `ZapBarUITests` pass on a tvOS simulator; `LiveUITests` on an iPhone simulator
- [x] 2.3 `/opsx:verify` passes
