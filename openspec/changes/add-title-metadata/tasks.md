## 1. Proposal and boards

- [x] 1.1 Write the proposal, delta specs, design and tasks, and validate with `openspec validate add-title-metadata --strict`
- [x] 1.2 Draw `iPhone-Title-Scores`, `iPad-Title-Scores`, `TV-Title-Scores`, `iPhone-Settings-Lookups` and `TV-Settings-Lookups`

## 2. Ids and names in AntennaCore

- [ ] 2.1 Decode `tmdb`, `tmdb_id` and `imdb_id` on movie and series rows and in the info body, with fixture tests citing `xtream-vod-client/movie-database-ids`
- [x] 2.2 Add `TitleName.clean(_:)` with fixtures of real provider names (language tags, years, quality words), citing `title-metadata/a-title-is-matched-by-its-database-id-first`
- [ ] 2.3 Add `TitleMatch.pick(_:name:year:)` and a shared fixture set of search results, citing `title-metadata/a-title-is-matched-by-its-database-id-first`

## 3. The lookup service

Blocked on `add-aws-hosting` task group 6: the account, the API stack, the WAF web ACL and the deploy workflow.

- [ ] 3.1 Confirm `add-aws-hosting` task 6.2 amended the "no server of our own" line in `openspec/config.yaml` and CLAUDE.md, after the owner's answer to open question 1
- [ ] 3.2 Add `Services/lookup/`: the Lambda with `/v1/match`, the matching rule from 2.3 run on the same fixtures, and unit tests
- [ ] 3.3 Add the lookup Lambda, its routes, its Secrets Manager key and a one-day CloudFront cache behavior for `/v1/match*` and `/v1/trending*` to the `AntennaApi` stack in `Infra/` from `add-aws-hosting`, with the handler logging no query, body or caller
- [ ] 3.4 Add the lookup service and TMDB to `docs/architecture/c4-context.drawio.svg` and `c4-container.drawio.svg`

## 4. Lookup client and cache

- [ ] 4.1 Add the lookup client in AntennaCore: request building that carries only name, year and ids, response decoding, with tests citing `title-metadata/only-what-is-needed-is-looked-up`
- [x] 4.2 Add the per-source cache file with the seven-day refresh and 180-day cap, removal on source delete, with tests citing `title-metadata/matches-are-kept-on-the-device`
- [x] 4.3 Merge database details under provider details in `TitleMetadata`, citing `title-metadata/details-the-provider-left-out-come-from-the-database`
- [x] 4.4 Add the `TitleLookup` protocol, the `KeptTitleLookup` decorator and a Debug-only `MockTitleLookup` with stable sample scores and the Sample label, selected by `-mock-title-scores YES` or the Debug Sample scores switch, and a `scripts/check-rules.sh` check that fails when the mock is named outside `#if DEBUG` (design.md decision 8)
- [ ] 4.5 Return the live client from 4.1 in `TitleLookups.app`, wrapped in `KeptTitleLookup` with `KeptTitleLookup.cachesDirectory`, so Release builds show the score row and the Movie info switch

## 5. Title page

- [x] 5.1 Add `ScoreRow` with previews on iPhone, iPad, Mac and Apple TV, and show it on the title page below the buttons
- [x] 5.2 Drop the provider rating from the details line when scores show, citing `title-detail-and-episode-picker/what-the-title-is-about`
- [x] 5.3 Look a title up when its page opens, never block Play, show kept results at once, citing `title-metadata/a-slow-or-failing-lookup-never-holds-up-the-page` and `title-detail-and-episode-picker/scores-from-other-sites`
- [x] 5.4 UI tests on iPhone and Apple TV with a stubbed lookup: the score row shows, focus order on Apple TV is unchanged
- [ ] 5.5 Add a journey step for the title page with scores, anchored on `title.scores`

## 6. Settings, credit and privacy

- [x] 6.1 Add `lookupsEnabled` to `PreferencesRecord` and `AppPreferences`, the switch and footer under Preferences, citing `sources-and-settings/a-switch-for-movie-database-lookups`
- [x] 6.2 Turning lookups off stops requests and deletes the cache, citing `title-metadata/lookups-can-be-turned-off`
- [ ] 6.3 Add the TMDB row with logo and notice under About, citing `title-metadata/the-database-is-credited` and `design-system/nothing-fake-and-nothing-bundled`
- [ ] 6.4 Update the Privacy Policy in `Web/privacy/` and `WebsiteTests`, citing `antuna-website/the-privacy-policy-rules-out-tracking`, and `docs/release/app-privacy.md`

## 7. Trending (moved from add-discover-rows)

Moved here on 2026-11-20: the row needs the lookup service. Its boards are `iPhone-Movies-Discover`, `iPad-Movies-Discover` and `TV-Movies-Discover`.

- [ ] 7.1 Add `/v1/trending` to the lookup service with a one-day cache
- [ ] 7.2 Add `TrendingMatch.titles` in AntennaCore with fixtures of ids, tagged names, years and duplicates, citing `movies-and-series-browsing/trending-in-your-sources`
- [ ] 7.3 Fetch, keep for seven days, and show the Trending row on every platform; no fetch and no row with lookups off
- [ ] 7.4 UI tests on iPhone and Apple TV with a stubbed trending list: only matching titles show, focus lands on the first poster
- [ ] 7.5 Add a journey step anchored on `movies.row.trending`

## 8. People from TMDB (moved from add-browse-by-person)

Moved here on 2026-11-20. `add-browse-by-person` shipped person pages from the provider's own names; these tasks add TMDB filmographies once the lookup service exists. Decision 10 has the plan.

- [ ] 8.1 Add `/v1/person/{id}` to the lookup service, credits reduced and capped at 500
- [ ] 8.2 Generalize the Trending matcher from group 7 to any list of database entries and match filmographies against the catalogue
- [ ] 8.3 Keep filmographies in `Caches/people/` for seven days, at most 200, deleted with lookups off, with the offline and failure states and their boards
- [ ] 8.4 Show TMDB credits as chips on matched titles, a photo and "Filmography from TMDB" on the person page
- [ ] 8.5 Add `/v1/people` to the lookup service and People from TMDB in Search, after three letters and a pause, only online with lookups on
- [ ] 8.6 Update the Settings lookups footer, its boards, the Privacy Policy and `WebsiteTests`, citing `antuna-website/the-privacy-policy-rules-out-tracking`
- [ ] 8.7 UI tests with a stubbed service, and `/opsx:verify` for the whole change

## 9. Verify

- [ ] 9.1 Each requirement has a test citing `<capability>/<requirement-slug>`, and `scripts/check-spec-refs.sh` passes
- [ ] 9.2 `/opsx:verify` passes
