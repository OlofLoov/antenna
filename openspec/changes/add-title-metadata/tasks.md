## 1. Proposal and boards

- [x] 1.1 Write the proposal, delta specs, design and tasks, and validate with `openspec validate add-title-metadata --strict`
- [x] 1.2 Draw `iPhone-Title-Scores`, `iPad-Title-Scores`, `TV-Title-Scores`, `iPhone-Settings-Lookups` and `TV-Settings-Lookups`

## 2. Ids and names in AntennaCore

- [ ] 2.1 Decode `tmdb`, `tmdb_id` and `imdb_id` on movie and series rows and in the info body, with fixture tests citing `xtream-vod-client/movie-database-ids`
- [ ] 2.2 Add `TitleName.clean(_:)` with fixtures of real provider names (language tags, years, quality words), citing `title-metadata/a-title-is-matched-by-its-database-id-first`
- [ ] 2.3 Add `TitleMatch.pick(_:name:year:)` and a shared fixture set of search results, citing `title-metadata/a-title-is-matched-by-its-database-id-first`

## 3. The lookup service

- [ ] 3.1 Amend the "no server of our own" line in `openspec/config.yaml` and CLAUDE.md's hard constraints as design.md decision 1 words it, after the owner's answer to open question 1
- [ ] 3.2 Add `Services/lookup/`: the Lambda with `/v1/match`, the matching rule from 2.3 run on the same fixtures, and unit tests
- [ ] 3.3 Add the CDK stack (HTTP API, Lambda, Secrets Manager key, CloudFront with a one-day cache, WAF rate rule, every log of request content off) and a deploy workflow using OIDC
- [ ] 3.4 Add the lookup service and TMDB to `docs/architecture/c4-context.drawio.svg` and `c4-container.drawio.svg`

## 4. Lookup client and cache

- [ ] 4.1 Add the lookup client in AntennaCore: request building that carries only name, year and ids, response decoding, with tests citing `title-metadata/only-what-is-needed-is-looked-up`
- [ ] 4.2 Add the per-source cache file with the seven-day refresh and 180-day cap, removal on source delete, with tests citing `title-metadata/matches-are-kept-on-the-device`
- [ ] 4.3 Merge database details under provider details in `TitleMetadata`, citing `title-metadata/details-the-provider-left-out-come-from-the-database`

## 5. Title page

- [ ] 5.1 Add `ScoreRow` with previews on iPhone, iPad, Mac and Apple TV, and show it on the title page below the buttons
- [ ] 5.2 Drop the provider rating from the details line when scores show, citing `title-detail-and-episode-picker/what-the-title-is-about`
- [ ] 5.3 Look a title up when its page opens, never block Play, show kept results at once, citing `title-metadata/a-slow-or-failing-lookup-never-holds-up-the-page` and `title-detail-and-episode-picker/scores-from-other-sites`
- [ ] 5.4 UI tests on iPhone and Apple TV with a stubbed lookup: the score row shows, focus order on Apple TV is unchanged
- [ ] 5.5 Add a journey step for the title page with scores, anchored on `title.scores`

## 6. Settings, credit and privacy

- [ ] 6.1 Add `lookupsEnabled` to `PreferencesRecord` and `AppPreferences`, the switch and footer under Preferences, citing `sources-and-settings/a-switch-for-movie-database-lookups`
- [ ] 6.2 Turning lookups off stops requests and deletes the cache, citing `title-metadata/lookups-can-be-turned-off`
- [ ] 6.3 Add the TMDB row with logo and notice under About, citing `title-metadata/the-database-is-credited` and `design-system/nothing-fake-and-nothing-bundled`
- [ ] 6.4 Update the Privacy Policy in `Web/privacy/` and `WebsiteTests`, citing `antenna-website/the-privacy-policy-rules-out-tracking`, and `docs/release/app-privacy.md`

## 7. Verify

- [ ] 7.1 Each requirement has a test citing `<capability>/<requirement-slug>`, and `scripts/check-spec-refs.sh` passes
- [ ] 7.2 `/opsx:verify` passes
