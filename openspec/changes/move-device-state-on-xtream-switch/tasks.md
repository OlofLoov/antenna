# Tasks

## 1. Rewrites in AntennaCore

- [ ] 1.1 Add the id rewrites to `RecentChannels`, `LastChannelKey`, `LanguageMemory` and `GuideSettings`, and verify core tests citing `source-management/switching-to-xtream-keeps-what-was-remembered-per-channel`

## 2. The switch

- [ ] 2.1 Move recents, the last channel and language picks for every profile, and guide matches, in `switchToXtream`, and verify an app test citing `source-management/switching-to-xtream-keeps-what-was-remembered-per-channel`
- [ ] 2.2 Run the Settings UI test classes on a local iPhone simulator

## 3. Verify

- [ ] 3.1 Each requirement has a test citing `<capability>/<requirement-slug>`
- [ ] 3.2 `/opsx:verify` passes
