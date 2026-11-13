# Proposal

## Why

The owner's list for discovery, in his words: "Trending; Recents; Categories ny serie movies channel; Movies by actor; Movies by category; Series by actor; Movies; Score on different sites ie rotten tomato, imdb or whatever".

> As a movie and series watcher, I want to see what a film scored on the sites I trust before I start it.

> As a movie watcher with a plain playlist, I want a description and a year on a title page, not just a name and a logo.

Trending, browsing by actor and scores all need the same thing first: knowing which entry in a public movie database a provider's title is. Providers send messy names ("EN | Dune: Part Two (2024) 4K"), some send a TMDB id, and plain M3U playlists send a name, a logo and a group. This change matches titles to TMDB, shows scores on the title page, fills details the provider left out, and adds the switch, the credit and the privacy text that go with talking to a service other than the user's sources. `add-discover-rows` and `add-browse-by-person` build on it.

After it, a user opening a movie sees "TMDB 74%" under the details line, a playlist movie shows its year, plot, cast and backdrop, and a user who wants no lookups turns them off in Settings on one device and they stop on all of them.

## What Changes

- Read the TMDB id that many Xtream panels send on movie and series rows and in the info call, and an IMDb id from the info call.
- Match a title when its page opens: by TMDB id when the provider gave one, else by its name cleaned of provider tags and its year.
- A small lookup service run by Code Crave (API Gateway, Lambda and a CloudFront cache) holds the TMDB key and answers the app. It keeps no request logs. This amends the "no server of our own" rule; design.md records the options.
- A score row on the title page on every platform, starting with the TMDB user score. IMDb, Rotten Tomatoes and Metacritic scores are designed for but wait on a licence (see design.md).
- Missing description, year, length, genre, backdrop, cast and director filled from TMDB; provider fields win.
- Matches kept on the device for seven days, never synced, never longer than six months.
- A synced "Movie info and scores" switch under Preferences, on by default.
- The TMDB credit with its logo under About in Settings, and the Privacy Policy updated.

Out of scope:
- Trending, New and Recents rows (`add-discover-rows`).
- Cast you can select and a person's page (`add-browse-by-person`).
- Scores on posters in rows (open question in design.md).
- Matching the whole catalogue in the background.
- Merging provider categories into common genres.
- Posters from TMDB in rows. A title with no provider poster keeps its name tile.
- Episode-level details from TMDB.

## Capabilities

### New Capabilities
- `title-metadata`: matching provider titles to TMDB, what is sent, what is kept, failure handling, the off switch and the credit.

### Modified Capabilities
- `xtream-vod-client`: reads TMDB and IMDb ids.
- `title-detail-and-episode-picker`: the score row, and the provider rating leaving the details line when scores show.
- `sources-and-settings`: the lookup switch.
- `antenna-website`: the Privacy Policy names the lookup service.
- `design-system`: a credit logo a data licence requires is allowed in Settings, About.

## Impact

- AntennaCore: id decoding, a title name cleaner, a matcher, the lookup client and its cache rules.
- Apps: title page score row, Settings switch and About credit, `PreferencesRecord` gains a defaulted field.
- A new external system and container in `docs/architecture/` (the lookup service and TMDB).
- Infrastructure outside the app: an AWS account with the lookup service, deployed from this repo.
- Web: Privacy Policy. Docs: `docs/release/app-privacy.md` keeps "Data Not Collected" with the reason updated.
- Boards: new `iPhone-Title-Scores`, `iPad-Title-Scores`, `TV-Title-Scores`, `iPhone-Settings-Lookups`, `TV-Settings-Lookups`.
- Depends on the archived `add-title-detail-and-episode-picker`, `add-sources-and-settings`, `add-m3u-vod-fallback` and `add-xtream-panel-links` work.
- Blocked on: a TMDB commercial agreement before release (the app is paid, and TMDB's terms need a written agreement for commercial use), and the owner's choice of lookup service option. Code up to the release can be built against a development key.
