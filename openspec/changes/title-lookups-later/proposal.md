# Proposal

## Why

Parked on 2026-11-27. Nothing here is built, and nothing here can be built as planned: every part needs a lookup service run by Code Crave that holds the TMDB key, and on 2026-11-19 the owner decided against that server. CLAUDE.md and `openspec/config.yaml` keep "no server of our own". This change holds the plan so it can come back if that decision changes. Until then, do not apply it.

The owner's list for discovery, in his words: "Trending; Recents; Categories ny serie movies channel; Movies by actor; Movies by category; Series by actor; Movies; Score on different sites ie rotten tomato, imdb or whatever".

> As a movie and series watcher, I want to see what a film scored on the sites I trust before I start it.

> As a movie watcher, I want a Trending row that shows what is popular this week among the titles my sources already have.

`add-title-metadata` shipped the app's side: the lookup protocol, a cleaner for provider names, matches kept on the device for seven days, database details merged under the provider's, the score row, the synced Movie info and scores switch, and a Debug-only sample lookup. Release builds have no lookup, so they show none of it. This change is the rest: the service, the live client, the ids that make a match exact, the credit and the privacy text, Trending, and people from TMDB.

After it, a user opening a movie in a Release build sees "TMDB 74%" under the buttons, a plain playlist movie shows its year, plot, cast and backdrop, Movies and Series get a Trending row, and a person's page can show a TMDB filmography.

## What Changes

- Read the TMDB id that many Xtream panels send on movie and series rows and in the info call, and an IMDb id from the info call.
- Match a title by TMDB id when the provider gave one, else by its cleaned name and its year, with a strict rule for a name with no year.
- A small lookup service run by Code Crave that holds the TMDB key and answers the app, keeping no request logs. This needs the owner to lift "no server of our own".
- The live lookup client in Release builds, behind the kept-match cache `add-title-metadata` built.
- The TMDB credit with its logo under About in Settings, and the Privacy Policy naming the lookup service.
- A Trending row in Movies and Series: TMDB's trending list for the week, matched on the device against the user's catalogue, at most 20, hidden below three matches or with lookups off.
- TMDB filmographies and People from TMDB in Search on top of the provider-name person pages from `add-browse-by-person`.

Out of scope:
- Scores on posters in rows.
- Matching the whole catalogue in the background.
- Posters from TMDB in rows, and episode-level details from TMDB.
- IMDb, Rotten Tomatoes and Metacritic scores until a licence is in hand (design.md decision 2).

## Capabilities

### New Capabilities
None. `title-metadata` exists since `add-title-metadata` was archived.

### Modified Capabilities
- `title-metadata`: matching by database id first, and the credit.
- `xtream-vod-client`: reads TMDB and IMDb ids.
- `antuna-website`: the Privacy Policy names the lookup service.
- `design-system`: a credit logo a data licence requires is allowed in Settings, About.
- `movies-and-series-browsing`: the Trending row and its place in the row order.

## Impact

- Blocked on the owner: running a server of our own (declined 2026-11-19), and a TMDB commercial agreement before release, since the app is paid and TMDB's terms need a written agreement for commercial use.
- AntennaCore: id decoding, the matcher, the live lookup client, the trending matcher.
- Apps: `TitleLookups.app` returns the live client, the About credit, the Trending row, TMDB people.
- Infra: the lookup service on the AWS account in `Infra/`. `add-aws-hosting` was archived on 2026-11-27 with Terraform, not the CDK app this plan was first written against, so the infra tasks need re-planning against `Infra/` before they start.
- A new external system and container in `docs/architecture/` (the lookup service and TMDB).
- Web: Privacy Policy. Docs: `docs/release/app-privacy.md` keeps "Data Not Collected" with the reason updated.
- Depends on the archived `add-title-metadata`, `add-discover-rows` and `add-browse-by-person`.
- The Trending row is drawn on `iPhone-Movies-Discover`, `iPad-Movies-Discover` and `TV-Movies-Discover`; the credit on `iPhone-Settings-Lookups` and `TV-Settings-Lookups`.
