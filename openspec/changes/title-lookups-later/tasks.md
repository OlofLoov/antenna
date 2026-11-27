Parked: do not apply until the owner lifts "no server of our own" (declined 2026-11-19). The tasks came from `add-title-metadata` groups 2 to 8 on 2026-11-27 and keep their old numbers in brackets.

## 1. Decide again

- [ ] 1.1 The owner picks how the app reaches TMDB (design.md open question 1), and the line in `openspec/config.yaml` and CLAUDE.md is amended in the same PR if the answer is a server of our own [3.1]
- [ ] 1.2 Re-plan the service against the Terraform roots in `Infra/` from the archived `add-aws-hosting`, and rewrite decision 1 and groups 3 and 5 to match

## 2. Ids and matching in AntennaCore

- [ ] 2.1 Decode `tmdb`, `tmdb_id` and `imdb_id` on movie and series rows and in the info body, with fixture tests citing `xtream-vod-client/movie-database-ids` [2.1]
- [ ] 2.2 Add `TitleMatch.pick(_:name:year:)` and a shared fixture set of search results, citing `title-metadata/a-title-is-matched-by-its-database-id-first` [2.3]

## 3. The lookup service

- [ ] 3.1 Add the service with `/v1/match`, the matching rule from 2.2 run on the same fixtures, and unit tests [3.2]
- [ ] 3.2 Deploy it with its key in Secrets Manager and a one-day CloudFront cache for `/v1/match*` and `/v1/trending*`, with the handler logging no query, body or caller [3.3]
- [ ] 3.3 Add the lookup service and TMDB to `docs/architecture/c4-context.drawio.svg` and `c4-container.drawio.svg` [3.4]

## 4. Live lookup client

- [ ] 4.1 Add the lookup client in AntennaCore: request building that carries only kind, name, year and ids, response decoding, with tests citing `title-metadata/only-what-is-needed-is-looked-up` [4.1]
- [ ] 4.2 Return it from `TitleLookups.app`, wrapped in `KeptTitleLookup` with `KeptTitleLookup.cachesDirectory`, so Release builds show the score row and the Movie info switch, and update `title-metadata/sample-scores-in-debug-builds-only` to match [4.5]
- [ ] 4.3 Add a journey step for the title page with scores, anchored on `title.scores` [5.5]

## 5. Credit and privacy

- [ ] 5.1 Add the TMDB row with logo and notice under About, citing `title-metadata/the-database-is-credited` and `design-system/nothing-fake-and-nothing-bundled` [6.3]
- [ ] 5.2 Update the Privacy Policy in `Web/site/src/routes/privacy/` and `WebsiteTests`, citing `antuna-website/the-privacy-policy-rules-out-tracking`, and `docs/release/app-privacy.md` [6.4]

## 6. Trending

Boards: `iPhone-Movies-Discover`, `iPad-Movies-Discover` and `TV-Movies-Discover`.

- [ ] 6.1 Add `/v1/trending` to the lookup service with a one-day cache [7.1]
- [ ] 6.2 Add `TrendingMatch.titles` in AntennaCore with fixtures of ids, tagged names, years and duplicates, citing `movies-and-series-browsing/trending-in-your-sources` [7.2]
- [ ] 6.3 Fetch, keep for seven days, and show the Trending row on every platform; no fetch and no row with lookups off, citing `movies-and-series-browsing/rows-in-a-predictable-order` [7.3]
- [ ] 6.4 UI tests on iPhone and Apple TV with a stubbed trending list: only matching titles show, focus lands on the first poster [7.4]
- [ ] 6.5 Add a journey step anchored on `movies.row.trending` [7.5]

## 7. People from TMDB

Decision 10 has the plan. `add-browse-by-person` shipped person pages from the provider's own names.

- [ ] 7.1 Add `/v1/person/{id}` to the lookup service, credits reduced and capped at 500 [8.1]
- [ ] 7.2 Generalize the Trending matcher from group 6 to any list of database entries and match filmographies against the catalogue [8.2]
- [ ] 7.3 Keep filmographies in `Caches/people/` for seven days, at most 200, deleted with lookups off, with the offline and failure states and their boards [8.3]
- [ ] 7.4 Show TMDB credits as chips on matched titles, a photo and "Filmography from TMDB" on the person page [8.4]
- [ ] 7.5 Add `/v1/people` to the lookup service and People from TMDB in Search, after three letters and a pause, only online with lookups on [8.5]
- [ ] 7.6 Update the Settings lookups footer, its boards, the Privacy Policy and `WebsiteTests`, citing `antuna-website/the-privacy-policy-rules-out-tracking` [8.6]
- [ ] 7.7 UI tests with a stubbed service [8.7]

## 8. Verify

- [ ] 8.1 Each requirement has a test citing `<capability>/<requirement-slug>`, and `scripts/check-spec-refs.sh` passes
- [ ] 8.2 `/opsx:verify` passes
