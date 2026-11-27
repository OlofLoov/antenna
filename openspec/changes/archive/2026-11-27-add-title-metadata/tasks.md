Narrowed on 2026-11-27: the owner declined the lookup service on 2026-11-19. Tasks 2.1, 2.3, group 3, 4.1, 4.5, 5.5, 6.3, 6.4 and groups 7 and 8 moved to the parked change `title-lookups-later`, which lists them under their old numbers.

## 1. Proposal and boards

- [x] 1.1 Write the proposal, delta specs, design and tasks, and validate with `openspec validate add-title-metadata --strict`
- [x] 1.2 Draw `iPhone-Title-Scores`, `iPad-Title-Scores`, `TV-Title-Scores`, `iPhone-Settings-Lookups` and `TV-Settings-Lookups`

## 2. Names in AntennaCore

- [x] 2.2 Add `TitleName.clean(_:)` with fixtures of real provider names (language tags, years, quality words), citing `title-metadata/a-title-is-matched-by-its-database-id-first`

## 4. Lookup protocol and cache

- [x] 4.2 Add the per-source cache file with the seven-day refresh and 180-day cap, removal on source delete, with tests citing `title-metadata/matches-are-kept-on-the-device`
- [x] 4.3 Merge database details under provider details in `TitleMetadata`, citing `title-metadata/details-the-provider-left-out-come-from-the-database`
- [x] 4.4 Add the `TitleLookup` protocol, the `KeptTitleLookup` decorator and a Debug-only `MockTitleLookup` with stable sample scores and the Sample label, selected by `-mock-title-scores YES` or the Debug Sample scores switch, and a `scripts/check-rules.sh` check that fails when the mock is named outside `#if DEBUG` (design.md decision 8)

## 5. Title page

- [x] 5.1 Add `ScoreRow` with previews on iPhone, iPad, Mac and Apple TV, and show it on the title page below the buttons
- [x] 5.2 Drop the provider rating from the details line when scores show, citing `title-detail-and-episode-picker/what-the-title-is-about`
- [x] 5.3 Look a title up when its page opens, never block Play, show kept results at once, citing `title-metadata/a-slow-or-failing-lookup-never-holds-up-the-page` and `title-detail-and-episode-picker/scores-from-other-sites`
- [x] 5.4 UI tests on iPhone and Apple TV with a stubbed lookup: the score row shows, focus order on Apple TV is unchanged

## 6. Settings

- [x] 6.1 Add `lookupsEnabled` to `PreferencesRecord` and `AppPreferences`, the switch and footer under Preferences, citing `sources-and-settings/a-switch-for-movie-database-lookups`
- [x] 6.2 Turning lookups off stops requests and deletes the cache, citing `title-metadata/lookups-can-be-turned-off`

## 9. Verify

- [x] 9.1 Each requirement has a test citing `<capability>/<requirement-slug>`, and `scripts/check-spec-refs.sh` passes
- [x] 9.2 `/opsx:verify` passes
