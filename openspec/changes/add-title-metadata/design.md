# Design

## Context

See proposal.md for why. What exists on 2026-11-13:

- `XtreamVODWire.swift` decodes movie and series rows and the info body. It reads `rating`, `cast`, `actors`, `director` and `genre` but no database id. Many XUI-style panels send `tmdb` or `tmdb_id` on rows and `tmdb_id` in `info`; none of this is read today.
- Plain M3U movies and series carry a name, a logo and a group, nothing else (`m3u-playlists/playlist-movies-show-in-movies`).
- `TitleMetadata` builds the page's details line from the provider's info call, with the rating as "★ 7.4".
- The app talks to the user's sources, the addresses they list, iCloud and StoreKit. `docs/release/app-privacy.md` answers "Data Not Collected", and the Privacy Policy says Code Crave runs no server that receives user data.

Boards, under `openspec/specs/design-system/boards/`:
- New: `iPhone-Title-Scores.dc.html`, `iPad-Title-Scores.dc.html` (iPad and Mac), `TV-Title-Scores.dc.html`: the title page with the score row below the buttons and the provider's star rating gone from that line. `iPhone-Settings-Lookups.dc.html` and `TV-Settings-Lookups.dc.html`: the switch under Preferences with its footer, and the TMDB credit under About.
- Follows: `iPhone-Title`, `iPad-Title`, `TV-Title`, `iPhone-Settings`, `TV-Settings`.
- Not drawn: iPad and Mac Settings (the iPhone list in the iPad Settings layout, `iPad-Settings`), and the score row with IMDb, Rotten Tomatoes and Metacritic, which waits on a licence. The boards show where those chips go.

Design-system requirements that apply: "Focus is the lifted white card" (the score row takes no focus), "One accent color", "Text stays above the platform caption floor", "Text meets contrast minimums", "Accessibility identifiers follow the board", "Nothing fake and nothing bundled" (modified for the credit logo).

## Research

Checked on 2026-11-13. Prices marked unverified come from third-party pages only.

| Service | What it gives | Terms for a paid app | Cost |
|---------|---------------|----------------------|------|
| TMDB API | ids, search by name and year, details, credits, people, trending, find by IMDb id, `vote_average` | Commercial use needs "a written agreement with TMDB that expressly permits Your commercial use", possibly with fees ([terms](https://www.themoviedb.org/api-terms-of-use), updated 2023-10-20). Free "for non-commercial purposes"; commercial requests go to sales@themoviedb.org ([FAQ](https://developer.themoviedb.org/docs/faq)). | Not published. About $149 a month for companies under $1M revenue, unverified ([zuplo](https://zuplo.com/learning-center/best-movie-api-imdb-vs-omdb-vs-tmdb)). |
| OMDb | IMDb rating and votes, Metascore, a Ratings list with Rotten Tomatoes | Content is CC BY-NC 4.0; the legal page bars use "in connection with any commercial endeavors" ([legal](https://www.omdbapi.com/legal.htm)). Needs written permission. | Free key 1,000 a day; Patreon from 15 SEK a month ([apikey](https://www.omdbapi.com/apikey.aspx)). |
| Rotten Tomatoes | Tomatometer | No public API. Fabric Origin, an approved paid account under Fandango's API terms and partner-only brand rules ([docs](https://developer.origin.fabricdata.com/origin/apis-all/rotten-tomatoes-api-docs)). | From $60,000 a year, unverified. |
| IMDb | ratings, ids | Datasets are "personal and non-commercial use" only ([datasets](https://data.imdb.com/non-commercial-datasets/)). The API on AWS Data Exchange is sold by contract on request; add-ons list at $40,000 and $50,000 a year ([AWS](https://aws.amazon.com/marketplace/pp/prodview-bdmgbi3sikr6i)). | Five figures a year at least. |
| MDBList | aggregated IMDb, Rotten Tomatoes, Metacritic, TMDB scores | No commercial terms published; it passes on Rotten Tomatoes scores, so the upstream licence question stays. | €10 to €200 a year ([join](https://mdblist.memberful.com/join)). |
| Trakt | trending, watched lists | API terms, limits and branding could not be read (the docs rendered empty). VIP went from $30 to $60 a year in 2025 and free limits tightened ([alternativeto](https://alternativeto.net/news/2025/2/trakt-tv-has-set-stricter-limits-for-free-users-and-raised-vip-subscription-prices-by-100-)). | Unknown for commercial use. |
| Wikidata | IMDb and TMDB ids | CC0 ([licensing](https://www.wikidata.org/wiki/Wikidata:Licensing)) | Free; no scores. |

TMDB details used below:
- Attribution: the TMDB logo, less prominent than Antenna's own mark, and the notice "This product uses the TMDB API but is not endorsed or certified by TMDB" in the app's About or Credits ([FAQ](https://developer.themoviedb.org/docs/faq), [logos](https://www.themoviedb.org/about/logos-attribution)).
- Rate limit: about 40 requests a second, with HTTP 429 to honour ([rate limiting](https://developer.themoviedb.org/docs/rate-limiting), updated 2025-10-20).
- Caching: no TMDB data kept "longer than 6 months", and all of it deleted when the agreement ends (terms).
- Endpoints: `/3/search/movie` (`primary_release_year`), `/3/search/tv` (`first_air_date_year`), `/3/movie/{id}`, `/3/tv/{id}` with `append_to_response=credits,external_ids`, `/3/find/{imdb id}?external_source=imdb_id`, `/3/trending/{movie|tv}/{day|week}`, `/3/person/{id}/combined_credits` ([reference](https://developer.themoviedb.org/reference)).
- Nothing in the terms names IPTV; they bar use "that violates any law". Antenna plays the user's own sources and shows only titles those sources have.

Apple:
- Guideline 5.2.2: an app that "displays content from a third-party service" must be "specifically permitted to do so under the service's terms of use. Authorization must be provided upon request." The TMDB agreement is that authorization ([guidelines](https://developer.apple.com/app-store/review/guidelines/)).
- App Privacy: "'Collect' refers to transmitting data off the device in a way that allows you and/or your third-party partners to access it for a period longer than what is necessary to service the transmitted request in real time" ([details](https://developer.apple.com/app-store/app-privacy-details/)). A service that answers and keeps nothing stays inside "Data Not Collected". TMDB's own retention of API requests was not checked.

## Goals / Non-Goals

**Goals:**
- One match per title, stable enough for the later changes to join trending lists and filmographies onto the user's catalogue.
- No title, poster or score for anything the user's sources do not have.
- "Data Not Collected" stays true and the switch turns it all off.

**Non-Goals:**
- Background matching of whole catalogues.
- Scores from sites without a licence.

## Decisions

### 1. Who talks to TMDB: a small lookup service

Options considered:
- **A. The app calls TMDB directly with a key built into the app.** No server, and the "no server of our own" rule stands. But the key can be pulled out of the binary, every device calls TMDB on its own, a change of provider or key needs an app release that tvOS users install slowly, and TMDB sees each user's IP address next to the titles they open. Whether that keeps "Data Not Collected" depends on TMDB's log retention, which Code Crave cannot control or check.
- **B. A lookup service run by Code Crave (chosen, pending the owner).** API Gateway (HTTP API) in front of a Lambda that holds the TMDB key in Secrets Manager, with CloudFront caching answers by request for a day. The app asks the service; the service asks TMDB. TMDB sees only the service. The service logs no request body, path or IP address: API Gateway access logs off, CloudFront standard logs off, Lambda logs only counts and errors. Shared answers (a trending list, a popular film) are fetched once for every user, which keeps far under TMDB's rate limit. The key, the provider and the response shape can change without an app release. A second licensed score source can be added behind the same endpoint.
- **C. No external data.** Use only what providers send. No scores, no trending, nothing for plain playlists. Fails the owner's request.
- **D. A pre-built index on a CDN.** A nightly job publishes TMDB ids, names and years; the app downloads it and matches locally, sending nothing about the user. Matching is private, but TMDB's export files carry no year, the index is large for an Apple TV cache, and scores and credits still need per-title calls. Kept as a later privacy upgrade for matching only.

Cost of B, estimated from AWS list prices and not measured: HTTP API about $1 per million requests, Lambda within the free tier at this size, CloudFront about $0.0075 to $0.01 per 10,000 requests plus transfer. At 1,000 daily users opening ten titles a day, about 300,000 requests a month, the bill is a few dollars a month before TMDB's fee.

This amends the hard constraint "with no server of our own" in `openspec/config.yaml`. `add-aws-hosting` decision 10 words the amendment once for every Code Crave service, in the PR that adds its API stack. The C4 context and container diagrams gain the lookup service and TMDB.

The service runs on the infrastructure from `add-aws-hosting`, which this change depends on: the CDK app in `Infra/`, the `AntennaApi` stack (HTTP API in eu-north-1 behind CloudFront at `api.<antenna-domain>`, the WAF web ACL, the origin header check), the `infra.yml` workflow and its OIDC roles, and no request logs. This change adds the lookup Lambda (code in `Services/lookup/`, a TypeScript package), its routes, its Secrets Manager key and a CloudFront cache behavior for its routes to that stack; it builds no stack, workflow or role of its own. Endpoints, all `GET`, all cacheable:
- `/v1/match?kind=movie|tv&name=&year=` and `/v1/match?kind=&tmdb=` and `/v1/match?kind=&imdb=` return one match or none: TMDB id, name, year, details, credits (top 15 cast, directors), scores.
- `/v1/trending?kind=&window=week` and `/v1/person/{id}` are reserved for the next two changes.

The app sends no device id, profile, source name or token. A plain app check stops casual reuse: requests carry a static header the app ships, and CloudFront rate-limits per IP through AWS WAF (a rule with no logging). The key in the app is worth less than the TMDB key it replaces, since abuse is capped at the service.

### 2. Which scores

Options considered:
- TMDB user score only (chosen for the first release). Covered by the same agreement as the rest.
- OMDb for IMDb, Rotten Tomatoes and Metacritic. Cheap, but its licence is non-commercial; usable only with written permission from its owner.
- MDBList. Cheap; no commercial terms, and it resells Rotten Tomatoes data, so its licence does not settle the question.
- Rotten Tomatoes through Fabric, IMDb through AWS. Licensed, but priced for large companies.

The service returns scores as a list of `{site, value, scale}` so the app draws whatever the service sends, in the fixed order IMDb, Rotten Tomatoes, Metacritic, TMDB. Adding a licensed site is a service change. Rotten Tomatoes is shown only as text, never with its tomato marks, which Fandango keeps for partners.

### 3. Matching

`TitleName.clean(_:)` in AntennaCore strips, in order: a leading language or country tag ending in `|`, `-` or `:` ("EN |", "[MULTI]", "4K-NF:"), a trailing year in parentheses or brackets (kept as the year), and quality and release words ("4K", "UHD", "2160p", "1080p", "HDR", "x265", "MULTI", "VOSTFR", "DUBBED"). Case and spacing are kept for the request.

Order:
1. Provider TMDB id: `/v1/match?tmdb=`.
2. Provider IMDb id: `/v1/match?imdb=`.
3. Name and year (year from the info call, else the cleaned name): exact or near-exact title match within one year.
4. Name only: accepted when one result has the exact cleaned name (folded for case and accents) and at least twice the votes of the next one with that name. Otherwise unmatched.

The rule runs on the service so it can be tuned without an app release; AntennaCore has the same rule as `TitleMatch.pick(_:name:year:)` for the next changes, which match lists locally, and both are tested against one fixture set.

Series from M3U are matched by the show name the playlist parser already derives.

### 4. What is kept, where

Options considered:
- UserDefaults. The rule in `openspec/config.yaml` keeps per-device state there as small values; thousands of matches are not small.
- SwiftData. It would sync, and a cache that each device can rebuild has no reason to use the user's iCloud quota. A new synced record type is also a schema decision for no gain.
- A file in the Caches directory (chosen): `Caches/metadata/<source id>.json`, one map from provider title id to `{tmdbID, kind, details, scores, fetchedAt}`. The system may purge it; the app then asks again. Entries older than seven days are refreshed when their page opens, entries older than 180 days are dropped on load. Deleting a source deletes its file. Turning lookups off deletes the folder. The file holds no link or login: provider title ids hold none (`xtream-vod-client/ids-are-stable`, `m3u-playlists/playlist-movies-show-in-movies`).

The Top Shelf extension does not read it.

### 5. The switch

`PreferencesRecord` gains `lookupsEnabled: Bool = true`, a defaulted field, so the CloudKit schema change is additive and older builds ignore it. `AppPreferences.lookupsEnabled` carries it. Synced, because a person who turns lookups off means it for the household's devices. Per-source switches were considered: they add a row per source for a case nobody has asked for (a source whose titles are private), and the global switch covers it. See the open questions.

### 6. On the page

`TitleMetadata` gains `scores: [Score]` and merges database details under provider ones field by field. The score row is `ScoreRow` in `Apps/Shared/Components/Title/`, a horizontal list of `site` (muted) and `value` (primary, semibold) pairs, wrapping at large text sizes. It sits below the buttons and the progress bar on every platform, so its arrival moves nothing the user can tap or focus. It reserves no space until scores arrive.

Identifiers: `title.scores`, `title.score.<site>` (`imdb`, `rottenTomatoes`, `metacritic`, `tmdb`). Settings: `settings.lookups`, `settings.lookups.footer`, `settings.about.tmdb`.

### 7. Privacy text

The Privacy Policy section on network connections names the movie info service, what it receives, that it keeps nothing, and the switch. `docs/release/app-privacy.md` adds the service to "Why the answer is no". `app-release/each-bundle-declares-its-privacy` is unchanged: still no tracking and no collected data.

### 8. A sample lookup in Debug builds until the service exists

The owner, 2026-11-18: "for now lets create a local mock that would show ratings tmdb like scores but as a decorator or whatever your suggestion". The service in decision 1 does not exist yet, and the score row, the merge and the switch can be built and tried without it.

Options considered:
- **Wait for the service.** Nothing on screen until AWS and the TMDB agreement are settled.
- **Fixed scores in the scripted UI test sources only.** Covers the tests but not a developer trying the page on a device with a real playlist.
- **A protocol, a decorator and a Debug-only mock (chosen).**

What was built:
- `TitleLookup` in AntennaCore, one call: `match(TitleLookupQuery) async throws -> TitleMatch?`. `TitleLookupQuery` carries kind, cleaned name, year and the provider's TMDB and IMDb ids, nothing else. `TitleQuery` was taken by the App Intents entity query, hence the longer name. `TitleMatch` holds the TMDB id, `TitleDetails` (plot, year, length, genre, backdrop, cast, director), `[Score]` as `{site, value, scale}` from decision 2, and `isSample`.
- `KeptTitleLookup`, an actor wrapping any `TitleLookup` with decision 4's rules: kept per source in `Caches/metadata/<source id>.json`, shown without asking for seven days, dropped after 180, the kept match returned when the lookup fails, nothing asked or kept while off (turning off deletes the folder), and a deleted source's file removed. It is keyed by source and title id, which it never passes to the wrapped lookup. Provider fields win in `TitleMetadata.merging(_:)`, not in the decorator, since the provider's details arrive separately.
- `MockTitleLookup` in AntennaCore, inside `#if DEBUG`. Its answer comes from a 64-bit FNV-1a hash of the folded, cleaned name, so "EN | The Long Harbor (2024) 4K" and "the long harbor" get the same TMDB score on every launch and device, between 50 and 90%. It fills the plot, cast and director with text that starts with "Sample", a year, a length and a genre, and no backdrop, so it never touches the network. Every match has `isSample` set and the score row ends with a bordered "Sample" label (`title.scores.sample`).
- In the app, `TitleLookups.app` is the one place a title page gets its lookup. Release builds return nil: no score row, no Movie info switch, no requests. Debug builds return the mock behind `KeptTitleLookup` with no directory, so sample matches stay in memory and never land in the folder the real service will use. It turns on with the launch argument `-mock-title-scores YES` or with the Debug-only "Sample scores" switch in Settings. `-mock-title-scores-all-sites` also turns it on and adds IMDb, Rotten Tomatoes and Metacritic, to try the full row. `scripts/check-rules.sh` fails when `MockTitleLookup` or `DebugTitleScores` appears in app or AntennaCore source outside an `#if DEBUG` block.
- The Movie info and scores switch (decision 5) is built and synced through `PreferencesRecord.lookupsEnabled`, but Settings shows it only while a lookup exists, so Release builds hide it until the service ships.
- The live client for the service (task 4.1) is not written. When it is, `TitleLookups.app` returns it wrapped in `KeptTitleLookup` with `KeptTitleLookup.cachesDirectory`.

Previews do not use the mock. They feed fixed `TitleMatch` values, since a `#Preview` compiles into Release builds too.

### 9. Trending: a list fetched, matched on the device

Moved from `add-discover-rows` on 2026-11-20, which shipped Recently watched, See all and New channels without it.

The app asks the lookup service for `/v1/trending?kind=movie|tv&window=week`. The service fetches TMDB's `/3/trending/{movie|tv}/week` pages 1 to 5 (100 titles) with `append_to_response` for release year and the IMDb id, and caches the answer for a day at CloudFront. Every user gets the same answer, so the request says nothing about anyone and the service makes about two TMDB calls a day.

The app matches the list against its loaded catalogue with `TrendingMatch.titles(trending:catalogue:sourceOrder:)`:
1. A title whose provider gave a TMDB id matches by id.
2. Else by `TitleName.clean` folded for case and accents, plus the year when the provider name holds one (within one year). A cleaned name that occurs more than once in a source without a year to tell them apart is skipped.
3. One tile per trending entry, from the first source in the user's order. Trending order kept. At most 20; below three the row hides.

The list is kept in `Caches/discover/trending-<kind>.json` with its fetch date and used for seven days offline. The row shows provider posters only. Identifier `movies.row.trending`.

Options considered for the list:
- TMDB trending (chosen): covered by the same agreement as the title lookups.
- Trakt trending: its commercial terms could not be read, and its free limits tightened in 2025.
- Most watched across Antenna users: would need the app to report what people watch, which ends "Data Not Collected".

The row sits after My list and before Recently watched: what the user is in the middle of, then what they saved, then what is popular, then their history, then the provider's order.

### 10. People from TMDB

Moved from `add-browse-by-person` on 2026-11-20. That change shipped person pages built from the provider's cast and director names; this is the plan for TMDB filmographies on top of them.

- `/v1/person/{id}` on the lookup service returns name, department, photo path and `combined_credits` reduced to `{tmdbID, kind, title, original title, year, role}`, newest first, capped at 500. The app matches it against the loaded catalogue with the Trending matcher from decision 9 (provider TMDB id first, else `TitleName.clean` plus year within one, ambiguous names skipped). A matched title's chips carry TMDB person ids and open the TMDB filmography; unmatched titles keep provider names.
- Photo from TMDB's image CDN at `w185` through the poster cache, and "Filmography from TMDB" under the name.
- Filmographies in `Caches/people/<tmdb id>.json` for seven days, at most 200 files, deleted when lookups are turned off; offline shows what was kept or "You're offline" with Retry; a failure shows "Could not load this filmography" with Retry.
- `/v1/people?query=` calls TMDB `/3/search/person`, keeps the five most popular with their credits. The app sends the query after 500 ms without a keystroke and three characters, never with lookups off or offline, and merges those people with the provider-name ones.
- What leaves the device is typed text. The Settings footer from `add-title-metadata` becomes "Titles and people you open, and names you search for, are looked up in TMDB.", and the Privacy Policy (`antenna-website/the-privacy-policy-rules-out-tracking`) names person pages and names typed in Search among what the movie info service receives. The service logs nothing, so "Data Not Collected" holds. The first version of this change already wrote that footer line on `iPhone-Settings-Lookups` and `TV-Settings-Lookups`; it stays, since the footer ships only with the lookup service.
- Owner's open questions from the first design still apply then: People from TMDB in Search given it sends typed text (recommend yes, behind the switch), and no biography.

## Risks / Trade-offs

- TMDB's commercial price is unknown until sales answers. If it is out of reach the change ships nothing user-visible; the id decoding is still useful to the next changes.
- Wrong matches show the wrong film's scores. The name-only rule is strict on purpose, and a title with a provider id never uses it.
- The service is a first server to run: a cost, an AWS account to keep and an outage path. The app treats it as optional at every step.
- A score next to a pirate copy of a film could look like an endorsement to App Review. The app shows scores only for titles the user's own sources list, which is the same footing as the posters and plots providers already send.

## Migration Plan

Additive. No data moves. Older builds ignore the new preference field.

## Open Questions

Open questions for the owner, each with a recommendation:

1. **Lookup service or a key in the app?** Recommend the service (B): it hides the key, shares a cache, keeps users' IP addresses away from TMDB and changes without an app release, at a few dollars a month. It amends the "no server" rule.
2. **TMDB commercial agreement.** Recommend emailing sales@themoviedb.org now with the country (Sweden), the app's model and expected request volume; the first release of this change waits for the answer.
3. **IMDb, Rotten Tomatoes and Metacritic scores.** Recommend shipping TMDB only, and asking OMDb's owner for written commercial permission as the cheapest path to the three. Not MDBList or Rotten Tomatoes directly until a licence is in hand.
4. **Lookups on by default?** Recommend on, with the Settings footer and the Privacy Policy text, since nothing about the user is sent and the service keeps nothing.
5. **Per-source switch?** Recommend not now; one synced switch.
6. **Scores on posters in rows?** Recommend no: rows would need a lookup per poster, which is whole-catalogue matching by another name, and Apple TV cards get crowded. The title page and, in `add-discover-rows`, the Trending row are enough.
