# Proposal

## Why

From the owner's list: "Movies by actor; Series by actor".

> As a movie and series watcher, I liked her in this; what else does my subscription have with her?

> As a movie watcher, I remember the director, not the title.

Today a title page shows the provider's cast and director as one line of text. Nothing leads from a name to other titles.

After this change each name on a title page is a chip the user can select. It opens a page with that person's movies, series and directing work among the titles whose names Antenna has already received from the user's sources, and Search finds people by name.

On 2026-11-19 the owner decided not to run the title-info server (the TMDB proxy) for now. This change therefore ships in two parts:

- **Provider names, built now.** People are matched by the cast and director names the provider sends, on the device, with no lookup service.
- **Lookup service, later.** Photos, a department from TMDB, a whole filmography in one request, and people from TMDB in Search wait until the server exists. They stay in this change as open tasks.

## What Changes

Built now:
- The cast and director names on a title page become chips, at most 15, on every platform.
- A person's page on every platform: initials, name, "Acting · 3 in your sources", and Movies, Series and Directed rows of titles the user can play. A note says when titles without names may be missing.
- The names come from the Xtream movie and series lists when a panel puts them there, and from every details answer the app already asks for (banner, Apple TV preview, title page). Antenna asks the provider for nothing more.
- The names learned from details answers stay on the device for 30 days, so the person pages fill out as the user browses.
- A People section in Search, last, with up to three people from those names.

Later, with the lookup service (kept as open tasks):
- A photo and TMDB's department on the person page, and the whole filmography matched against the catalogue in one request per person.
- People from TMDB in Search, with what that sends named in the Privacy Policy and the Settings footer.

Out of scope:
- A biography, birthday or known-for list.
- People's photos in the cast list on the title page.
- A People chip in Search's kind filter.
- Following a person or alerts when a new title with them arrives.
- Writers, composers and other crew beyond directors.
- Asking the provider for details of titles the user has not looked at, to fill person pages.

## Capabilities

### New Capabilities
- `browse-by-person`: picking a name in the cast, the person's page, which titles it lists, where the names come from, and finding a person in Search.

### Modified Capabilities
- `search`: People joins the result sections, last.

## Impact

- AntennaCore: decoding `cast`, `actors` and `director` on Xtream list rows; splitting and normalizing provider names; the people index; the person page model; the people search rules.
- Apps: cast chips on the title page, a person screen on each platform, a People section in Search, and a small cache file of names learned from details answers.
- Navigation: the title page slot in the library becomes a stack, so title and person pages can open from each other.
- Boards: `iPhone-Person`, `iPad-Person`, `TV-Person`, `iPhone-Title-Cast`, `TV-Title-Cast`, `iPhone-Search-People`, revised for provider names.
- The provider-names part depends on nothing outside this repo. The lookup-service part depends on `add-title-metadata` (the lookup service, the TMDB agreement, matched titles with credits, the lookups switch) and is blocked on the owner's decision to run that server.
