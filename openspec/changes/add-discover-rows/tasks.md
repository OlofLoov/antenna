## 1. Proposal and boards

- [x] 1.1 Write the proposal, delta specs, design and tasks, and validate with `openspec validate add-discover-rows --strict`
- [x] 1.2 Draw `iPhone-Movies-Discover`, `iPad-Movies-Discover`, `TV-Movies-Discover`, `iPhone-Live-New`, `iPad-Live-New` and `TV-Overlay-New`

## 2. Recently watched and See all (no external data)

- [ ] 2.1 Add `RecentlyWatched.list` in AntennaCore with tests citing `movies-and-series-browsing/recently-watched`
- [ ] 2.2 Add the Recently watched row to Movies and Series on every platform, in the order of `movies-and-series-browsing/rows-in-a-predictable-order`, with previews
- [ ] 2.3 Add See all on Recently added opening the grid newest first, citing `movies-and-series-browsing/see-everything-new`
- [ ] 2.4 UI tests on iPhone and Apple TV: Recently watched shows a finished movie; See all opens the grid and Menu closes it on Apple TV
- [ ] 2.5 Add journey steps for the rows anchored on `movies.row.recentlyWatched`

## 3. New channels (no external data)

- [ ] 3.1 Add the seen-channels memory and `NewChannels.group` in AntennaCore, with tests citing `new-channels/a-new-group-lists-channels-added-lately`, `new-channels/a-new-source-starts-with-nothing-new`, `new-channels/what-new-remembers-stays-on-the-device` and `new-channels/renamed-and-moved-channels-are-not-new`
- [ ] 3.2 Record seen channels on each source load, forget them on source delete, and add the New group to the iPhone chips, the iPad and Mac sidebar and the Apple TV overlay
- [ ] 3.3 UI tests on iPhone and Apple TV with a fixture source that gains a channel between two loads
- [ ] 3.4 Add a journey step for the New group anchored on `groups.new`

## 4. Trending (needs add-title-metadata)

- [ ] 4.1 Add `/v1/trending` to the lookup service with a one-day cache
- [ ] 4.2 Add `TrendingMatch.titles` in AntennaCore with fixtures of ids, tagged names, years and duplicates, citing `movies-and-series-browsing/trending-in-your-sources`
- [ ] 4.3 Fetch, keep for seven days, and show the Trending row on every platform; no fetch and no row with lookups off
- [ ] 4.4 UI tests on iPhone and Apple TV with a stubbed trending list: only matching titles show, focus lands on the first poster
- [ ] 4.5 Add a journey step anchored on `movies.row.trending`

## 5. Verify

- [ ] 5.1 Each requirement has a test citing `<capability>/<requirement-slug>`, and `scripts/check-spec-refs.sh` passes
- [ ] 5.2 `/opsx:verify` passes
